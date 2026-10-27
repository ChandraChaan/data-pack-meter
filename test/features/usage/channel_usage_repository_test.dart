import 'package:data_pack_meter/core/errors.dart';
import 'package:data_pack_meter/core/platform/native_channel.dart';
import 'package:data_pack_meter/features/pack/domain/pack_period.dart';
import 'package:data_pack_meter/features/usage/data/channel_usage_repository.dart';
import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null));

  final window = PackPeriod(
    startUtc: DateTime.utc(2026, 10, 27),
    endUtc: DateTime.utc(2026, 10, 28),
  );
  const repo = ChannelUsageRepository();

  test('sends the window in epoch milliseconds and reads totals', () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      sent = call;
      return {'mobileRx': 300, 'mobileTx': 20, 'wifiRx': 5000, 'wifiTx': 1.0};
    });
    final usage = await repo.deviceUsage(window);
    expect(sent?.method, 'deviceUsage');
    expect(sent?.arguments, {
      'startMs': window.startUtc.millisecondsSinceEpoch,
      'endMs': window.endUtc.millisecondsSinceEpoch,
    });
    expect(usage.mobile, const Traffic(rxBytes: 300, txBytes: 20));
    expect(usage.wifi.totalBytes, 5001);
  });

  test('reads app rows, ranks them and drops empty ones', () async {
    MethodCall? sent;
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      sent = call;
      return [
        {'uid': 10100, 'kind': 'app', 'label': 'Maps', 'rx': 10, 'tx': 1},
        {
          'uid': 10200,
          'kind': 'app',
          'label': 'Video',
          'packageName': 'com.example.video',
          'rx': 900,
          'tx': 10,
          'icon': Uint8List.fromList([1, 2, 3]),
        },
        {'uid': 1000, 'kind': 'system', 'rx': 50, 'tx': 50},
        {'uid': -5, 'kind': 'tethering', 'rx': 0, 'tx': 0},
        {'uid': 10300, 'kind': 'mystery', 'rx': 1, 'tx': 0},
      ];
    });
    final apps = await repo.appUsage(NetworkKind.wifi, window);
    expect((sent?.arguments as Map<Object?, Object?>)['network'], 'wifi');
    expect(apps.map((a) => a.uid), [10200, 1000, 10100, 10300]);
    expect(apps.first.icon, [1, 2, 3]);
    expect(apps.first.packageName, 'com.example.video');
    expect(apps[1].kind, AppKind.system);
    expect(apps.last.kind, AppKind.app, reason: 'unknown kinds fall back');
  });

  test('maps the no-access error to a typed exception', () {
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      throw PlatformException(code: kNoUsageAccessCode);
    });
    expect(
      repo.deviceUsage(window),
      throwsA(isA<UsageAccessDeniedException>()),
    );
  });

  test('maps other platform errors to NativeCallException', () {
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      throw PlatformException(code: 'ERROR', message: 'stats service died');
    });
    expect(repo.hasUsageAccess(), throwsA(isA<NativeCallException>()));
  });

  test('a missing native side is a NativeCallException', () {
    expect(repo.hasUsageAccess(), throwsA(isA<NativeCallException>()));
  });

  test('rankByTraffic breaks ties by uid', () {
    const t = Traffic(rxBytes: 5, txBytes: 5);
    final ranked = rankByTraffic(const [
      AppUsage(uid: 3, kind: AppKind.app, label: '', traffic: t),
      AppUsage(uid: 1, kind: AppKind.app, label: '', traffic: t),
    ]);
    expect(ranked.map((a) => a.uid), [1, 3]);
  });
}
