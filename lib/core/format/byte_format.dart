import 'package:intl/intl.dart';

/// One kilobyte, as carriers count it (1 GB = 1024 MB).
const int kKilobyte = 1024;
const int kMegabyte = kKilobyte * 1024;
const int kGigabyte = kMegabyte * 1024;

/// A byte count split into a number and a unit, ready to display.
final class ByteAmount {
  const ByteAmount(this.number, this.unit);

  final String number;
  final ByteUnit unit;

  @override
  bool operator ==(Object other) =>
      other is ByteAmount && other.number == number && other.unit == unit;

  @override
  int get hashCode => Object.hash(number, unit);

  @override
  String toString() => '$number ${unit.symbol}';
}

enum ByteUnit {
  b('B', 1),
  kb('KB', kKilobyte),
  mb('MB', kMegabyte),
  gb('GB', kGigabyte);

  const ByteUnit(this.symbol, this.bytes);

  final String symbol;
  final int bytes;
}

/// Formats byte counts and speeds with 1024-based units.
///
/// Values below 10 get up to two decimals, below 100 one decimal, larger ones
/// none, and trailing zeros are dropped: `1.5 GB`, `12.3 MB`, `512 KB`.
/// Units switch at 1000 so a number never has four digits.
final class ByteFormatter {
  ByteFormatter([String? locale]) : _locale = locale;

  final String? _locale;

  ByteAmount amount(int bytes) {
    final value = bytes < 0 ? 0 : bytes;
    final unit = _unitFor(value);
    if (unit == ByteUnit.b) {
      return ByteAmount(
        NumberFormat.decimalPattern(_locale).format(value),
        unit,
      );
    }
    return ByteAmount(_number(value / unit.bytes), unit);
  }

  /// `1.5 GB`
  String bytes(int bytes) => amount(bytes).toString();

  /// `1.2 MB/s`
  String speed(int bytesPerSecond) => '${amount(bytesPerSecond)}/s';

  String _number(double value) {
    // Round first, so 9.996 MB becomes "10 MB" rather than "10.00".
    final decimals = value < 10 ? 2 : (value < 100 ? 1 : 0);
    final format = NumberFormat.decimalPattern(_locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimals;
    return format.format(value);
  }

  static ByteUnit _unitFor(int bytes) {
    // Switch units at 1000 so numbers never take four digits ("0.98 GB").
    if (bytes >= 1000 * kMegabyte) return ByteUnit.gb;
    if (bytes >= 1000 * kKilobyte) return ByteUnit.mb;
    if (bytes >= 1000) return ByteUnit.kb;
    return ByteUnit.b;
  }
}

/// Splits a pack size into the number and unit to prefill the pack form:
/// GB from 1 GB up, MB below. Uses up to two decimals, `.` as separator.
(String, ByteUnit) editableAmount(int bytes) {
  final unit = bytes >= kGigabyte ? ByteUnit.gb : ByteUnit.mb;
  final text = (bytes / unit.bytes)
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  return (text, unit);
}
