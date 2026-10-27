/// How to show a time span: the two largest useful parts.
sealed class DurationParts {
  const DurationParts();

  /// Rounds [duration] up to the next minute, so "resets in 0 min" never shows
  /// while time is left.
  factory DurationParts.of(Duration duration) {
    final totalMinutes = duration.isNegative
        ? 0
        : (duration.inSeconds + 59) ~/ 60;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes ~/ 60) % 24;
    final minutes = totalMinutes % 60;
    if (days > 0) return DaysHours(days, hours);
    if (hours > 0) return HoursMinutes(hours, minutes);
    return Minutes(minutes);
  }
}

final class DaysHours extends DurationParts {
  const DaysHours(this.days, this.hours);

  final int days;
  final int hours;

  @override
  bool operator ==(Object other) =>
      other is DaysHours && other.days == days && other.hours == hours;

  @override
  int get hashCode => Object.hash(days, hours);
}

final class HoursMinutes extends DurationParts {
  const HoursMinutes(this.hours, this.minutes);

  final int hours;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is HoursMinutes && other.hours == hours && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(hours, minutes);
}

final class Minutes extends DurationParts {
  const Minutes(this.minutes);

  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is Minutes && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;
}
