import 'package:data_pack_meter/core/platform/native_channel.dart';
import 'package:data_pack_meter/features/pack/data/channel_pack_repository.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(nativeChannel, null));

  test('reads nothing as no pack with alerts on', () {
    expect(packSettingsFromMap(const {}), const PackSettings());
  });

  test('round-trips daily and monthly packs', () {
    const settings = [
      PackSettings(plan: DailyPack(limitBytes: 2 * gb)),
      PackSettings(
        plan: MonthlyPack(limitBytes: 50 * gb, resetDay: 31),
        alertsEnabled: false,
      ),
    ];
    for (final s in settings) {
      expect(packSettingsFromMap(packSettingsToMap(s)), s);
    }
  });

  test('ignores a pack with no size and clamps the reset day', () {
    expect(
      packSettingsFromMap(const {'type': 'daily', 'limitBytes': 0}).plan,
      isNull,
    );
    expect(
      packSettingsFromMap(const {
        'type': 'monthly',
        'limitBytes': 10,
        'resetDay': 40,
      }).plan,
      const MonthlyPack(limitBytes: 10, resetDay: 31),
    );
  });

  test('saves and loads through the channel', () async {
    Map<Object?, Object?> stored = const {};
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      switch (call.method) {
        case 'savePack':
          stored = call.arguments as Map<Object?, Object?>;
          return null;
        case 'getPack':
          return stored;
      }
      return null;
    });
    const repo = ChannelPackRepository();
    const settings = PackSettings(
      plan: MonthlyPack(limitBytes: 30 * gb, resetDay: 12),
    );
    await repo.save(settings);
    expect(stored['type'], 'monthly');
    expect(await repo.load(), settings);
  });
}
