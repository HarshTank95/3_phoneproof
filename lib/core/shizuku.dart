import 'native_bridge.dart';

/// Shizuku gives privileged reads (system battery fields on Android 14,
/// charge_full/charge_full_design for real mAh). We detect its presence and the
/// rest of the app degrades gracefully when it is absent — Shizuku-dependent
/// values simply show "Not reported by this device".
class Shizuku {
  static bool installed = false;
  static bool bound = false;

  static Future<void> probe() async {
    final m = await NativeBridge.shizukuAvailable();
    installed = m['installed'] == true;
    bound = m['bound'] == true;
  }

  static bool get usable => installed && bound;

  static String get statusLabel {
    if (bound) return 'Shizuku connected — deep reads enabled';
    if (installed) return 'Shizuku installed (not connected) — limited deep reads';
    return 'Shizuku not installed — some battery values unavailable on Android 14';
  }
}
