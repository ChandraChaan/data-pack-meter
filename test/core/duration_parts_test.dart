import 'package:data_pack_meter/core/format/duration_parts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('days and hours from one day', () {
    expect(
      DurationParts.of(const Duration(days: 2, hours: 4, minutes: 30)),
      const DaysHours(2, 4),
    );
  });

  test('hours and minutes under a day', () {
    expect(
      DurationParts.of(const Duration(hours: 5, minutes: 12)),
      const HoursMinutes(5, 12),
    );
  });

  test('rounds seconds up so time left never shows as zero', () {
    expect(DurationParts.of(const Duration(seconds: 1)), const Minutes(1));
    expect(
      DurationParts.of(const Duration(minutes: 59, seconds: 30)),
      const HoursMinutes(1, 0),
    );
  });

  test('zero and negative durations are zero minutes', () {
    expect(DurationParts.of(Duration.zero), const Minutes(0));
    expect(DurationParts.of(const Duration(minutes: -3)), const Minutes(0));
  });
}
