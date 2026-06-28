// Measured (not "About Phone"-reported) device specs.

class DisplayTruth {
  final int widthPx;
  final int heightPx;
  final int densityDpi;
  final double refreshRate;
  final List<double> supportedRefreshRates;

  const DisplayTruth({
    required this.widthPx,
    required this.heightPx,
    required this.densityDpi,
    required this.refreshRate,
    required this.supportedRefreshRates,
  });

  double get maxRefresh =>
      supportedRefreshRates.isEmpty ? refreshRate : supportedRefreshRates.reduce((a, b) => a > b ? a : b);

  String get resolutionLabel => '$widthPx × $heightPx';

  factory DisplayTruth.fromMap(Map<dynamic, dynamic> m) {
    final modes = (m['supportedModes'] as List?) ?? const [];
    final rates = modes
        .map((e) => ((e as Map)['refreshRate'] as num).toDouble())
        .toSet()
        .toList()
      ..sort();
    return DisplayTruth(
      widthPx: (m['widthPx'] as num?)?.toInt() ?? 0,
      heightPx: (m['heightPx'] as num?)?.toInt() ?? 0,
      densityDpi: (m['densityDpi'] as num?)?.toInt() ?? 0,
      refreshRate: (m['refreshRate'] as num?)?.toDouble() ?? 60.0,
      supportedRefreshRates: rates.cast<double>(),
    );
  }
}

class SensorEntry {
  final String name;
  final int type;
  final String vendor;
  const SensorEntry({required this.name, required this.type, required this.vendor});
}

class SensorInventory {
  final List<SensorEntry> sensors;
  const SensorInventory(this.sensors);

  bool hasType(int t) => sensors.any((s) => s.type == t);

  // Android sensor type constants.
  bool get hasAccelerometer => hasType(1);
  bool get hasGyroscope => hasType(4);
  bool get hasMagnetometer => hasType(2); // compass
  bool get hasProximity => hasType(8);
  bool get hasLight => hasType(5);
  bool get hasBarometer => hasType(6);
  bool get hasStepCounter => hasType(19);
  bool get hasHeartRate => hasType(21);

  factory SensorInventory.fromList(List<dynamic> list) {
    return SensorInventory(list.map((e) {
      final m = e as Map;
      return SensorEntry(
        name: (m['name'] ?? '').toString(),
        type: (m['type'] as num?)?.toInt() ?? -1,
        vendor: (m['vendor'] ?? '').toString(),
      );
    }).toList());
  }
}

class CpuTruth {
  final int cores;
  final List<String> abis;
  final String? hardware;
  final List<int> perCoreMaxFreqKhz;
  final int maxFreqKhz;
  // Benchmark
  final int singleScore;
  final int multiScore;
  final double singleMs;
  final double multiMs;

  const CpuTruth({
    required this.cores,
    required this.abis,
    required this.hardware,
    required this.perCoreMaxFreqKhz,
    required this.maxFreqKhz,
    this.singleScore = 0,
    this.multiScore = 0,
    this.singleMs = 0,
    this.multiMs = 0,
  });

  double get maxFreqGhz => maxFreqKhz > 0 ? maxFreqKhz / 1e6 : 0;
  bool get is64bit => abis.any((a) => a.contains('64'));

  CpuTruth withBench(Map<dynamic, dynamic> b) => CpuTruth(
        cores: cores,
        abis: abis,
        hardware: hardware,
        perCoreMaxFreqKhz: perCoreMaxFreqKhz,
        maxFreqKhz: maxFreqKhz,
        singleScore: (b['singleScore'] as num?)?.toInt() ?? 0,
        multiScore: (b['multiScore'] as num?)?.toInt() ?? 0,
        singleMs: (b['singleMs'] as num?)?.toDouble() ?? 0,
        multiMs: (b['multiMs'] as num?)?.toDouble() ?? 0,
      );

  factory CpuTruth.fromMap(Map<dynamic, dynamic> m) {
    return CpuTruth(
      cores: (m['cores'] as num?)?.toInt() ?? 0,
      abis: ((m['abis'] as List?) ?? const []).map((e) => e.toString()).toList(),
      hardware: m['hardware'] as String?,
      perCoreMaxFreqKhz:
          ((m['perCoreMaxFreqKhz'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      maxFreqKhz: (m['maxFreqKhz'] as num?)?.toInt() ?? -1,
    );
  }
}

class RamTruth {
  final int totalBytes;
  final int availBytes;
  final int zramBytes;
  final bool hasSwap;

  const RamTruth({
    required this.totalBytes,
    required this.availBytes,
    required this.zramBytes,
    required this.hasSwap,
  });

  double get totalGb => totalBytes / (1024 * 1024 * 1024);
  double get zramGb => zramBytes / (1024 * 1024 * 1024);
  bool get hasVirtualRam => zramBytes > 0 || hasSwap;

  factory RamTruth.fromMap(Map<dynamic, dynamic> m) {
    final amTotal = (m['amTotalMem'] as num?)?.toInt() ?? 0;
    final memTotalKb = (m['memTotalKb'] as num?)?.toInt() ?? 0;
    final zram = (m['zramTotalBytes'] as num?)?.toInt() ?? -1;
    return RamTruth(
      totalBytes: amTotal > 0 ? amTotal : memTotalKb * 1024,
      availBytes: (m['amAvailMem'] as num?)?.toInt() ?? 0,
      zramBytes: zram > 0 ? zram : 0,
      hasSwap: m['hasSwap'] == true,
    );
  }
}

class StorageTruth {
  final int totalBytes;
  final int freeBytes;
  // write-verify
  final bool? verified;
  final int sampleBytes;
  final int mismatchBytes;
  // speed
  final double seqWriteMbps;
  final double seqReadMbps;
  final double randReadMbps;

  const StorageTruth({
    required this.totalBytes,
    required this.freeBytes,
    this.verified,
    this.sampleBytes = 0,
    this.mismatchBytes = 0,
    this.seqWriteMbps = -1,
    this.seqReadMbps = -1,
    this.randReadMbps = -1,
  });

  double get totalGb => totalBytes / (1000 * 1000 * 1000);

  StorageTruth merge({Map<dynamic, dynamic>? verify, Map<dynamic, dynamic>? speed}) {
    return StorageTruth(
      totalBytes: totalBytes,
      freeBytes: freeBytes,
      verified: verify != null ? verify['verified'] == true : verified,
      sampleBytes: verify != null ? (verify['sampleBytes'] as num?)?.toInt() ?? 0 : sampleBytes,
      mismatchBytes: verify != null ? (verify['mismatchBytes'] as num?)?.toInt() ?? 0 : mismatchBytes,
      seqWriteMbps: speed != null ? (speed['seqWriteMbps'] as num?)?.toDouble() ?? -1 : seqWriteMbps,
      seqReadMbps: speed != null ? (speed['seqReadMbps'] as num?)?.toDouble() ?? -1 : seqReadMbps,
      randReadMbps: speed != null ? (speed['randReadMbps'] as num?)?.toDouble() ?? -1 : randReadMbps,
    );
  }

  factory StorageTruth.fromMap(Map<dynamic, dynamic> m) {
    return StorageTruth(
      totalBytes: (m['dataTotalBytes'] as num?)?.toInt() ?? 0,
      freeBytes: (m['dataFreeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class BuildTruth {
  final String manufacturer;
  final String brand;
  final String model;
  final String fingerprint;
  final String tags;
  final String type;
  final int sdkInt;
  final String release;
  final String? securityPatch;

  const BuildTruth({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.fingerprint,
    required this.tags,
    required this.type,
    required this.sdkInt,
    required this.release,
    this.securityPatch,
  });

  String get marketName => '$manufacturer $model';

  /// Android release ↔ API-level consistency check (rough table).
  bool get versionConsistent {
    const map = {
      24: '7', 25: '7', 26: '8', 27: '8', 28: '9', 29: '10', 30: '11',
      31: '12', 32: '12', 33: '13', 34: '14', 35: '15', 36: '16',
    };
    final expected = map[sdkInt];
    if (expected == null) return true; // unknown, don't flag
    return release.startsWith(expected);
  }

  factory BuildTruth.fromMap(Map<dynamic, dynamic> m) {
    return BuildTruth(
      manufacturer: (m['manufacturer'] ?? '').toString(),
      brand: (m['brand'] ?? '').toString(),
      model: (m['model'] ?? '').toString(),
      fingerprint: (m['fingerprint'] ?? '').toString(),
      tags: (m['tags'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      sdkInt: (m['sdkInt'] as num?)?.toInt() ?? 0,
      release: (m['release'] ?? '').toString(),
      securityPatch: m['securityPatch'] as String?,
    );
  }
}

class AuthenticityTruth {
  final bool isEmulator;
  final List<String> emulatorReasons;
  final bool isRooted;
  final List<String> rootReasons;
  // Play Integrity
  final IntegrityVerdict integrity;

  const AuthenticityTruth({
    required this.isEmulator,
    required this.emulatorReasons,
    required this.isRooted,
    required this.rootReasons,
    this.integrity = IntegrityVerdict.notChecked,
  });

  AuthenticityTruth withIntegrity(IntegrityVerdict v) => AuthenticityTruth(
        isEmulator: isEmulator,
        emulatorReasons: emulatorReasons,
        isRooted: isRooted,
        rootReasons: rootReasons,
        integrity: v,
      );

  factory AuthenticityTruth.fromMap(Map<dynamic, dynamic> m) {
    return AuthenticityTruth(
      isEmulator: m['isEmulator'] == true,
      emulatorReasons: ((m['emulatorReasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
      isRooted: m['isRooted'] == true,
      rootReasons: ((m['rootReasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

enum IntegrityVerdict { meets, fails, notChecked, error }
