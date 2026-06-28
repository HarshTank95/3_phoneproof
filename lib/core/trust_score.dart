import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'models/battery_truth.dart';
import 'models/report.dart';
import 'models/spec_truth.dart';
import 'models/test_result.dart';

/// Aggregates every truth source into a 0–100 Trust Score with a transparent
/// list of reasons, plus the grouped result cards and claim mismatches.
class TrustScoreEngine {
  static Report build({
    required ScanMode mode,
    required Claim claim,
    required BuildTruth build,
    required BatteryTruth battery,
    required DisplayTruth display,
    required SensorInventory sensors,
    required CpuTruth cpu,
    required RamTruth ram,
    required StorageTruth storage,
    required AuthenticityTruth authenticity,
    required CheckGroup functional,
    String? imei,
  }) {
    final reasons = <ScoreReason>[];
    int score = 100;
    bool critical = false;

    void deduct(String text, int amount, ReasonSeverity sev) {
      reasons.add(ScoreReason(text, -amount, sev));
      score -= amount;
      if (sev == ReasonSeverity.critical) critical = true;
    }

    // ---- Authenticity (critical signals) ----
    if (authenticity.isEmulator) {
      deduct('Running on an emulator, not real hardware', 60, ReasonSeverity.critical);
    }
    if (authenticity.integrity == IntegrityVerdict.fails) {
      deduct('Failed Google device-integrity (common with clones/tampered phones)',
          50, ReasonSeverity.critical);
    }
    if (authenticity.isRooted) {
      deduct('Root / Magisk indicators present', 12, ReasonSeverity.major);
    }
    if (!build.versionConsistent) {
      deduct('Android version inconsistent with API level', 15, ReasonSeverity.major);
    }

    // ---- Storage capacity (critical) ----
    if (storage.verified == false) {
      deduct('Storage failed write-verify — possible fake capacity', 60,
          ReasonSeverity.critical);
    }
    if (storage.seqWriteMbps >= 0 && storage.seqWriteMbps < 15) {
      deduct('Implausibly slow storage (${storage.seqWriteMbps.toStringAsFixed(0)} MB/s)',
          18, ReasonSeverity.major);
    }

    // ---- Sensors (claimed flagship must have core sensors) ----
    final missingCore = <String>[];
    if (!sensors.hasAccelerometer) missingCore.add('accelerometer');
    if (!sensors.hasGyroscope) missingCore.add('gyroscope');
    if (!sensors.hasMagnetometer) missingCore.add('compass');
    final claimsFlagship = claim.claimedTier == 'flagship';
    if (missingCore.isNotEmpty) {
      if (claimsFlagship) {
        deduct('Missing core sensors a flagship must have: ${missingCore.join(", ")}',
            35, ReasonSeverity.critical);
      } else if (!sensors.hasAccelerometer) {
        deduct('No accelerometer detected', 20, ReasonSeverity.major);
      } else {
        deduct('Missing sensor(s): ${missingCore.join(", ")}', 8, ReasonSeverity.minor);
      }
    }

    // ---- CPU vs claimed tier ----
    if (claim.claimedTier != null) {
      final tier = _cpuTier(cpu);
      if (claim.claimedTier == 'flagship' && tier == 'budget') {
        deduct('CPU looks budget-class but sold as flagship', 40, ReasonSeverity.critical);
      } else if (claim.claimedTier == 'flagship' && tier == 'midrange') {
        deduct('CPU is mid-range, weaker than a flagship claim', 15, ReasonSeverity.major);
      }
    }

    // ---- Battery health ----
    final soh = battery.effectiveSoH;
    if (soh != null) {
      if (soh < 70) {
        deduct('Battery health low ($soh%)', 18, ReasonSeverity.major);
      } else if (soh < 80) {
        deduct('Battery health moderate ($soh%)', 8, ReasonSeverity.minor);
      } else {
        reasons.add(ScoreReason('Battery health good ($soh%)', 0, ReasonSeverity.positive));
      }
    }
    if (battery.cycleCount != null && battery.cycleCount! > 800) {
      deduct('High charge-cycle count (${battery.cycleCount})', 12, ReasonSeverity.major);
    }
    if (battery.legacyHealthIsBad) {
      deduct('Battery reports "${battery.legacyHealthLabel}"', 15, ReasonSeverity.major);
    }

    // ---- Functional tests ----
    final essentialFails = functional.checks.where((c) =>
        c.status == CheckStatus.fail &&
        const ['touch', 'speaker', 'mic', 'cam_rear', 'cam_front'].contains(c.id));
    for (final f in essentialFails) {
      deduct('Failed essential test: ${f.title}', 12, ReasonSeverity.major);
    }
    final cosmeticFails = functional.checks.where((c) =>
        c.status == CheckStatus.fail && !essentialFails.contains(c));
    for (final f in cosmeticFails) {
      deduct('Failed test: ${f.title}', 4, ReasonSeverity.minor);
    }

    // ---- Claim mismatches ----
    final mismatches = _mismatches(claim, battery, cpu);
    for (final mm in mismatches) {
      if (mm.label == 'Age') {
        deduct('Claimed age conflicts with battery wear', 14, ReasonSeverity.major);
      }
    }

    // Clamp & cap.
    if (critical) score = score.clamp(0, 30);
    score = score.clamp(0, 100);

    final verdict = _verdict(score, critical);

    // Sort reasons: deductions first by magnitude, positives last.
    reasons.sort((a, b) => a.delta.compareTo(b.delta));

    final groups = _buildGroups(
      battery: battery,
      display: display,
      sensors: sensors,
      cpu: cpu,
      ram: ram,
      storage: storage,
      authenticity: authenticity,
      build: build,
      functional: functional,
      imei: imei,
    );

    final reportId = _reportId();
    final ts = DateTime.now();
    final hash = _hashPayload(reportId, ts, build, score, groups);

    return Report(
      reportId: reportId,
      timestamp: ts,
      mode: mode,
      claim: claim,
      build: build,
      battery: battery,
      display: display,
      sensors: sensors,
      cpu: cpu,
      ram: ram,
      storage: storage,
      authenticity: authenticity,
      groups: groups,
      trustScore: score,
      verdict: verdict,
      reasons: reasons,
      mismatches: mismatches,
      payloadHash: hash,
      imei: imei,
    );
  }

  // ---------------------------------------------------------------- helpers

  static String _cpuTier(CpuTruth cpu) {
    // Heuristic from multi-core benchmark score + max clock. Clearly approximate.
    final s = cpu.multiScore;
    if (s >= 9000 || cpu.maxFreqGhz >= 2.8) return 'flagship';
    if (s >= 4500 || cpu.maxFreqGhz >= 2.2) return 'midrange';
    return 'budget';
  }

  static Verdict _verdict(int score, bool critical) {
    if (critical || score < 40) return Verdict.highRisk;
    if (score < 75) return Verdict.caution;
    return Verdict.genuine;
  }

  static List<ClaimMismatch> _mismatches(Claim claim, BatteryTruth battery, CpuTruth cpu) {
    final out = <ClaimMismatch>[];
    // Age vs battery wear.
    final est = battery.estimatedAgeFromWear;
    if (claim.ageMonths != null && est != null) {
      final claimedYears = claim.ageMonths! / 12.0;
      // crude lower-bound parse of estimate not needed; compare with cycles.
      final cyc = battery.cycleCount;
      final soh = battery.effectiveSoH;
      // Expected cycles for claimed age ~ 350/yr.
      if (cyc != null) {
        final expected = claimedYears * 350;
        if (cyc > expected * 1.8 && cyc > 200) {
          out.add(ClaimMismatch(
            label: 'Age',
            claimed: '${claim.ageMonths} months',
            real: '$cyc cycles${soh != null ? ', ~$soh% health' : ''} (est. $est)',
            note: 'Battery wear suggests significantly more use than claimed.',
          ));
        }
      } else if (soh != null && claimedYears < 1 && soh < 85) {
        out.add(ClaimMismatch(
          label: 'Age',
          claimed: '${claim.ageMonths} months',
          real: '~$soh% health (est. $est)',
          note: 'Health is lower than expected for a phone this young.',
        ));
      }
    }
    // Tier vs CPU.
    if (claim.claimedTier == 'flagship') {
      final tier = _cpuTier(cpu);
      if (tier != 'flagship') {
        out.add(ClaimMismatch(
          label: 'Performance',
          claimed: 'Flagship-class',
          real: '${cpu.maxFreqGhz.toStringAsFixed(2)} GHz, $tier benchmark',
          note: 'Measured performance is below flagship expectations.',
        ));
      }
    }
    return out;
  }

  static List<CheckGroup> _buildGroups({
    required BatteryTruth battery,
    required DisplayTruth display,
    required SensorInventory sensors,
    required CpuTruth cpu,
    required RamTruth ram,
    required StorageTruth storage,
    required AuthenticityTruth authenticity,
    required BuildTruth build,
    required CheckGroup functional,
    String? imei,
  }) {
    CheckResult avail(String id, String title, dynamic value, String unit,
        {String meaning = '', CheckStatus statusIfPresent = CheckStatus.info}) {
      if (value == null) {
        return CheckResult(
            id: id,
            title: title,
            status: CheckStatus.unavailable,
            detail: 'Not reported by this device',
            meaning: meaning);
      }
      return CheckResult(
          id: id,
          title: title,
          status: statusIfPresent,
          detail: '$value$unit',
          meaning: meaning);
    }

    // ---- Battery Truth ----
    final soh = battery.effectiveSoH;
    final batteryChecks = <CheckResult>[
      CheckResult(
        id: 'soh',
        title: 'State of Health',
        status: soh == null
            ? CheckStatus.unavailable
            : soh >= 80
                ? CheckStatus.pass
                : soh >= 70
                    ? CheckStatus.caution
                    : CheckStatus.fail,
        detail: soh == null ? 'Not reported by this device' : '$soh%',
        meaning: 'Real capacity vs factory. Stored in the fuel-gauge chip — hard to fake.',
      ),
      CheckResult(
        id: 'cycles',
        title: 'Charge cycles',
        status: battery.cycleCount == null
            ? CheckStatus.unavailable
            : battery.cycleCount! > 800
                ? CheckStatus.caution
                : CheckStatus.pass,
        detail: battery.cycleCount == null
            ? 'Not reported by this device'
            : '${battery.cycleCount} cycles',
        meaning: 'How many full charges the battery has seen. ~300–400/yr is typical.',
      ),
      CheckResult(
        id: 'realmah',
        title: 'Real capacity',
        status: battery.realCapacityMah == null ? CheckStatus.unavailable : CheckStatus.info,
        detail: battery.realCapacityMah == null
            ? 'Needs Shizuku / root'
            : '${battery.realCapacityMah} mAh'
                '${battery.designCapacityMah != null ? ' of ${battery.designCapacityMah} mAh' : ''}',
        meaning: 'Measured full-charge capacity from sysfs.',
      ),
      CheckResult(
        id: 'mfgdate',
        title: 'Manufacturing date',
        status: battery.manufacturingDate == null ? CheckStatus.unavailable : CheckStatus.info,
        detail: battery.manufacturingDate == null
            ? 'Android 15+ / Shizuku only'
            : _fmtDate(battery.manufacturingDate!),
        meaning: 'When the battery cell was made (Box-Ready devices).',
      ),
      CheckResult(
        id: 'legacyhealth',
        title: 'Battery health (legacy)',
        status: battery.healthRaw == null
            ? CheckStatus.unavailable
            : battery.legacyHealthIsBad
                ? CheckStatus.fail
                : CheckStatus.pass,
        detail: battery.healthRaw == null ? 'Unavailable' : battery.legacyHealthLabel,
        meaning: 'OS-level health flag — available on all devices.',
      ),
      avail('level', 'Charge level',
          (battery.levelPercent ?? battery.capacityPercent), '%',
          meaning: 'Current battery charge.'),
      avail('temp', 'Temperature', battery.temperatureC?.toStringAsFixed(1), ' °C',
          meaning: 'Live cell temperature.'),
      avail('voltage', 'Voltage', battery.voltageMilliV, ' mV', meaning: 'Live cell voltage.'),
      CheckResult(
        id: 'charging',
        title: 'Charging state',
        status: CheckStatus.info,
        detail: '${battery.chargingStateLabel}'
            '${battery.plugLabel != null ? ' · ${battery.plugLabel}' : ''}',
        meaning: 'Live charging status and connection type.',
      ),
      avail('tech', 'Technology', battery.technology, '', meaning: 'Cell chemistry.'),
      CheckResult(
        id: 'chargenow',
        title: 'Charge stored now',
        status: battery.chargeCounterUah == null ? CheckStatus.unavailable : CheckStatus.info,
        detail: battery.chargeCounterUah == null
            ? 'Not reported by this device'
            : '${(battery.chargeCounterUah! / 1000).round()} mAh (coulomb counter)',
        meaning: 'Charge currently in the cell, straight from the fuel-gauge.',
      ),
    ];

    // ---- Spec Truth ----
    final specChecks = <CheckResult>[
      CheckResult(
        id: 'storage_verify',
        title: 'Storage capacity (write-verify)',
        status: storage.verified == null
            ? CheckStatus.skipped
            : storage.verified!
                ? CheckStatus.pass
                : CheckStatus.fail,
        detail: storage.verified == null
            ? 'Not run'
            : storage.verified!
                ? 'Verified ${_gb(storage.totalBytes)} usable (sampled ${_mb(storage.sampleBytes)})'
                : 'Mismatch: ${_mb(storage.mismatchBytes)} corrupt — fake capacity likely',
        meaning: 'We wrote random data and read it back. Fakes fail this.',
      ),
      CheckResult(
        id: 'storage_speed',
        title: 'Storage speed',
        status: storage.seqWriteMbps < 0
            ? CheckStatus.skipped
            : storage.seqWriteMbps < 15
                ? CheckStatus.fail
                : CheckStatus.pass,
        detail: storage.seqWriteMbps < 0
            ? 'Not run'
            : 'W ${storage.seqWriteMbps.toStringAsFixed(0)} · R ${storage.seqReadMbps.toStringAsFixed(0)} MB/s · rnd ${storage.randReadMbps.toStringAsFixed(1)}',
        meaning: 'Implausibly slow storage signals a counterfeit chip.',
      ),
      CheckResult(
        id: 'display',
        title: 'Display (measured)',
        status: CheckStatus.info,
        detail: '${display.resolutionLabel} · ${display.densityDpi} dpi · ${display.maxRefresh.toStringAsFixed(0)} Hz',
        meaning: 'Real resolution and refresh rate, not the "About" screen.',
      ),
      CheckResult(
        id: 'cpu',
        title: 'CPU / SoC',
        status: CheckStatus.info,
        detail: '${cpu.cores} cores · ${cpu.maxFreqGhz > 0 ? '${cpu.maxFreqGhz.toStringAsFixed(2)} GHz' : 'freq n/a'} · ${cpu.is64bit ? '64-bit' : '32-bit'}'
            '${cpu.hardware != null ? ' · ${cpu.hardware}' : ''}',
        meaning: 'Measured cores and clocks.',
      ),
      CheckResult(
        id: 'cpu_bench',
        title: 'CPU benchmark',
        status: cpu.multiScore == 0 ? CheckStatus.skipped : CheckStatus.info,
        detail: cpu.multiScore == 0
            ? 'Not run'
            : 'Single ${cpu.singleScore} · Multi ${cpu.multiScore} (${_cpuTier(cpu)})',
        meaning: 'Quick compute test to sanity-check the chip class.',
      ),
      CheckResult(
        id: 'ram',
        title: 'RAM',
        status: CheckStatus.info,
        detail: '${ram.totalGb.toStringAsFixed(1)} GB'
            '${ram.hasVirtualRam ? ' (+${ram.zramGb > 0 ? '${ram.zramGb.toStringAsFixed(1)} GB zRAM' : 'virtual RAM'})' : ''}',
        meaning: 'Physical RAM; virtual/zRAM is flagged separately.',
      ),
      CheckResult(
        id: 'sensors',
        title: 'Sensor inventory',
        status: (!sensors.hasAccelerometer || !sensors.hasGyroscope || !sensors.hasMagnetometer)
            ? CheckStatus.caution
            : CheckStatus.pass,
        detail: '${sensors.sensors.length} sensors'
            ' · ${[
          if (sensors.hasGyroscope) 'gyro',
          if (sensors.hasMagnetometer) 'compass',
          if (sensors.hasBarometer) 'barometer',
          if (sensors.hasProximity) 'proximity',
          if (sensors.hasLight) 'light',
        ].join(', ')}',
        meaning: 'Components actually present — missing ones are suspicious on flagships.',
      ),
      CheckResult(
        id: 'build_sanity',
        title: 'Build / environment',
        status: build.versionConsistent ? CheckStatus.pass : CheckStatus.caution,
        detail: 'Android ${build.release} (API ${build.sdkInt}) · ${build.type}'
            '${build.securityPatch != null ? ' · patch ${build.securityPatch}' : ''}',
        meaning: 'Android version ↔ API consistency and build type.',
      ),
    ];

    // ---- Authenticity ----
    final authChecks = <CheckResult>[
      CheckResult(
        id: 'integrity',
        title: 'Certified genuine (Play Integrity)',
        status: switch (authenticity.integrity) {
          IntegrityVerdict.meets => CheckStatus.pass,
          IntegrityVerdict.fails => CheckStatus.fail,
          _ => CheckStatus.unavailable,
        },
        detail: switch (authenticity.integrity) {
          IntegrityVerdict.meets => 'Google-certified genuine device',
          IntegrityVerdict.fails => 'Not certified — common with clones, fakes & tampered phones',
          IntegrityVerdict.error => 'Check failed (offline?)',
          IntegrityVerdict.notChecked => 'Not checked (no backend configured)',
        },
        meaning: 'Hardware-backed device verdict. A strong signal, not absolute proof.',
      ),
      CheckResult(
        id: 'emulator',
        title: 'Emulator detection',
        status: authenticity.isEmulator ? CheckStatus.fail : CheckStatus.pass,
        detail: authenticity.isEmulator
            ? authenticity.emulatorReasons.join('; ')
            : 'Real hardware (no emulator markers)',
        meaning: 'On-device heuristic — fast, offline, approximate.',
      ),
      CheckResult(
        id: 'root',
        title: 'Root / bootloader',
        status: authenticity.isRooted ? CheckStatus.caution : CheckStatus.pass,
        detail: authenticity.isRooted
            ? authenticity.rootReasons.join('; ')
            : 'No root markers found',
        meaning: 'Heuristic root check — can be fooled; treat as a signal.',
      ),
      CheckResult(
        id: 'imei',
        title: 'IMEI',
        status: CheckStatus.info,
        detail: imei != null && imei.isNotEmpty ? '$imei (entered, unverifiable)' : 'Dial *#06# to view',
        meaning: 'Third-party apps cannot read IMEI on Android 10+. Verify manually.',
      ),
    ];

    return [
      CheckGroup(id: 'battery', title: 'Battery Truth', icon: Icons.battery_charging_full_rounded, checks: _ordered(batteryChecks)),
      CheckGroup(id: 'spec', title: 'Spec Truth', icon: Icons.memory_rounded, checks: _ordered(specChecks)),
      CheckGroup(id: 'auth', title: 'Authenticity', icon: Icons.verified_user_rounded, checks: _ordered(authChecks)),
      CheckGroup(id: functional.id, title: functional.title, icon: functional.icon, checks: _ordered(functional.checks)),
    ];
  }

  /// Surface the meaningful rows first (failures → real data) and sink the
  /// rows a device simply doesn't expose to the bottom, so a report never
  /// *opens* on a wall of "Unavailable". Stable within each rank.
  static int _statusRank(CheckStatus s) {
    switch (s) {
      case CheckStatus.fail:
        return 0;
      case CheckStatus.caution:
        return 1;
      case CheckStatus.pass:
        return 2;
      case CheckStatus.info:
        return 3;
      case CheckStatus.skipped:
        return 4;
      case CheckStatus.unavailable:
        return 5;
    }
  }

  static List<CheckResult> _ordered(List<CheckResult> checks) {
    final indexed = checks.asMap().entries.toList();
    indexed.sort((a, b) {
      final r = _statusRank(a.value.status).compareTo(_statusRank(b.value.status));
      return r != 0 ? r : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  // ---------------------------------------------------------------- format/hash

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _gb(int bytes) => '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  static String _reportId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'PP-$ts';
  }

  static String _hashPayload(
      String id, DateTime ts, BuildTruth build, int score, List<CheckGroup> groups) {
    final payload = {
      'id': id,
      'ts': ts.toIso8601String(),
      'device': build.marketName,
      'fingerprint': build.fingerprint,
      'score': score,
      'groups': groups.map((g) => g.toJson()).toList(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    return sha256.convert(bytes).toString();
  }
}
