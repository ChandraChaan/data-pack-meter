import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/pack/domain/pack_status.dart';
import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:data_pack_meter/features/usage/presentation/today_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  // 19:00 on 27 October in India.
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 13, 30));
  final todayStart = DateTime.utc(2026, 10, 26, 18, 30);

  ProviderContainer containerWith({
    FakeUsageRepository? usage,
    FakePackRepository? pack,
  }) => ProviderContainer.test(
    retry: noRetry,
    overrides: fakeOverrides(clock: clock, usage: usage, pack: pack),
  );

  test('asks for access when Usage Access is off', () async {
    final container = containerWith(usage: FakeUsageRepository(access: false));
    expect(
      await container.read(todayControllerProvider.future),
      isA<TodayNeedsAccess>(),
    );
  });

  test('shows today without a status until a pack is set', () async {
    const today = DeviceUsage(
      mobile: Traffic(rxBytes: 100, txBytes: 10),
      wifi: Traffic(rxBytes: 900, txBytes: 90),
    );
    final container = containerWith(
      usage: FakeUsageRepository(usage: {todayStart: today}),
    );
    final state = await container.read(todayControllerProvider.future);
    expect(state, isA<TodayReady>());
    state as TodayReady;
    expect(state.today, today);
    expect(state.status, isNull);
  });

  test('a daily pack counts mobile data since local midnight', () async {
    final usage = FakeUsageRepository(
      usage: {
        todayStart: DeviceUsage(
          mobile: Traffic(rxBytes: (1.15 * gb).round(), txBytes: 100 * mb),
          wifi: const Traffic(rxBytes: 5 * gb, txBytes: 0),
        ),
      },
    );
    final container = containerWith(
      usage: usage,
      pack: FakePackRepository(
        PackSettings(plan: DailyPack(limitBytes: (1.5 * gb).round())),
      ),
    );
    final state =
        await container.read(todayControllerProvider.future) as TodayReady;
    final status = state.status!;
    expect(status.period.startUtc, todayStart);
    expect(status.usedBytes, (1.15 * gb).round() + 100 * mb);
    expect(status.level, PackLevel.nearLimit);
    expect(status.timeLeft, const Duration(hours: 5));
    expect(usage.queried, hasLength(1), reason: 'today is the pack period');
  });

  test('a monthly pack queries the whole period', () async {
    final periodStart = DateTime.utc(2026, 10, 9, 18, 30); // 10 Oct, IST
    final usage = FakeUsageRepository(
      usage: {
        periodStart: const DeviceUsage(
          mobile: Traffic(rxBytes: 31 * gb, txBytes: gb),
          wifi: Traffic.zero,
        ),
      },
    );
    final container = containerWith(
      usage: usage,
      pack: FakePackRepository(
        const PackSettings(
          plan: MonthlyPack(limitBytes: 30 * gb, resetDay: 10),
        ),
      ),
    );
    final state =
        await container.read(todayControllerProvider.future) as TodayReady;
    expect(state.status!.period.startUtc, periodStart);
    expect(state.status!.level, PackLevel.exceeded);
    expect(state.status!.overBytes, 2 * gb);
    expect(usage.queried, hasLength(2));
  });

  test('access revoked mid-load falls back to the access card', () async {
    final usage = _RevokingUsageRepository();
    final container = containerWith(usage: usage);
    expect(
      await container.read(todayControllerProvider.future),
      isA<TodayNeedsAccess>(),
    );
  });

  test('a native failure surfaces as an error', () async {
    final container = containerWith(usage: FakeUsageRepository(fail: true));
    await expectLater(
      container.read(todayControllerProvider.future),
      throwsA(anything),
    );
    expect(container.read(todayControllerProvider).hasError, isTrue);
  });
}

/// Says access is on, then fails the query as if it was just turned off.
final class _RevokingUsageRepository extends FakeUsageRepository {
  @override
  Future<bool> hasUsageAccess() async {
    access = false;
    return true;
  }
}
