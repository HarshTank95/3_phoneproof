import 'models/device_truth.dart';
import 'models/spec_truth.dart';

/// How much we trust a cross-signal contradiction. Shown to the user verbatim —
/// low-confidence findings are hints, never presented as proof.
enum AnomalyConfidence { high, medium, low }

/// A single contradiction found by comparing signals against each other.
class Anomaly {
  final String id;
  final String title;
  final String detail;
  final AnomalyConfidence confidence;

  /// Score points to deduct. 0 = informational, or already counted by another
  /// rule (we surface it here as a cross-check without double-penalising).
  final int penalty;

  const Anomaly({
    required this.id,
    required this.title,
    required this.detail,
    required this.confidence,
    this.penalty = 0,
  });
}

/// Cross-signal consistency checks. Every rule compares two things the device
/// actually reported and only fires when both sides are known — it never
/// invents a signal, and it states its own confidence.
class AnomalyEngine {
  static List<Anomaly> detect({
    required BuildTruth build,
    required AttestationTruth attestation,
    required GpuTruth gpu,
    required CpuTruth cpu,
    required StorageTruth storage,
    required DrmTruth drm,
    required UptimeTruth uptime,
    required CodecTruth codecs,
    required SystemIntegrityTruth systemIntegrity,
  }) {
    final out = <Anomaly>[];
    final isFlagship = cpu.multiScore >= 9000 || cpu.maxFreqGhz >= 2.8;

    // --- SELinux permissive (only scored here) ---
    if (systemIntegrity.selinuxEnforcing == false) {
      out.add(const Anomaly(
        id: 'ax_selinux',
        title: 'SELinux is permissive',
        detail:
            'Stock Android always runs SELinux "Enforcing". Permissive means the security policy is disabled — a custom or tampered OS.',
        confidence: AnomalyConfidence.high,
        penalty: 15,
      ));
    }

    // --- Modern chip without a hardware HEVC decoder ---
    if (isFlagship && codecs.available && !codecs.hasHwHevc) {
      out.add(const Anomaly(
        id: 'ax_codec',
        title: 'Flagship chip but no hardware HEVC decoder',
        detail:
            'Every real flagship SoC since ~2016 decodes HEVC in silicon. Its absence suggests an emulator or a misrepresented chip.',
        confidence: AnomalyConfidence.medium,
        penalty: 8,
      ));
    }

    // --- Bootloader / verified boot (hardware-attested, already scored) ---
    if (attestation.supported && attestation.deviceLocked == false) {
      out.add(const Anomaly(
        id: 'ax_bootloader',
        title: 'Bootloader is unlocked',
        detail: 'Hardware-attested. The phone has been reflashable — a common sign of tampering.',
        confidence: AnomalyConfidence.high,
      ));
    } else if (attestation.supported &&
        attestation.verifiedBootState != null &&
        attestation.verifiedBootState != 'Verified') {
      out.add(Anomaly(
        id: 'ax_boot',
        title: 'Boot chain is not "Verified"',
        detail: 'Hardware-attested state: ${attestation.verifiedBootState}. Suggests a custom/modified OS.',
        confidence: AnomalyConfidence.high,
      ));
    }

    // --- GPU vendor vs SoC identity ---
    final gpuConflict = _gpuVsSoc(gpu, cpu, build);
    if (gpuConflict != null) out.add(gpuConflict);

    // --- Flagship compute but sub-spec storage speed ---
    if (isFlagship && storage.seqWriteMbps > 0 && storage.seqWriteMbps < 100) {
      out.add(Anomaly(
        id: 'ax_storage',
        title: 'Flagship SoC but slow storage',
        detail:
            'Benchmark looks flagship-class, yet sequential write is only ${storage.seqWriteMbps.toStringAsFixed(0)} MB/s (eMMC-class). Possible counterfeit or downgraded storage.',
        confidence: AnomalyConfidence.medium,
        penalty: 8,
      ));
    }

    // --- Flagship chip but Widevine L3 ---
    if (isFlagship && drm.securityLevel == 'L3') {
      out.add(const Anomaly(
        id: 'ax_drm',
        title: 'Flagship chip but Widevine L3',
        detail:
            'A high-end chip usually ships Widevine L1. L3 here can mean a custom ROM/tamper — or a genuinely DRM-limited unit. Treat as a hint.',
        confidence: AnomalyConfidence.low,
      ));
    }

    // --- Version string vs API level (already scored) ---
    if (!build.versionConsistent) {
      out.add(Anomaly(
        id: 'ax_version',
        title: 'Android version inconsistent with API level',
        detail: 'Reports Android ${build.release} on API ${build.sdkInt} — the build props may be edited.',
        confidence: AnomalyConfidence.medium,
      ));
    }

    // --- Freshly booted (history could be masked) ---
    final up = uptime.uptimeMs;
    if (up != null && up < 5 * 60 * 1000) {
      out.add(Anomaly(
        id: 'ax_uptime',
        title: 'Device booted moments ago',
        detail:
            'Up for ${uptime.humanUptime}. A phone reset right before sale can hide its usage history — worth asking about.',
        confidence: AnomalyConfidence.low,
      ));
    }

    return out;
  }

  /// Adreno ⇒ Qualcomm, Mali ⇒ ARM (MediaTek/Exynos/Tensor/Kirin),
  /// PowerVR ⇒ (older) MediaTek. Only fires when BOTH the GPU family and the
  /// SoC vendor are clearly identified and disagree — otherwise stays silent.
  static Anomaly? _gpuVsSoc(GpuTruth gpu, CpuTruth cpu, BuildTruth build) {
    final r = (gpu.renderer ?? '').toLowerCase();
    if (r.isEmpty) return null;
    final socText = [
      cpu.hardware ?? '',
      build.manufacturer,
      build.model,
      build.fingerprint,
    ].join(' ').toLowerCase();

    bool socSaysQualcomm() =>
        socText.contains('qualcomm') ||
        socText.contains('snapdragon') ||
        RegExp(r'\bsm[0-9]{3,4}\b').hasMatch(socText) ||
        socText.contains('msm');
    bool socSaysMediatek() =>
        socText.contains('mediatek') ||
        socText.contains('dimensity') ||
        RegExp(r'\bmt[0-9]{4}\b').hasMatch(socText);
    bool socSaysExynos() => socText.contains('exynos');
    bool socSaysTensor() => socText.contains('tensor');

    String? gpuFamily;
    if (r.contains('adreno')) {
      gpuFamily = 'Adreno (Qualcomm)';
    } else if (r.contains('mali')) {
      gpuFamily = 'Mali (ARM)';
    } else if (r.contains('powervr')) {
      gpuFamily = 'PowerVR (Imagination)';
    }
    if (gpuFamily == null) return null;

    final conflict = (r.contains('adreno') &&
            (socSaysMediatek() || socSaysExynos() || socSaysTensor())) ||
        (r.contains('mali') && socSaysQualcomm()) ||
        (r.contains('powervr') && socSaysQualcomm());

    if (!conflict) return null;
    return Anomaly(
      id: 'ax_gpu_soc',
      title: 'GPU doesn’t match the reported chip',
      detail: 'GPU reads as $gpuFamily but the device identifies as a different vendor’s SoC — a sign of edited build info.',
      confidence: AnomalyConfidence.medium,
      penalty: 12,
    );
  }
}
