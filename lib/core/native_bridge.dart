import 'package:flutter/services.dart';

/// Thin wrapper around the Kotlin platform channel. Every call is defensive:
/// a missing native value comes back as null/empty and is handled upstream,
/// never crashes the scan.
class NativeBridge {
  static const MethodChannel _ch = MethodChannel('phoneproof/native');

  static Future<Map<dynamic, dynamic>> _map(String method, [dynamic args]) async {
    try {
      final res = await _ch.invokeMethod(method, args);
      if (res is Map) return res;
      return const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<List<dynamic>> _list(String method, [dynamic args]) async {
    try {
      final res = await _ch.invokeMethod(method, args);
      if (res is List) return res;
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<dynamic, dynamic>> batteryProperties() => _map('batteryProperties');
  static Future<Map<dynamic, dynamic>> thermalStatus() => _map('thermalStatus');
  static Future<Map<dynamic, dynamic>> displayMetrics() => _map('displayMetrics');
  static Future<List<dynamic>> sensorList() => _list('sensorList');
  static Future<Map<dynamic, dynamic>> memInfo() => _map('memInfo');
  static Future<Map<dynamic, dynamic>> cpuInfo() => _map('cpuInfo');
  static Future<Map<dynamic, dynamic>> storageInfo() => _map('storageInfo');
  static Future<Map<dynamic, dynamic>> buildInfo() => _map('buildInfo');
  static Future<Map<dynamic, dynamic>> emulatorRoot() => _map('emulatorRoot');
  static Future<Map<dynamic, dynamic>> shizukuAvailable() => _map('shizukuAvailable');

  static Future<Map<dynamic, dynamic>> storageWriteVerify({int sampleMb = 64}) =>
      _map('storageWriteVerify', {'sampleMb': sampleMb});
  static Future<Map<dynamic, dynamic>> storageSpeed() => _map('storageSpeed');
  static Future<Map<dynamic, dynamic>> cpuBenchmark() => _map('cpuBenchmark');

  // Tier A — read-only, no special permission.
  static Future<Map<dynamic, dynamic>> keyAttestation() => _map('keyAttestation');
  static Future<Map<dynamic, dynamic>> drmInfo() => _map('drmInfo');
  static Future<Map<dynamic, dynamic>> gpuInfo() => _map('gpuInfo');
  static Future<Map<dynamic, dynamic>> displayHdr() => _map('displayHdr');
  static Future<Map<dynamic, dynamic>> systemFeatures() => _map('systemFeatures');
  static Future<Map<dynamic, dynamic>> uptime() => _map('uptime');
  static Future<List<dynamic>> cameraSpecs() => _list('cameraSpecs');
  static Future<Map<dynamic, dynamic>> codecInfo() => _map('codecInfo');
  static Future<Map<dynamic, dynamic>> kernelSelinux() => _map('kernelSelinux');
  static Future<Map<dynamic, dynamic>> hapticsInfo() => _map('hapticsInfo');
  static Future<Map<dynamic, dynamic>> biometricInfo() => _map('biometricInfo');
  static Future<Map<dynamic, dynamic>> connectivityInfo() => _map('connectivityInfo');

  /// Keep the screen awake (battery capacity test). Best-effort.
  static Future<void> keepScreenOn(bool on) async {
    try {
      await _ch.invokeMethod('keepScreenOn', on);
    } catch (_) {}
  }
}
