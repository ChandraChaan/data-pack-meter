import 'package:data_pack_meter/core/time/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Central European time in 2026: +1, +2 from 29 March, +1 from 25 October.
Duration berlin(DateTime utc) {
  if (utc.isBefore(DateTime.utc(2026, 3, 29, 1))) {
    return const Duration(hours: 1);
  }
  if (utc.isBefore(DateTime.utc(2026, 10, 25, 1))) {
    return const Duration(hours: 2);
  }
  return const Duration(hours: 1);
}

void main() {
  const wall = WallClock(berlin);

  test('round-trips ordinary times', () {
    final utc = DateTime.utc(2026, 7, 1, 10, 15);
    expect(wall.toWall(utc), DateTime.utc(2026, 7, 1, 12, 15));
    expect(wall.toUtc(DateTime.utc(2026, 7, 1, 12, 15)), utc);
  });

  test('a wall time in the spring gap moves later by the gap', () {
    // 02:30 never happens on 29 March; it maps to 03:30 local.
    expect(
      wall.toUtc(DateTime.utc(2026, 3, 29, 2, 30)),
      DateTime.utc(2026, 3, 29, 1, 30),
    );
  });

  test('an ambiguous autumn wall time picks the earlier instant', () {
    // 02:30 happens twice on 25 October.
    expect(
      wall.toUtc(DateTime.utc(2026, 10, 25, 2, 30)),
      DateTime.utc(2026, 10, 25, 0, 30),
    );
  });

  test('works the same whatever DateTime kind it is given', () {
    final local = DateTime(2026, 7, 1, 12, 15);
    expect(wall.toUtc(local), DateTime.utc(2026, 7, 1, 10, 15));
  });
}
