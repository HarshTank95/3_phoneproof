// Tier A truths — hardware-backed, read-only, no special permission.
// Every field is nullable: a value the device doesn't expose stays null and is
// rendered as "Not reported", never guessed.

/// Hardware Key Attestation: Google-signed verified-boot state + bootloader
/// lock, read from the Android Keystore attestation certificate.
class AttestationTruth {
  final bool supported;
  final bool hardwareBacked;
  final String? securityLevel; // Software / TEE / StrongBox
  final bool? deviceLocked; // bootloader locked?
  final String? verifiedBootState; // Verified / Self-signed / Unverified / Failed
  final int? osPatchLevel; // YYYYMM
  final String? reason; // why unsupported / unparsed

  const AttestationTruth({
    this.supported = false,
    this.hardwareBacked = false,
    this.securityLevel,
    this.deviceLocked,
    this.verifiedBootState,
    this.osPatchLevel,
    this.reason,
  });

  /// A genuine, untampered device: locked bootloader AND a "Verified" boot chain.
  bool get isTrustedBoot => deviceLocked == true && verifiedBootState == 'Verified';

  /// Tampered signal we can state as fact (hardware-signed): unlocked or not verified.
  bool get isTampered =>
      (deviceLocked == false) ||
      (verifiedBootState != null && verifiedBootState != 'Verified');

  factory AttestationTruth.fromMap(Map<dynamic, dynamic> m) {
    return AttestationTruth(
      supported: m['supported'] == true,
      hardwareBacked: m['hardwareBacked'] == true,
      securityLevel: m['securityLevel'] as String?,
      deviceLocked: m['deviceLocked'] is bool ? m['deviceLocked'] as bool : null,
      verifiedBootState: m['verifiedBootState'] as String?,
      osPatchLevel: (m['osPatchLevel'] as num?)?.toInt(),
      reason: (m['reason'] ?? m['parseError']) as String?,
    );
  }
}

/// Widevine DRM security level — spoof-resistant and a real streaming concern.
class DrmTruth {
  final bool widevineSupported;
  final String? securityLevel; // L1 / L2 / L3
  final String? hdcpLevel;
  final String? version;

  const DrmTruth({
    this.widevineSupported = false,
    this.securityLevel,
    this.hdcpLevel,
    this.version,
  });

  factory DrmTruth.fromMap(Map<dynamic, dynamic> m) {
    return DrmTruth(
      widevineSupported: m['widevineSupported'] == true,
      securityLevel: m['securityLevel'] as String?,
      hdcpLevel: m['hdcpLevel'] as String?,
      version: m['version'] as String?,
    );
  }
}

/// Real GPU, read from a live OpenGL ES context (not the "About" screen).
class GpuTruth {
  final bool available;
  final String? renderer;
  final String? vendor;
  final String? glVersion;

  const GpuTruth({this.available = false, this.renderer, this.vendor, this.glVersion});

  factory GpuTruth.fromMap(Map<dynamic, dynamic> m) {
    return GpuTruth(
      available: m['available'] == true,
      renderer: m['renderer'] as String?,
      vendor: m['vendor'] as String?,
      glVersion: m['glVersion'] as String?,
    );
  }
}

/// Display HDR / wide-colour capability, straight from the panel.
class DisplayHdrTruth {
  final List<String> hdrTypes;
  final bool? wideColorGamut;
  final double? maxLuminanceNits; // panel-reported HDR peak

  const DisplayHdrTruth({this.hdrTypes = const [], this.wideColorGamut, this.maxLuminanceNits});

  factory DisplayHdrTruth.fromMap(Map<dynamic, dynamic> m) {
    return DisplayHdrTruth(
      hdrTypes: ((m['hdrTypes'] as List?) ?? const []).map((e) => e.toString()).toList(),
      wideColorGamut: m['wideColorGamut'] is bool ? m['wideColorGamut'] as bool : null,
      maxLuminanceNits: (m['maxLuminance'] as num?)?.toDouble(),
    );
  }
}

/// Hardware media decoders — a spoof-resistant SoC fingerprint.
class CodecTruth {
  final bool available;
  final List<String> hardwareDecoders; // e.g. AV1, HEVC, VP9, Dolby Vision
  final List<String> softwareOnlyDecoders;
  final int totalDecoders;

  const CodecTruth({
    this.available = false,
    this.hardwareDecoders = const [],
    this.softwareOnlyDecoders = const [],
    this.totalDecoders = 0,
  });

  bool get hasHwHevc => hardwareDecoders.contains('HEVC');
  bool get hasHwAv1 => hardwareDecoders.contains('AV1');

  factory CodecTruth.fromMap(Map<dynamic, dynamic> m) {
    List<String> strs(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
    return CodecTruth(
      available: m['available'] == true,
      hardwareDecoders: strs(m['hardwareDecoders']),
      softwareOnlyDecoders: strs(m['softwareOnlyDecoders']),
      totalDecoders: (m['totalDecoders'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Kernel identity + SELinux enforcement (permissive = strong tamper signal).
class SystemIntegrityTruth {
  final String? kernelVersion;
  final bool? selinuxEnforcing; // null = not readable on this device

  const SystemIntegrityTruth({this.kernelVersion, this.selinuxEnforcing});

  factory SystemIntegrityTruth.fromMap(Map<dynamic, dynamic> m) {
    return SystemIntegrityTruth(
      kernelVersion: m['kernelVersion'] as String?,
      selinuxEnforcing: m['selinuxEnforcing'] is bool ? m['selinuxEnforcing'] as bool : null,
    );
  }
}

/// Vibration hardware class — amplitude control + primitives = real LRA motor.
class HapticsTruth {
  final bool? hasVibrator;
  final bool? amplitudeControl;
  final bool? richPrimitives; // Android 12+ composition primitives

  const HapticsTruth({this.hasVibrator, this.amplitudeControl, this.richPrimitives});

  factory HapticsTruth.fromMap(Map<dynamic, dynamic> m) {
    bool? b(dynamic v) => v is bool ? v : null;
    return HapticsTruth(
      hasVibrator: b(m['hasVibrator']),
      amplitudeControl: b(m['amplitudeControl']),
      richPrimitives: b(m['richPrimitives']),
    );
  }
}

/// Biometric hardware class (Class 3 "strong" = hardware-backed).
class BiometricTruth {
  final String? strong; // Available / Hardware present / No hardware / null
  final String? weak;
  final bool fingerprintFeature;

  const BiometricTruth({this.strong, this.weak, this.fingerprintFeature = false});

  factory BiometricTruth.fromMap(Map<dynamic, dynamic> m) {
    return BiometricTruth(
      strong: m['strong'] as String?,
      weak: m['weak'] as String?,
      fingerprintFeature: m['fingerprintFeature'] == true,
    );
  }
}

/// Radio capability generation (capability queries only — no scanning).
class ConnectivityTruth {
  final bool? wifi5Ghz;
  final bool? wifi6Ghz; // 6 GHz band (Wi-Fi 6E)
  final bool? wifi6; // 802.11ax
  final bool? wifi7; // 802.11be
  final bool? btLe2MPhy; // Bluetooth 5 2M PHY
  final bool? btLeCodedPhy; // BT5 long range
  final bool? btLeExtAdv;

  const ConnectivityTruth({
    this.wifi5Ghz,
    this.wifi6Ghz,
    this.wifi6,
    this.wifi7,
    this.btLe2MPhy,
    this.btLeCodedPhy,
    this.btLeExtAdv,
  });

  String? get wifiLabel {
    if (wifi7 == true) return 'Wi-Fi 7 (802.11be)';
    if (wifi6 == true) return wifi6Ghz == true ? 'Wi-Fi 6E' : 'Wi-Fi 6 (802.11ax)';
    if (wifi5Ghz == true) return 'Dual-band (2.4 + 5 GHz)';
    if (wifi5Ghz == false) return '2.4 GHz only';
    return null;
  }

  String? get btLabel {
    final feats = <String>[
      if (btLe2MPhy == true) '2M PHY',
      if (btLeCodedPhy == true) 'long range',
      if (btLeExtAdv == true) 'ext. advertising',
    ];
    if (feats.isNotEmpty) return 'Bluetooth 5 class (${feats.join(', ')})';
    if (btLe2MPhy == false) return 'Bluetooth 4.x class';
    return null;
  }

  factory ConnectivityTruth.fromMap(Map<dynamic, dynamic> m) {
    bool? b(dynamic v) => v is bool ? v : null;
    return ConnectivityTruth(
      wifi5Ghz: b(m['wifi5Ghz']),
      wifi6Ghz: b(m['wifi6Ghz']),
      wifi6: b(m['wifi6']),
      wifi7: b(m['wifi7']),
      btLe2MPhy: b(m['btLe2MPhy']),
      btLeCodedPhy: b(m['btLeCodedPhy']),
      btLeExtAdv: b(m['btLeExtAdv']),
    );
  }
}

/// Hardware feature inventory (NFC, fingerprint, IR, …) — present or not.
class FeatureInventory {
  final Map<String, bool> features; // ordered

  const FeatureInventory(this.features);

  List<String> get present => features.entries.where((e) => e.value).map((e) => e.key).toList();
  List<String> get absent => features.entries.where((e) => !e.value).map((e) => e.key).toList();

  factory FeatureInventory.fromMap(Map<dynamic, dynamic> m) {
    final raw = (m['features'] as Map?) ?? const {};
    final out = <String, bool>{};
    raw.forEach((k, v) => out[k.toString()] = v == true);
    return FeatureInventory(out);
  }
}

/// Thermal state + headroom toward throttling — a proxy for cooling health.
class ThermalTruth {
  final bool available;
  final int? statusRaw; // 0..6 (NONE..SHUTDOWN)
  final double? headroom; // 0..1+, 1.0 = at severe-throttle threshold; null if N/A

  const ThermalTruth({this.available = false, this.statusRaw, this.headroom});

  String? get statusLabel {
    switch (statusRaw) {
      case 0:
        return 'Normal';
      case 1:
        return 'Light';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      case 4:
        return 'Critical';
      case 5:
        return 'Emergency';
      case 6:
        return 'Shutdown';
      default:
        return null;
    }
  }

  /// Percentage margin before severe throttling (100% = cool, 0% = throttling).
  int? get marginPct {
    if (headroom == null) return null;
    final m = (1.0 - headroom!).clamp(0.0, 1.0);
    return (m * 100).round();
  }

  factory ThermalTruth.fromMap(Map<dynamic, dynamic> m) {
    return ThermalTruth(
      available: m['available'] == true,
      statusRaw: (m['status'] as num?)?.toInt(),
      headroom: (m['headroom'] as num?)?.toDouble(),
    );
  }
}

/// One camera's real hardware, from CameraCharacteristics (no permission).
class CameraSpec {
  final String id;
  final String facing; // Front / Back / External
  final double? megapixels; // full sensor resolution
  final double? binnedMegapixels; // default (binned) output on Quad-Bayer sensors
  final double? sensorWidthMm;
  final double? sensorHeightMm;
  final List<double> focalLengths;
  final List<double> apertures;
  final bool hasFlash;
  final bool hasOis;
  final int physicalCount; // >1 => a logical multi-camera grouping physical lenses

  const CameraSpec({
    required this.id,
    required this.facing,
    this.megapixels,
    this.binnedMegapixels,
    this.sensorWidthMm,
    this.sensorHeightMm,
    this.focalLengths = const [],
    this.apertures = const [],
    this.hasFlash = false,
    this.hasOis = false,
    this.physicalCount = 0,
  });

  String get mpLabel => megapixels == null ? '?' : '${megapixels!.toStringAsFixed(0)}MP';

  factory CameraSpec.fromMap(Map<dynamic, dynamic> m) {
    return CameraSpec(
      id: (m['id'] ?? '').toString(),
      facing: (m['facing'] ?? 'Unknown').toString(),
      megapixels: (m['megapixels'] as num?)?.toDouble(),
      binnedMegapixels: (m['binnedMegapixels'] as num?)?.toDouble(),
      sensorWidthMm: (m['sensorWidthMm'] as num?)?.toDouble(),
      sensorHeightMm: (m['sensorHeightMm'] as num?)?.toDouble(),
      focalLengths: ((m['focalLengths'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
      apertures: ((m['apertures'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
      hasFlash: m['hasFlash'] == true,
      hasOis: m['hasOis'] == true,
      physicalCount: (m['physicalCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// All measured cameras — true megapixels vs marketing MP, real lens count.
class CameraTruth {
  final List<CameraSpec> cameras;
  const CameraTruth(this.cameras);

  List<CameraSpec> get rear => cameras.where((c) => c.facing == 'Back').toList();
  List<CameraSpec> get front => cameras.where((c) => c.facing == 'Front').toList();
  bool get anyOis => cameras.any((c) => c.hasOis);

  factory CameraTruth.fromList(List<dynamic> list) {
    return CameraTruth(list.map((e) => CameraSpec.fromMap(e as Map)).toList());
  }
}

/// Time since last boot — flags a phone freshly reset to hide its history.
class UptimeTruth {
  final int? uptimeMs;
  final int? bootEpochMs;

  const UptimeTruth({this.uptimeMs, this.bootEpochMs});

  Duration? get sinceBoot => uptimeMs == null ? null : Duration(milliseconds: uptimeMs!);

  String? get humanUptime {
    final d = sinceBoot;
    if (d == null) return null;
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  factory UptimeTruth.fromMap(Map<dynamic, dynamic> m) {
    return UptimeTruth(
      uptimeMs: (m['uptimeMs'] as num?)?.toInt(),
      bootEpochMs: (m['bootEpochMs'] as num?)?.toInt(),
    );
  }
}
