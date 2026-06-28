import '../../core/models/battery_truth.dart';
import '../../core/native_bridge.dart';
import '../../core/shizuku.dart';

class BatteryTruthService {
  static Future<BatteryTruth> read() async {
    final m = await NativeBridge.batteryProperties();
    return BatteryTruth.fromMap(m, shizuku: Shizuku.usable);
  }
}
