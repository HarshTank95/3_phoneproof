import '../../core/models/spec_truth.dart';
import '../../core/native_bridge.dart';

/// RAM total + virtual-RAM / zRAM detection.
class RamTest {
  static Future<RamTruth> read() async {
    return RamTruth.fromMap(await NativeBridge.memInfo());
  }
}
