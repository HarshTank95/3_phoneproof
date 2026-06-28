import '../../core/models/spec_truth.dart';
import '../../core/native_bridge.dart';

/// Enumerate the sensors physically present on the device.
class SensorInventoryService {
  static Future<SensorInventory> read() async {
    return SensorInventory.fromList(await NativeBridge.sensorList());
  }
}

class DisplayService {
  static Future<DisplayTruth> read() async {
    return DisplayTruth.fromMap(await NativeBridge.displayMetrics());
  }
}

class BuildService {
  static Future<BuildTruth> read() async {
    return BuildTruth.fromMap(await NativeBridge.buildInfo());
  }
}
