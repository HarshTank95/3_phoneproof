import '../../core/models/spec_truth.dart';
import '../../core/native_bridge.dart';

/// Fast, offline, approximate emulator + root/bootloader heuristics.
class EmulatorRootHeuristics {
  static Future<AuthenticityTruth> read() async {
    return AuthenticityTruth.fromMap(await NativeBridge.emulatorRoot());
  }
}
