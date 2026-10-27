import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_channel.dart';
import '../domain/pack_plan.dart';
import '../domain/pack_repository.dart';

final packRepositoryProvider = Provider<PackRepository>(
  (ref) => const ChannelPackRepository(),
);

/// Keeps the pack in Android SharedPreferences, so background alerts and the
/// widget see the same settings as the app.
final class ChannelPackRepository implements PackRepository {
  const ChannelPackRepository([this._channel = nativeChannel]);

  final MethodChannel _channel;

  @override
  Future<PackSettings> load() async {
    final map = await invokeNative<Map<Object?, Object?>>(
      'getPack',
      null,
      _channel,
    );
    return packSettingsFromMap(map ?? const {});
  }

  @override
  Future<void> save(PackSettings settings) =>
      invokeNative<void>('savePack', packSettingsToMap(settings), _channel);
}

PackSettings packSettingsFromMap(Map<Object?, Object?> map) {
  final limit = readInt(map, 'limitBytes');
  final plan = switch (readString(map, 'type')) {
    'daily' when limit > 0 => DailyPack(limitBytes: limit),
    'monthly' when limit > 0 => MonthlyPack(
      limitBytes: limit,
      resetDay: readInt(map, 'resetDay', 1).clamp(1, 31),
    ),
    _ => null,
  };
  return PackSettings(
    plan: plan,
    alertsEnabled: readBool(map, 'alertsEnabled', true),
  );
}

Map<String, Object?> packSettingsToMap(PackSettings settings) => {
  'type': switch (settings.plan) {
    DailyPack() => 'daily',
    MonthlyPack() => 'monthly',
    null => null,
  },
  'limitBytes': settings.plan?.limitBytes ?? 0,
  'resetDay': switch (settings.plan) {
    MonthlyPack(:final resetDay) => resetDay,
    _ => 1,
  },
  'alertsEnabled': settings.alertsEnabled,
};
