import 'dart:math' as math;

import '../../../core/time/clock.dart';
import 'pack_plan.dart';

/// One allowance window, from a reset to the next one, as UTC instants.
final class PackPeriod {
  const PackPeriod({required this.startUtc, required this.endUtc});

  /// The current period of [plan] at [nowUtc], in the time zone of [wall].
  ///
  /// Resets happen at local midnight, so the window follows the phone's time
  /// zone: travel east and the day ends earlier in UTC terms.
  factory PackPeriod.current(PackPlan plan, DateTime nowUtc, WallClock wall) {
    final now = wall.toWall(nowUtc);
    final (DateTime start, DateTime end) = switch (plan) {
      DailyPack() => (
        DateTime.utc(now.year, now.month, now.day),
        DateTime.utc(now.year, now.month, now.day + 1),
      ),
      MonthlyPack(:final resetDay) => _monthlyWindow(now, resetDay),
    };
    return PackPeriod(startUtc: wall.toUtc(start), endUtc: wall.toUtc(end));
  }

  /// Today from local midnight to the next one, whatever the plan.
  factory PackPeriod.today(DateTime nowUtc, WallClock wall) =>
      PackPeriod.current(const DailyPack(limitBytes: 1), nowUtc, wall);

  /// The last [days] days including today, starting at a local midnight.
  factory PackPeriod.lastDays(int days, DateTime nowUtc, WallClock wall) {
    assert(days >= 1, 'days must be at least 1');
    final now = wall.toWall(nowUtc);
    final start = DateTime.utc(now.year, now.month, now.day - (days - 1));
    final end = DateTime.utc(now.year, now.month, now.day + 1);
    return PackPeriod(startUtc: wall.toUtc(start), endUtc: wall.toUtc(end));
  }

  final DateTime startUtc;
  final DateTime endUtc;

  Duration timeLeft(DateTime nowUtc) {
    final left = endUtc.difference(nowUtc);
    return left.isNegative ? Duration.zero : left;
  }

  static (DateTime, DateTime) _monthlyWindow(DateTime now, int resetDay) {
    final thisMonth = _resetIn(now.year, now.month, resetDay);
    if (!now.isBefore(thisMonth)) {
      return (thisMonth, _resetIn(now.year, now.month + 1, resetDay));
    }
    return (_resetIn(now.year, now.month - 1, resetDay), thisMonth);
  }

  /// Midnight on [resetDay] of the given month, or its last day if shorter.
  /// [month] may be 0 or 13; it is normalised into the right year.
  static DateTime _resetIn(int year, int month, int resetDay) {
    final first = DateTime.utc(year, month);
    final daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    return DateTime.utc(
      first.year,
      first.month,
      math.min(resetDay, daysInMonth),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackPeriod &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(startUtc, endUtc);

  @override
  String toString() => 'PackPeriod($startUtc → $endUtc)';
}
