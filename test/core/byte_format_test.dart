import 'package:data_pack_meter/core/format/byte_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final format = ByteFormatter('en');

  group('ByteFormatter.bytes', () {
    test('shows small counts in bytes', () {
      expect(format.bytes(0), '0 B');
      expect(format.bytes(999), '999 B');
    });

    test('negative counts read as zero', () {
      expect(format.bytes(-5), '0 B');
    });

    test('uses 1024-based units', () {
      expect(format.bytes(1024), '1 KB');
      expect(format.bytes(1536), '1.5 KB');
      expect(format.bytes(1024 * 1024), '1 MB');
      expect(format.bytes(3 * 1024 * 1024 * 1024 ~/ 2), '1.5 GB');
    });

    test('decimals shrink as numbers grow', () {
      expect(format.bytes((1.234 * kMegabyte).round()), '1.23 MB');
      expect(format.bytes((12.34 * kMegabyte).round()), '12.3 MB');
      expect(format.bytes((123.4 * kMegabyte).round()), '123 MB');
    });

    test('switches unit before showing four digits', () {
      expect(format.bytes(1000), '0.98 KB');
      expect(format.bytes(1023), '1 KB');
      expect(format.bytes(999 * kMegabyte), '999 MB');
      expect(format.bytes(1000 * kMegabyte), '0.98 GB');
    });

    test('follows the locale decimal separator', () {
      expect(ByteFormatter('de').bytes(3 * kGigabyte ~/ 2), '1,5 GB');
    });
  });

  test('speed adds per second', () {
    expect(format.speed(0), '0 B/s');
    expect(format.speed(250 * kKilobyte), '250 KB/s');
    expect(format.speed((1.2 * kMegabyte).round()), '1.2 MB/s');
  });

  group('editableAmount', () {
    test('uses GB from one gigabyte', () {
      expect(editableAmount(3 * kGigabyte ~/ 2), ('1.5', ByteUnit.gb));
      expect(editableAmount(2 * kGigabyte), ('2', ByteUnit.gb));
      expect(editableAmount(100 * kGigabyte), ('100', ByteUnit.gb));
    });

    test('uses MB below one gigabyte', () {
      expect(editableAmount(500 * kMegabyte), ('500', ByteUnit.mb));
      expect(editableAmount(kMegabyte ~/ 2), ('0.5', ByteUnit.mb));
    });
  });
}
