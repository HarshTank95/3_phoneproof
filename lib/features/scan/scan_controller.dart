import 'package:flutter/material.dart';

import '../../core/models/battery_truth.dart';
import '../../core/models/device_truth.dart';
import '../../core/models/report.dart';
import '../../core/models/spec_truth.dart';
import '../../core/models/test_result.dart';
import '../../core/native_bridge.dart';
import '../../core/shizuku.dart';
import '../../core/trust_score.dart';
import '../authenticity/emulator_root_heuristics.dart';
import '../authenticity/play_integrity.dart';
import '../battery_truth/battery_truth_service.dart';
import '../spec_truth/cpu_test.dart';
import '../spec_truth/ram_test.dart';
import '../spec_truth/sensor_inventory.dart';
import '../spec_truth/storage_test.dart';

enum ModuleStatus { pending, running, done }

class ScanModule {
  final String id;
  final String label;
  final IconData icon;
  ModuleStatus status;
  String detail;
  ScanModule(this.id, this.label, this.icon)
      : status = ModuleStatus.pending,
        detail = '';
}

/// Orchestrates the automatic scan modules, collects every truth source, holds
/// interactive functional results, and assembles the final Report.
class ScanController extends ChangeNotifier {
  ScanController({required this.mode});

  final ScanMode mode;
  Claim claim = const Claim();
  String? imei;

  // Collected truths
  BuildTruth? build;
  BatteryTruth? battery;
  DisplayTruth? display;
  SensorInventory? sensors;
  CpuTruth? cpu;
  RamTruth? ram;
  StorageTruth? storage;
  AuthenticityTruth? authenticity;

  // Tier A truths (hardware-backed, read-only).
  AttestationTruth? attestation;
  DrmTruth? drm;
  GpuTruth? gpu;
  DisplayHdrTruth? displayHdr;
  FeatureInventory? features;
  UptimeTruth? uptime;
  ThermalTruth? thermal;
  CameraTruth? cameras;
  CodecTruth? codecs;
  SystemIntegrityTruth? systemIntegrity;
  HapticsTruth? haptics;
  BiometricTruth? biometrics;
  ConnectivityTruth? connectivity;

  // Interactive functional results (filled by the guided steps).
  final List<CheckResult> functionalResults = [];

  final List<ScanModule> modules = [
    ScanModule('battery', 'Battery Truth', Icons.battery_charging_full_rounded),
    ScanModule('specs', 'Spec Truth', Icons.memory_rounded),
    ScanModule('authenticity', 'Authenticity', Icons.verified_user_rounded),
    ScanModule('hardware', 'Functional Hardware', Icons.touch_app_rounded),
  ];

  bool reduceMotion = false;

  /// Fires after each module completes (for haptics in the UI).
  VoidCallback? onModuleComplete;

  ScanModule _m(String id) => modules.firstWhere((m) => m.id == id);

  Future<void> _pace([int ms = 350]) async {
    if (reduceMotion) return;
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// Runs every automatic (non-interactive) module. Functional hardware stays
  /// pending until the guided steps complete.
  Future<void> runAutomatic() async {
    await Shizuku.probe();

    // ---- Battery ----
    _start('battery');
    build = await BuildService.read();
    battery = await BatteryTruthService.read();
    final soh = battery?.effectiveSoH;
    _finish('battery',
        soh != null ? 'Health $soh%' : (battery?.cycleCount != null ? '${battery!.cycleCount} cycles' : 'Live readings'));
    await _pace();

    // ---- Specs ----
    _start('specs');
    display = await DisplayService.read();
    sensors = await SensorInventoryService.read();
    ram = await RamTest.read();
    var c = await CpuTest.read();
    notifyListeners();
    c = await CpuTest.benchmark(c);
    cpu = c;
    var s = await StorageTest.info();
    s = await StorageTest.writeVerify(s, sampleMb: 64);
    s = await StorageTest.speed(s);
    storage = s;
    // Tier A spec-side reads (real GPU, panel HDR, DRM level, feature inventory,
    // thermal headroom, camera hardware).
    gpu = GpuTruth.fromMap(await NativeBridge.gpuInfo());
    displayHdr = DisplayHdrTruth.fromMap(await NativeBridge.displayHdr());
    drm = DrmTruth.fromMap(await NativeBridge.drmInfo());
    features = FeatureInventory.fromMap(await NativeBridge.systemFeatures());
    thermal = ThermalTruth.fromMap(await NativeBridge.thermalStatus());
    cameras = CameraTruth.fromList(await NativeBridge.cameraSpecs());
    codecs = CodecTruth.fromMap(await NativeBridge.codecInfo());
    haptics = HapticsTruth.fromMap(await NativeBridge.hapticsInfo());
    connectivity = ConnectivityTruth.fromMap(await NativeBridge.connectivityInfo());
    _finish('specs',
        '${cpu!.cores} cores · ${ram!.totalGb.toStringAsFixed(0)}GB · ${storage!.verified == true ? 'storage OK' : 'storage ?'}');
    await _pace();

    // ---- Authenticity ----
    _start('authenticity');
    var auth = await EmulatorRootHeuristics.read();
    final verdict = await PlayIntegrity.check();
    auth = auth.withIntegrity(verdict);
    authenticity = auth;
    // Tier A: hardware key attestation (verified boot + bootloader lock) + uptime,
    // kernel/SELinux integrity, biometric hardware class.
    attestation = AttestationTruth.fromMap(await NativeBridge.keyAttestation());
    uptime = UptimeTruth.fromMap(await NativeBridge.uptime());
    systemIntegrity = SystemIntegrityTruth.fromMap(await NativeBridge.kernelSelinux());
    biometrics = BiometricTruth.fromMap(await NativeBridge.biometricInfo());
    _finish('authenticity',
        auth.isEmulator
            ? 'Emulator!'
            : attestation?.isTampered == true
                ? 'Boot unverified'
                : (auth.isRooted ? 'Root markers' : 'Clean'));
    await _pace();
  }

  void markHardwareComplete() {
    _m('hardware').status = ModuleStatus.done;
    _m('hardware').detail = '${functionalResults.length} tests';
    notifyListeners();
    onModuleComplete?.call();
  }

  void _start(String id) {
    _m(id).status = ModuleStatus.running;
    notifyListeners();
  }

  void _finish(String id, String detail) {
    final m = _m(id);
    m.status = ModuleStatus.done;
    m.detail = detail;
    notifyListeners();
    onModuleComplete?.call();
  }

  void addFunctional(CheckResult r) {
    functionalResults.removeWhere((e) => e.id == r.id);
    functionalResults.add(r);
  }

  /// Build the final report. Safe to call once automatic + functional are done;
  /// any still-null truth falls back to a graceful empty value.
  Report buildReport() {
    final functionalGroup = CheckGroup(
      id: 'functional',
      title: 'Functional Tests',
      icon: Icons.checklist_rounded,
      checks: List.of(functionalResults),
    );

    return TrustScoreEngine.build(
      mode: mode,
      claim: claim,
      build: build ?? _emptyBuild(),
      battery: battery ?? const BatteryTruth(),
      display: display ?? _emptyDisplay(),
      sensors: sensors ?? const SensorInventory([]),
      cpu: cpu ?? _emptyCpu(),
      ram: ram ?? _emptyRam(),
      storage: storage ?? _emptyStorage(),
      authenticity: authenticity ?? _emptyAuth(),
      attestation: attestation ?? const AttestationTruth(),
      drm: drm ?? const DrmTruth(),
      gpu: gpu ?? const GpuTruth(),
      displayHdr: displayHdr ?? const DisplayHdrTruth(),
      features: features ?? const FeatureInventory({}),
      uptime: uptime ?? const UptimeTruth(),
      thermal: thermal ?? const ThermalTruth(),
      cameras: cameras ?? const CameraTruth([]),
      codecs: codecs ?? const CodecTruth(),
      systemIntegrity: systemIntegrity ?? const SystemIntegrityTruth(),
      haptics: haptics ?? const HapticsTruth(),
      biometrics: biometrics ?? const BiometricTruth(),
      connectivity: connectivity ?? const ConnectivityTruth(),
      functional: functionalGroup,
      imei: imei,
    );
  }

  BuildTruth _emptyBuild() => const BuildTruth(
      manufacturer: 'Unknown',
      brand: '',
      model: 'Device',
      fingerprint: '',
      tags: '',
      type: '',
      sdkInt: 0,
      release: '');
  DisplayTruth _emptyDisplay() => const DisplayTruth(
      widthPx: 0, heightPx: 0, densityDpi: 0, refreshRate: 60, supportedRefreshRates: []);
  CpuTruth _emptyCpu() =>
      const CpuTruth(cores: 0, abis: [], hardware: null, perCoreMaxFreqKhz: [], maxFreqKhz: -1);
  RamTruth _emptyRam() => const RamTruth(totalBytes: 0, availBytes: 0, zramBytes: 0, hasSwap: false);
  StorageTruth _emptyStorage() => const StorageTruth(totalBytes: 0, freeBytes: 0);
  AuthenticityTruth _emptyAuth() => const AuthenticityTruth(
      isEmulator: false, emulatorReasons: [], isRooted: false, rootReasons: []);
}
