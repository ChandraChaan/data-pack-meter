import 'pack_period.dart';
import 'pack_plan.dart';

/// Fractions of the pack at which the user gets an alert.
const List<double> kAlertThresholds = [0.8, 1.0];

enum PackLevel {
  /// Under 80% of the pack.
  ok,

  /// 80% or more.
  nearLimit,

  /// The whole pack is used.
  exceeded;

  static PackLevel forFraction(double fraction) {
    if (fraction >= kAlertThresholds[1]) return PackLevel.exceeded;
    if (fraction >= kAlertThresholds[0]) return PackLevel.nearLimit;
    return PackLevel.ok;
  }
}

/// Where the user stands against their pack right now.
final class PackStatus {
  const PackStatus({
    required this.plan,
    required this.period,
    required this.usedBytes,
    required this.nowUtc,
  });

  final PackPlan plan;
  final PackPeriod period;
  final int usedBytes;
  final DateTime nowUtc;

  int get limitBytes => plan.limitBytes;

  /// 0 when nothing is used, 1 at the limit, above 1 when over it.
  double get fraction => limitBytes <= 0 ? 0 : usedBytes / limitBytes;

  int get remainingBytes =>
      usedBytes >= limitBytes ? 0 : limitBytes - usedBytes;

  int get overBytes => usedBytes > limitBytes ? usedBytes - limitBytes : 0;

  PackLevel get level => PackLevel.forFraction(fraction);

  Duration get timeLeft => period.timeLeft(nowUtc);

  /// Whole percent used, rounded down so 99.6% never reads as 100%.
  int get percentUsed => (fraction * 100).floor();

  @override
  bool operator ==(Object other) =>
      other is PackStatus &&
      other.plan == plan &&
      other.period == period &&
      other.usedBytes == usedBytes &&
      other.nowUtc == nowUtc;

  @override
  int get hashCode => Object.hash(plan, period, usedBytes, nowUtc);
}
