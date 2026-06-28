import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Generates a pure tone WAV in memory and plays it (speaker / earpiece test),
/// plus a record-and-playback microphone test.
class AudioTest {
  static final AudioPlayer _player = AudioPlayer();
  static final AudioRecorder _recorder = AudioRecorder();

  /// Build a mono 16-bit PCM WAV of [seconds] at [freq] Hz.
  static Uint8List _toneWav({double freq = 440, double seconds = 1.5, int rate = 44100}) {
    final samples = (rate * seconds).round();
    final dataBytes = samples * 2;
    final buf = BytesBuilder();
    void str(String s) => buf.add(s.codeUnits);
    void u32(int v) => buf.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
    void u16(int v) => buf.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

    str('RIFF');
    u32(36 + dataBytes);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(rate);
    u32(rate * 2); // byte rate
    u16(2); // block align
    u16(16); // bits
    str('data');
    u32(dataBytes);

    final data = Uint8List(dataBytes);
    final bd = data.buffer.asByteData();
    for (int i = 0; i < samples; i++) {
      // gentle fade in/out to avoid clicks
      final env = math.min(1.0, math.min(i, samples - i) / (rate * 0.05));
      final v = math.sin(2 * math.pi * freq * i / rate) * 0.6 * env;
      bd.setInt16(i * 2, (v * 32767).round(), Endian.little);
    }
    buf.add(data);
    return buf.toBytes();
  }

  static Future<void> playTone({double freq = 440}) async {
    await _player.stop();
    await _player.play(BytesSource(_toneWav(freq: freq)));
  }

  static Future<void> stop() => _player.stop();

  static Future<bool> startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/pp_mic_test.m4a';
    await _recorder.start(const RecordConfig(), path: path);
    return true;
  }

  static Future<String?> stopRecording() => _recorder.stop();

  static Future<void> playback(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  static Future<void> dispose() async {
    await _player.dispose();
    await _recorder.dispose();
  }
}
