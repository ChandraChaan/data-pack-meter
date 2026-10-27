import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../../core/time/clock.dart';
import '../../pack/data/channel_pack_repository.dart';
import '../../pack/domain/pack_period.dart';
import '../../pack/domain/pack_plan.dart';
import '../../pack/domain/pack_status.dart';
import '../data/channel_usage_repository.dart';
import '../domain/usage_models.dart';

/// What the Today screen shows.
sealed class TodayState {
  const TodayState(this.settings);

  final PackSettings settings;
}

/// Usage Access is off, so there is nothing to count yet.
final class TodayNeedsAccess extends TodayState {
  const TodayNeedsAccess(super.settings);
}

final class TodayReady extends TodayState {
  const TodayReady({
    required PackSettings settings,
    required this.today,
    this.status,
  }) : super(settings);

  /// Mobile and Wi-Fi traffic since local midnight.
  final DeviceUsage today;

  /// `null` until the user sets up a pack.
  final PackStatus? status;
}

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayState>(TodayController.new);

class TodayController extends AsyncNotifier<TodayState> {
  @override
  Future<TodayState> build() => _load();

  /// Reloads, keeping the current numbers on screen while it does.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    if (!ref.mounted) return;
    state = next;
  }

  Future<TodayState> _load() async {
    final usage = ref.read(usageRepositoryProvider);
    final settings = await ref.read(packRepositoryProvider).load();
    if (!await usage.hasUsageAccess()) return TodayNeedsAccess(settings);

    final clock = ref.read(clockProvider);
    final now = clock.nowUtc();
    final wall = WallClock.of(clock);
    final todayWindow = PackPeriod.today(now, wall);
    try {
      final today = await usage.deviceUsage(todayWindow);
      final plan = settings.plan;
      if (plan == null) return TodayReady(settings: settings, today: today);

      final period = PackPeriod.current(plan, now, wall);
      final periodUsage = period == todayWindow
          ? today
          : await usage.deviceUsage(period);
      return TodayReady(
        settings: settings,
        today: today,
        status: PackStatus(
          plan: plan,
          period: period,
          usedBytes: periodUsage.mobile.totalBytes,
          nowUtc: now,
        ),
      );
    } on UsageAccessDeniedException {
      // Turned off between the check and the query.
      return TodayNeedsAccess(settings);
    }
  }
}
