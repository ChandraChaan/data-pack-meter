import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/native_channel.dart';
import '../../pack/domain/pack_period.dart';
import '../domain/usage_models.dart';
import '../domain/usage_repository.dart';

final usageRepositoryProvider = Provider<UsageRepository>(
  (ref) => const ChannelUsageRepository(),
);

/// Reads `NetworkStatsManager` through the platform channel.
final class ChannelUsageRepository implements UsageRepository {
  const ChannelUsageRepository([this._channel = nativeChannel]);

  final MethodChannel _channel;

  @override
  Future<bool> hasUsageAccess() async =>
      await invokeNative<bool>('hasUsageAccess', null, _channel) ?? false;

  @override
  Future<void> openUsageAccessSettings() =>
      invokeNative<void>('openUsageAccessSettings', null, _channel);

  @override
  Future<DeviceUsage> deviceUsage(PackPeriod window) async {
    final map = await invokeNative<Map<Object?, Object?>>(
      'deviceUsage',
      _window(window),
      _channel,
    );
    return deviceUsageFromMap(map ?? const {});
  }

  @override
  Future<List<AppUsage>> appUsage(
    NetworkKind network,
    PackPeriod window,
  ) async {
    final list = await invokeNative<List<Object?>>('appUsage', {
      ..._window(window),
      'network': network.name,
    }, _channel);
    return rankByTraffic(
      (list ?? const []).whereType<Map<Object?, Object?>>().map(
        appUsageFromMap,
      ),
    );
  }

  static Map<String, Object?> _window(PackPeriod window) => {
    'startMs': window.startUtc.millisecondsSinceEpoch,
    'endMs': window.endUtc.millisecondsSinceEpoch,
  };
}

DeviceUsage deviceUsageFromMap(Map<Object?, Object?> map) => DeviceUsage(
  mobile: Traffic(
    rxBytes: readInt(map, 'mobileRx'),
    txBytes: readInt(map, 'mobileTx'),
  ),
  wifi: Traffic(
    rxBytes: readInt(map, 'wifiRx'),
    txBytes: readInt(map, 'wifiTx'),
  ),
);

AppUsage appUsageFromMap(Map<Object?, Object?> map) {
  final icon = map['icon'];
  return AppUsage(
    uid: readInt(map, 'uid'),
    kind: AppKind.values.asNameMap()[readString(map, 'kind')] ?? AppKind.app,
    label: readString(map, 'label') ?? '',
    packageName: readString(map, 'packageName'),
    traffic: Traffic(rxBytes: readInt(map, 'rx'), txBytes: readInt(map, 'tx')),
    icon: icon is Uint8List && icon.isNotEmpty ? icon : null,
  );
}
