import 'package:flutter/material.dart';
import '../../ui/theme.dart';

/// Verdict status for any check. Always rendered as icon + label + colour so it
/// remains colour-blind safe.
enum CheckStatus { pass, fail, caution, skipped, unavailable, info }

extension CheckStatusX on CheckStatus {
  String get label {
    switch (this) {
      case CheckStatus.pass:
        return 'PASS';
      case CheckStatus.fail:
        return 'FAIL';
      case CheckStatus.caution:
        return 'CAUTION';
      case CheckStatus.skipped:
        return 'SKIPPED';
      case CheckStatus.unavailable:
        return 'UNAVAILABLE';
      case CheckStatus.info:
        return 'INFO';
    }
  }

  IconData get icon {
    switch (this) {
      case CheckStatus.pass:
        return Icons.check_circle_rounded;
      case CheckStatus.fail:
        return Icons.cancel_rounded;
      case CheckStatus.caution:
        return Icons.warning_amber_rounded;
      case CheckStatus.skipped:
        return Icons.remove_circle_outline_rounded;
      case CheckStatus.unavailable:
        return Icons.help_outline_rounded;
      case CheckStatus.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CheckStatus.pass:
        return AppColors.good;
      case CheckStatus.fail:
        return AppColors.risk;
      case CheckStatus.caution:
        return AppColors.caution;
      case CheckStatus.skipped:
      case CheckStatus.unavailable:
        return AppColors.unknown;
      case CheckStatus.info:
        return AppColors.accent;
    }
  }
}

/// One row in a result card.
class CheckResult {
  final String id;
  final String title;
  final CheckStatus status;

  /// Measured value / short detail (e.g. "480 cycles", "Not reported by this device").
  final String detail;

  /// One-line plain-language explanation of what it means.
  final String meaning;

  const CheckResult({
    required this.id,
    required this.title,
    required this.status,
    this.detail = '',
    this.meaning = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.name,
        'detail': detail,
      };
}

/// A grouped section of checks (Battery Truth, Spec Truth, etc.).
class CheckGroup {
  final String id;
  final String title;
  final IconData icon;
  final List<CheckResult> checks;

  const CheckGroup({
    required this.id,
    required this.title,
    required this.icon,
    required this.checks,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'checks': checks.map((c) => c.toJson()).toList()};
}
