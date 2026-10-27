import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_channel.dart';
import '../domain/meter_models.dart';
import '../domain/meter_repository.dart';

final meterRepositoryProvider = Provider<MeterRepository>(
  (ref) => const ChannelMeterRepository(),
);

final class ChannelMeterRepository implements MeterRepository {
  const ChannelMeterRepository([
    this._channel = nativeChannel,
    this._speed = speedChannel,
  ]);

  final MethodChannel _channel;
  final EventChannel _speed;

  @override
  Future<MeterState> load() async {
    final map =
        await invokeNative<Map<Object?, Object?>>(
          'meterState',
          null,
          _channel,
        ) ??
        const {};
    return MeterState(
      running: readBool(map, 'running'),
      startOnBoot: readBool(map, 'startOnBoot'),
      notificationsAllowed: readBool(map, 'notificationsAllowed', true),
    );
  }

  @override
  Future<void> start() => invokeNative<void>('startMeter', null, _channel);

  @override
  Future<void> stop() => invokeNative<void>('stopMeter', null, _channel);

  @override
  Future<void> setStartOnBoot({required bool enabled}) =>
      invokeNative<void>('setStartOnBoot', {'enabled': enabled}, _channel);

  @override
  Future<bool> requestNotificationPermission() async =>
      await invokeNative<bool>(
        'requestNotificationPermission',
        null,
        _channel,
      ) ??
      false;

  @override
  Stream<LiveSpeed> liveSpeed() => _speed
      .receiveBroadcastStream()
      .map(
        (event) =>
            event is Map<Object?, Object?> ? event : const <Object?, Object?>{},
      )
      .map(
        (map) => LiveSpeed(
          rxPerSecond: readInt(map, 'rx'),
          txPerSecond: readInt(map, 'tx'),
        ),
      );
}
