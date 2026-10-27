import 'package:data_pack_meter/core/time/clock.dart';
import 'package:data_pack_meter/features/pack/domain/pack_period.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

WallClock fixedZone(Duration offset) => WallClock((_) => offset);

PackPeriod period(DateTime start, DateTime end) =>
    PackPeriod(startUtc: start, endUtc: end);

void main() {
  const daily = DailyPack(limitBytes: gb);

  group('daily pack', () {
    test('runs from local midnight to the next one (IST)', () {
      // 01:30 on 28 October in India.
      final now = DateTime.utc(2026, 10, 27, 20);
      expect(
        PackPeriod.current(daily, now, fixedZone(ist)),
        period(
          DateTime.utc(2026, 10, 27, 18, 30),
          DateTime.utc(2026, 10, 28, 18, 30),
        ),
      );
    });

    test('works west of UTC', () {
      // 22:00 on 26 October at UTC-7.
      final now = DateTime.utc(2026, 10, 27, 5);
      expect(
        PackPeriod.current(daily, now, fixedZone(const Duration(hours: -7))),
        period(DateTime.utc(2026, 10, 26, 7), DateTime.utc(2026, 10, 27, 7)),
      );
    });

    test('local midnight belongs to the new day', () {
      final midnight = DateTime.utc(2026, 10, 27, 18, 30);
      final p = PackPeriod.current(daily, midnight, fixedZone(ist));
      expect(p.startUtc, midnight);
      expect(p.timeLeft(midnight), const Duration(days: 1));
    });

    test('follows the phone when it changes time zone', () {
      final now = DateTime.utc(2026, 10, 27, 20);
      final inIndia = PackPeriod.current(daily, now, fixedZone(ist));
      final inLondon = PackPeriod.current(daily, now, fixedZone(Duration.zero));
      expect(inIndia.startUtc, DateTime.utc(2026, 10, 27, 18, 30));
      expect(inLondon.startUtc, DateTime.utc(2026, 10, 27));
    });

    test('a day with a daylight-saving change is 23 or 25 hours', () {
      Duration berlin(DateTime utc) =>
          utc.isBefore(DateTime.utc(2026, 3, 29, 1))
          ? const Duration(hours: 1)
          : const Duration(hours: 2);
      final p = PackPeriod.current(
        daily,
        DateTime.utc(2026, 3, 29, 12),
        WallClock(berlin),
      );
      expect(p.startUtc, DateTime.utc(2026, 3, 28, 23));
      expect(p.endUtc.difference(p.startUtc), const Duration(hours: 23));
    });

    test('a missing midnight starts the day when clocks jump', () {
      // Clocks jump from 00:00 to 01:00 on 1 November (UTC-3 to UTC-2).
      Duration zone(DateTime utc) => utc.isBefore(DateTime.utc(2026, 11, 1, 3))
          ? const Duration(hours: -3)
          : const Duration(hours: -2);
      final p = PackPeriod.current(
        daily,
        DateTime.utc(2026, 11, 1, 15),
        WallClock(zone),
      );
      expect(p.startUtc, DateTime.utc(2026, 11, 1, 3));
      expect(p.endUtc, DateTime.utc(2026, 11, 2, 2));
    });
  });

  group('monthly pack', () {
    final utc = fixedZone(Duration.zero);
    MonthlyPack renewsOn(int day) => MonthlyPack(limitBytes: gb, resetDay: day);

    test('after the renewal day, runs to next month', () {
      expect(
        PackPeriod.current(renewsOn(15), DateTime.utc(2026, 10, 27), utc),
        period(DateTime.utc(2026, 10, 15), DateTime.utc(2026, 11, 15)),
      );
    });

    test('before the renewal day, started last month', () {
      expect(
        PackPeriod.current(renewsOn(15), DateTime.utc(2026, 10, 3), utc),
        period(DateTime.utc(2026, 9, 15), DateTime.utc(2026, 10, 15)),
      );
    });

    test('renews on the last day of shorter months', () {
      expect(
        PackPeriod.current(renewsOn(31), DateTime.utc(2026, 2, 27), utc),
        period(DateTime.utc(2026, 1, 31), DateTime.utc(2026, 2, 28)),
      );
      expect(
        PackPeriod.current(renewsOn(31), DateTime.utc(2026, 3, 10), utc),
        period(DateTime.utc(2026, 2, 28), DateTime.utc(2026, 3, 31)),
      );
    });

    test('knows leap years', () {
      expect(
        PackPeriod.current(renewsOn(30), DateTime.utc(2028, 3, 1), utc),
        period(DateTime.utc(2028, 2, 29), DateTime.utc(2028, 3, 30)),
      );
    });

    test('crosses the new year both ways', () {
      expect(
        PackPeriod.current(renewsOn(5), DateTime.utc(2027, 1, 2), utc),
        period(DateTime.utc(2026, 12, 5), DateTime.utc(2027, 1, 5)),
      );
      expect(
        PackPeriod.current(renewsOn(5), DateTime.utc(2026, 12, 20), utc),
        period(DateTime.utc(2026, 12, 5), DateTime.utc(2027, 1, 5)),
      );
    });

    test('renews at local midnight', () {
      // 00:10 on 15 October in India is still 14 October in UTC.
      final now = DateTime.utc(2026, 10, 14, 18, 40);
      expect(
        PackPeriod.current(renewsOn(15), now, fixedZone(ist)).startUtc,
        DateTime.utc(2026, 10, 14, 18, 30),
      );
    });
  });

  test('lastDays covers whole local days including today', () {
    final now = DateTime.utc(2026, 10, 27, 20); // 28 Oct, 01:30 IST
    expect(
      PackPeriod.lastDays(7, now, fixedZone(ist)),
      period(
        DateTime.utc(2026, 10, 21, 18, 30),
        DateTime.utc(2026, 10, 28, 18, 30),
      ),
    );
    expect(
      PackPeriod.lastDays(1, now, fixedZone(ist)),
      PackPeriod.today(now, fixedZone(ist)),
    );
  });

  test('time left never goes negative', () {
    final p = period(DateTime.utc(2026), DateTime.utc(2026, 1, 2));
    expect(p.timeLeft(DateTime.utc(2026, 1, 1, 18)), const Duration(hours: 6));
    expect(p.timeLeft(DateTime.utc(2026, 1, 3)), Duration.zero);
  });
}
