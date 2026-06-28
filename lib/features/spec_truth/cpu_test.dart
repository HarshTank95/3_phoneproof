import '../../core/models/spec_truth.dart';
import '../../core/native_bridge.dart';

/// CPU/SoC truth: cores, ABI, per-core freq + a short benchmark.
class CpuTest {
  static Future<CpuTruth> read() async {
    return CpuTruth.fromMap(await NativeBridge.cpuInfo());
  }

  static Future<CpuTruth> benchmark(CpuTruth base) async {
    final b = await NativeBridge.cpuBenchmark();
    return base.withBench(b);
  }
}
