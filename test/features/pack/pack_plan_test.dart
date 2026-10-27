import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('parsePackAmount', () {
    test('reads decimals with a dot or a comma', () {
      expect(parsePackAmount('1.5', gb), (1.5 * gb).round());
      expect(parsePackAmount('1,5', gb), (1.5 * gb).round());
      expect(parsePackAmount(' 2 ', gb), 2 * gb);
      expect(parsePackAmount('500', mb), 500 * mb);
    });

    test('rejects anything that is not a plain number', () {
      for (final text in ['', 'abc', '1.2.3', '-1', '1e3', '.5']) {
        expect(parsePackAmount(text, gb), isNull, reason: text);
      }
    });

    test('clamps absurd input instead of overflowing', () {
      final bytes = parsePackAmount('99999999999999999999', gb);
      expect(validatePackLimit(bytes), PackLimitError.tooLarge);
    });
  });

  test('validatePackLimit', () {
    expect(validatePackLimit(null), PackLimitError.notANumber);
    expect(validatePackLimit(0), PackLimitError.tooSmall);
    expect(validatePackLimit(1), isNull);
    expect(validatePackLimit(1024 * gb), isNull);
    expect(validatePackLimit(200 * 1024 * gb), PackLimitError.tooLarge);
  });

  test('plans compare by value', () {
    expect(const DailyPack(limitBytes: gb), const DailyPack(limitBytes: gb));
    expect(
      const MonthlyPack(limitBytes: gb, resetDay: 3),
      isNot(const MonthlyPack(limitBytes: gb, resetDay: 4)),
    );
    expect(
      const DailyPack(limitBytes: gb),
      isNot(const MonthlyPack(limitBytes: gb, resetDay: 1)),
    );
  });
}
