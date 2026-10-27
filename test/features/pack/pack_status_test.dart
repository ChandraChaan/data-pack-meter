import 'package:data_pack_meter/features/pack/domain/pack_period.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/pack/domain/pack_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

PackStatus statusWith(int used, {int limit = 1000}) => PackStatus(
  plan: DailyPack(limitBytes: limit),
  period: PackPeriod(
    startUtc: DateTime.utc(2026, 10, 27),
    endUtc: DateTime.utc(2026, 10, 28),
  ),
  usedBytes: used,
  nowUtc: DateTime.utc(2026, 10, 27, 19, 30),
);

void main() {
  group('alert levels', () {
    test('ok below 80%', () {
      expect(statusWith(0).level, PackLevel.ok);
      expect(statusWith(799).level, PackLevel.ok);
    });

    test('near the limit from 80%', () {
      expect(statusWith(800).level, PackLevel.nearLimit);
      expect(statusWith(999).level, PackLevel.nearLimit);
    });

    test('exceeded from 100%', () {
      expect(statusWith(1000).level, PackLevel.exceeded);
      expect(statusWith(5000).level, PackLevel.exceeded);
    });

    test('thresholds are 80% and 100%', () {
      expect(kAlertThresholds, [0.8, 1.0]);
    });
  });

  test('remaining and over', () {
    expect(statusWith(300).remainingBytes, 700);
    expect(statusWith(300).overBytes, 0);
    expect(statusWith(1200).remainingBytes, 0);
    expect(statusWith(1200).overBytes, 200);
  });

  test('percent rounds down so 99.9% is not shown as full', () {
    expect(statusWith(999).percentUsed, 99);
    expect(statusWith(1000).percentUsed, 100);
    expect(statusWith(2500).percentUsed, 250);
  });

  test('a 1.5 GB pack with 1.2 GB used is 80%', () {
    final status = statusWith((1.2 * gb).round(), limit: (1.5 * gb).round());
    expect(status.percentUsed, 80);
    expect(status.level, PackLevel.nearLimit);
  });

  test('time left counts to the end of the period', () {
    expect(statusWith(0).timeLeft, const Duration(hours: 4, minutes: 30));
  });
}
