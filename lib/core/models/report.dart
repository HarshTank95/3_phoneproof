import 'battery_truth.dart';
import 'spec_truth.dart';
import 'test_result.dart';

enum ScanMode { buyer, seller }

/// What the seller claims (optional). Powers the "claimed vs real" lie-detector.
class Claim {
  final String? model;
  final int? ageMonths;
  final String? condition; // e.g. "Like new", "Good", "Fair"
  final String? claimedTier; // "flagship" | "midrange" | "budget"

  const Claim({this.model, this.ageMonths, this.condition, this.claimedTier});

  bool get isEmpty => model == null && ageMonths == null && condition == null;
}

enum Verdict { genuine, caution, highRisk }

extension VerdictX on Verdict {
  String get label {
    switch (this) {
      case Verdict.genuine:
        return 'Genuine & Healthy';
      case Verdict.caution:
        return 'Caution';
      case Verdict.highRisk:
        return 'High Risk';
    }
  }
}

/// The full assembled result of a scan.
class Report {
  final String reportId;
  final DateTime timestamp;
  final ScanMode mode;
  final Claim claim;

  final BuildTruth build;
  final BatteryTruth battery;
  final DisplayTruth display;
  final SensorInventory sensors;
  final CpuTruth cpu;
  final RamTruth ram;
  final StorageTruth storage;
  final AuthenticityTruth authenticity;

  final List<CheckGroup> groups;

  final int trustScore;
  final Verdict verdict;
  final List<ScoreReason> reasons;

  /// Detected claim mismatches (the emotional payoff).
  final List<ClaimMismatch> mismatches;

  final String? imei; // user-entered, unverifiable

  final String payloadHash; // SHA-256 of the canonical payload

  const Report({
    required this.reportId,
    required this.timestamp,
    required this.mode,
    required this.claim,
    required this.build,
    required this.battery,
    required this.display,
    required this.sensors,
    required this.cpu,
    required this.ram,
    required this.storage,
    required this.authenticity,
    required this.groups,
    required this.trustScore,
    required this.verdict,
    required this.reasons,
    required this.mismatches,
    required this.payloadHash,
    this.imei,
  });
}

class ScoreReason {
  final String text;
  final int delta; // negative = deduction
  final ReasonSeverity severity;
  const ScoreReason(this.text, this.delta, this.severity);
}

enum ReasonSeverity { critical, major, minor, positive }

/// A single claimed-vs-real conflict.
class ClaimMismatch {
  final String label;
  final String claimed;
  final String real;
  final String note;
  const ClaimMismatch({
    required this.label,
    required this.claimed,
    required this.real,
    required this.note,
  });
}
