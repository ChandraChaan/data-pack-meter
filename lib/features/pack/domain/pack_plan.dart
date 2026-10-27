import 'dart:math' as math;

/// The user's mobile data allowance.
sealed class PackPlan {
  const PackPlan({required this.limitBytes});

  /// How much mobile data the pack allows per period, in bytes.
  final int limitBytes;
}

/// A fresh allowance every day at local midnight, like "1.5 GB a day".
final class DailyPack extends PackPlan {
  const DailyPack({required super.limitBytes});

  DailyPack copyWith({int? limitBytes}) =>
      DailyPack(limitBytes: limitBytes ?? this.limitBytes);

  @override
  bool operator ==(Object other) =>
      other is DailyPack && other.limitBytes == limitBytes;

  @override
  int get hashCode => Object.hash(DailyPack, limitBytes);
}

/// One allowance per month, renewed at local midnight on [resetDay].
///
/// In months shorter than [resetDay] the pack renews on the last day.
final class MonthlyPack extends PackPlan {
  const MonthlyPack({required super.limitBytes, required this.resetDay})
    : assert(resetDay >= 1 && resetDay <= 31, 'resetDay must be 1 to 31');

  final int resetDay;

  MonthlyPack copyWith({int? limitBytes, int? resetDay}) => MonthlyPack(
    limitBytes: limitBytes ?? this.limitBytes,
    resetDay: resetDay ?? this.resetDay,
  );

  @override
  bool operator ==(Object other) =>
      other is MonthlyPack &&
      other.limitBytes == limitBytes &&
      other.resetDay == resetDay;

  @override
  int get hashCode => Object.hash(MonthlyPack, limitBytes, resetDay);
}

/// Everything the user configured about their pack.
final class PackSettings {
  const PackSettings({this.plan, this.alertsEnabled = true});

  /// `null` until the user sets up a pack.
  final PackPlan? plan;

  /// Whether to notify at 80% and 100% of the pack.
  final bool alertsEnabled;

  PackSettings copyWith({PackPlan? plan, bool? alertsEnabled}) => PackSettings(
    plan: plan ?? this.plan,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
  );

  @override
  bool operator ==(Object other) =>
      other is PackSettings &&
      other.plan == plan &&
      other.alertsEnabled == alertsEnabled;

  @override
  int get hashCode => Object.hash(plan, alertsEnabled);
}

/// Checks a pack amount the user typed, in bytes.
///
/// Returns `null` when valid, otherwise why it is not.
PackLimitError? validatePackLimit(int? bytes) {
  if (bytes == null) return PackLimitError.notANumber;
  if (bytes <= 0) return PackLimitError.tooSmall;
  // 100 TB: anything larger is a typo, and it keeps the math far from overflow.
  if (bytes > 100 * 1024 * 1024 * 1024 * 1024) return PackLimitError.tooLarge;
  return null;
}

enum PackLimitError { notANumber, tooSmall, tooLarge }

/// Turns what the user typed, like "1.5" or "1,5", into bytes of [unitBytes].
///
/// Returns `null` when the text is not a plain decimal number.
int? parsePackAmount(String text, int unitBytes) {
  final normalised = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalised)) return null;
  final value = double.tryParse(normalised);
  if (value == null) return null;
  // Clamp absurd input so it stays a valid int; validatePackLimit rejects it.
  return math.min(value * unitBytes, 1e18).round();
}
