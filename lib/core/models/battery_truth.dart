/// Hardware battery truth — fuel-gauge values resilient to software spoofing.
/// Any field that the device does not expose stays null (never fabricated).
class BatteryTruth {
  final int? cycleCount;
  final int? stateOfHealthPct;
  final int? chargeCounterUah;
  final int? currentNowUa;
  final int? capacityPercent;
  final int? levelPercent;
  final double? temperatureC;
  final int? voltageMilliV;
  final String? technology;
  final int? healthRaw;
  final int? statusRaw;
  final int? pluggedRaw;
  final bool present;
  final int? chargeFull; // uAh, sysfs
  final int? chargeFullDesign; // uAh, sysfs
  final DateTime? manufacturingDate;
  final DateTime? firstUsageDate;
  final bool shizukuAvailable;

  const BatteryTruth({
    this.cycleCount,
    this.stateOfHealthPct,
    this.chargeCounterUah,
    this.currentNowUa,
    this.capacityPercent,
    this.levelPercent,
    this.temperatureC,
    this.voltageMilliV,
    this.technology,
    this.healthRaw,
    this.statusRaw,
    this.pluggedRaw,
    this.present = false,
    this.chargeFull,
    this.chargeFullDesign,
    this.manufacturingDate,
    this.firstUsageDate,
    this.shizukuAvailable = false,
  });

  /// Real capacity in mAh derived from sysfs charge_full, if exposed.
  int? get realCapacityMah =>
      (chargeFull != null && chargeFull! > 0) ? (chargeFull! / 1000).round() : null;

  int? get designCapacityMah => (chargeFullDesign != null && chargeFullDesign! > 0)
      ? (chargeFullDesign! / 1000).round()
      : null;

  /// SoH computed from sysfs if the explicit SoH property isn't present.
  int? get effectiveSoH {
    if (stateOfHealthPct != null && stateOfHealthPct! > 0) return stateOfHealthPct;
    if (realCapacityMah != null && designCapacityMah != null && designCapacityMah! > 0) {
      return (realCapacityMah! * 100 / designCapacityMah!).round();
    }
    return null;
  }

  String get legacyHealthLabel {
    switch (healthRaw) {
      case 2:
        return 'Good';
      case 3:
        return 'Overheat';
      case 4:
        return 'Dead';
      case 5:
        return 'Over-voltage';
      case 6:
        return 'Unspecified failure';
      case 7:
        return 'Cold';
      default:
        return 'Unknown';
    }
  }

  bool get legacyHealthIsBad => healthRaw == 3 || healthRaw == 4 || healthRaw == 5 || healthRaw == 6;

  String get chargingStateLabel {
    switch (statusRaw) {
      case 2:
        return 'Charging';
      case 3:
        return 'Discharging';
      case 4:
        return 'Not charging';
      case 5:
        return 'Full';
      default:
        return 'Unknown';
    }
  }

  String? get plugLabel {
    switch (pluggedRaw) {
      case 1:
        return 'AC (wired)';
      case 2:
        return 'USB';
      case 4:
        return 'Wireless';
      case 0:
        return 'On battery';
      default:
        return null;
    }
  }

  /// Rough age estimate from wear, used for the "claimed vs real" payoff.
  /// Heuristic only — surfaced as a range, clearly approximate.
  String? get estimatedAgeFromWear {
    final soh = effectiveSoH;
    final cyc = cycleCount;
    if (cyc == null && soh == null) return null;
    // ~300-400 full cycles/year typical; ~4-6% SoH loss/year typical.
    double yearsFromCycles = cyc != null ? cyc / 350.0 : -1;
    double yearsFromSoh = soh != null ? (100 - soh) / 5.0 : -1;
    final candidates = [yearsFromCycles, yearsFromSoh].where((y) => y >= 0).toList();
    if (candidates.isEmpty) return null;
    final avg = candidates.reduce((a, b) => a + b) / candidates.length;
    final lo = (avg * 0.8);
    final hi = (avg * 1.25);
    String fmt(double y) {
      if (y < 1) return '${(y * 12).round()} months';
      return '${y.toStringAsFixed(1)} years';
    }
    return '~${fmt(lo)}–${fmt(hi)}';
  }

  factory BatteryTruth.fromMap(Map<dynamic, dynamic> m, {bool shizuku = false}) {
    DateTime? epoch(dynamic v) {
      if (v == null) return null;
      final n = (v as num).toInt();
      if (n <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    }

    int? nz(dynamic v) {
      if (v == null) return null;
      final n = (v as num).toInt();
      return n;
    }

    final tempTenth = m['temperatureTenthC'];
    final volt = m['voltageMilliV'];
    return BatteryTruth(
      cycleCount: nz(m['cycleCount']),
      stateOfHealthPct: nz(m['stateOfHealth']),
      chargeCounterUah: nz(m['chargeCounter']),
      currentNowUa: nz(m['currentNow']),
      capacityPercent: nz(m['capacityPercent']),
      levelPercent: nz(m['levelPercent']),
      temperatureC: (tempTenth is num && tempTenth.toInt() > -1000)
          ? tempTenth / 10.0
          : null,
      voltageMilliV: (volt is num && volt.toInt() > 0) ? volt.toInt() : null,
      technology: m['technology'] as String?,
      healthRaw: nz(m['healthRaw']),
      statusRaw: nz(m['statusRaw']),
      pluggedRaw: nz(m['pluggedRaw']),
      present: m['present'] == true,
      chargeFull: nz(m['chargeFull']),
      chargeFullDesign: nz(m['chargeFullDesign']),
      manufacturingDate: epoch(m['manufacturingDateEpoch']),
      firstUsageDate: epoch(m['firstUsageDateEpoch']),
      shizukuAvailable: shizuku,
    );
  }
}
