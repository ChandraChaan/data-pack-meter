import 'dart:async';

import 'package:data_pack_meter/core/errors.dart';
import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/core/time/clock.dart';
import 'package:data_pack_meter/features/meter/data/channel_meter_repository.dart';
import 'package:data_pack_meter/features/meter/domain/meter_models.dart';
import 'package:data_pack_meter/features/meter/domain/meter_repository.dart';
import 'package:data_pack_meter/features/pack/data/channel_pack_repository.dart';
import 'package:data_pack_meter/features/pack/domain/pack_period.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/pack/domain/pack_repository.dart';
import 'package:data_pack_meter/features/usage/data/channel_usage_repository.dart';
import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:data_pack_meter/features/usage/domain/usage_repository.dart';
import 'package:flutter_riverpod/misc.dart';

/// India Standard Time, which has no daylight saving.
const ist = Duration(hours: 5, minutes: 30);

final class FixedClock implements Clock {
  FixedClock(this.now, {this.offset = ist});

  DateTime now;
  Duration offset;

  @override
  DateTime nowUtc() => now;

  @override
  Duration offsetAt(DateTime utc) => offset;
}

final class FakePackRepository implements PackRepository {
  FakePackRepository([this.settings = const PackSettings()]);

  PackSettings settings;
  int saves = 0;

  @override
  Future<PackSettings> load() async => settings;

  @override
  Future<void> save(PackSettings settings) async {
    saves++;
    this.settings = settings;
  }
}

class FakeUsageRepository implements UsageRepository {
  FakeUsageRepository({
    this.access = true,
    this.usage = const {},
    this.apps = const {},
    this.fail = false,
    this.gate,
  });

  /// When set, every call waits for it, to test loading states.
  Completer<void>? gate;
  bool access;
  bool fail;

  /// Device usage per window start; windows not listed report zero.
  Map<DateTime, DeviceUsage> usage;
  Map<NetworkKind, List<AppUsage>> apps;
  final List<PackPeriod> queried = [];
  int settingsOpened = 0;

  @override
  Future<bool> hasUsageAccess() async {
    await gate?.future;
    if (fail) throw const NativeCallException('boom');
    return access;
  }

  @override
  Future<void> openUsageAccessSettings() async => settingsOpened++;

  @override
  Future<DeviceUsage> deviceUsage(PackPeriod window) async {
    _check();
    queried.add(window);
    return usage[window.startUtc] ?? DeviceUsage.zero;
  }

  @override
  Future<List<AppUsage>> appUsage(
    NetworkKind network,
    PackPeriod window,
  ) async {
    _check();
    queried.add(window);
    return rankByTraffic(apps[network] ?? const []);
  }

  void _check() {
    if (fail) throw const NativeCallException('boom');
    if (!access) throw const UsageAccessDeniedException();
  }
}

final class FakeMeterRepository implements MeterRepository {
  FakeMeterRepository({
    this.state = const MeterState(
      running: false,
      startOnBoot: false,
      notificationsAllowed: true,
    ),
    this.grantOnRequest = true,
  });

  MeterState state;
  bool grantOnRequest;
  int permissionRequests = 0;
  final speeds = StreamController<LiveSpeed>.broadcast();

  @override
  Future<MeterState> load() async => state;

  @override
  Future<void> start() async => state = state.copyWith(running: true);

  @override
  Future<void> stop() async => state = state.copyWith(running: false);

  @override
  Future<void> setStartOnBoot({required bool enabled}) async =>
      state = state.copyWith(startOnBoot: enabled);

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    state = state.copyWith(notificationsAllowed: grantOnRequest);
    return grantOnRequest;
  }

  @override
  Stream<LiveSpeed> liveSpeed() => speeds.stream;

  Future<void> close() => speeds.close();
}

/// Overrides every repository and the clock with fakes.
List<Override> fakeOverrides({
  required Clock clock,
  FakePackRepository? pack,
  FakeUsageRepository? usage,
  FakeMeterRepository? meter,
}) => [
  clockProvider.overrideWithValue(clock),
  packRepositoryProvider.overrideWithValue(pack ?? FakePackRepository()),
  usageRepositoryProvider.overrideWithValue(usage ?? FakeUsageRepository()),
  meterRepositoryProvider.overrideWithValue(meter ?? FakeMeterRepository()),
];

const int mb = 1024 * 1024;
const int gb = 1024 * mb;
