/// The current time and the device's time zone, injectable for tests.
abstract interface class Clock {
  DateTime nowUtc();

  /// The local time zone's offset from UTC at the instant [utc].
  Duration offsetAt(DateTime utc);
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  Duration offsetAt(DateTime utc) => utc.toLocal().timeZoneOffset;
}

/// Converts between UTC instants and wall-clock times of one time zone.
///
/// Wall-clock times are represented as `DateTime.utc` values whose fields are
/// the local fields, so calendar arithmetic never depends on the time zone of
/// the machine running the code.
final class WallClock {
  const WallClock(this._offsetAt);

  WallClock.of(Clock clock) : this(clock.offsetAt);

  final Duration Function(DateTime utc) _offsetAt;

  DateTime toWall(DateTime utc) {
    final u = utc.toUtc();
    return u.add(_offsetAt(u));
  }

  /// The instant at which the wall clock shows [wall].
  ///
  /// When [wall] falls in a daylight-saving gap it is moved later by the
  /// length of the gap; when it is ambiguous (clocks going back), the earlier
  /// instant wins.
  DateTime toUtc(DateTime wall) {
    final asUtc = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
    );
    // Try the offsets in force just before and just after this wall time.
    final before = _offsetAt(asUtc.subtract(const Duration(days: 1)));
    final after = _offsetAt(asUtc.add(const Duration(days: 1)));
    final candidates = <DateTime>{
      asUtc.subtract(before),
      asUtc.subtract(after),
    }.where((c) => toWall(c) == asUtc).toList()..sort();
    if (candidates.isNotEmpty) return candidates.first;
    // In a gap the wall time never happens: shift it later by the gap's
    // length, like java.time does, so a missing midnight becomes 01:00.
    return asUtc.subtract(before);
  }
}
