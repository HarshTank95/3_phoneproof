import '../../core/models/spec_truth.dart';
import '../../core/native_bridge.dart';

/// Storage anti-spoof: real usable capacity (write-verify, sampled) + speed.
class StorageTest {
  static Future<StorageTruth> info() async {
    return StorageTruth.fromMap(await NativeBridge.storageInfo());
  }

  static Future<StorageTruth> writeVerify(StorageTruth base, {int sampleMb = 64}) async {
    final v = await NativeBridge.storageWriteVerify(sampleMb: sampleMb);
    return base.merge(verify: v);
  }

  static Future<StorageTruth> speed(StorageTruth base) async {
    final s = await NativeBridge.storageSpeed();
    return base.merge(speed: s);
  }
}
