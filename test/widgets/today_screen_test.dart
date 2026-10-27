import 'dart:async';

import 'package:data_pack_meter/core/ui/pack_ring.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:data_pack_meter/features/usage/presentation/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 13, 30)); // 19:00 IST
  final todayStart = DateTime.utc(2026, 10, 26, 18, 30);
  var setUpTapped = 0;
  final screen = TodayScreen(onSetUpPack: () => setUpTapped++);

  testWidgets('shows the pack ring, usage and time to reset', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpScreen(
      screen,
      overrides: fakeOverrides(
        clock: clock,
        pack: FakePackRepository(
          PackSettings(plan: DailyPack(limitBytes: (1.5 * gb).round())),
        ),
        usage: FakeUsageRepository(
          usage: {
            todayStart: DeviceUsage(
              mobile: Traffic(rxBytes: (1.1 * gb).round(), txBytes: 50 * mb),
              wifi: const Traffic(rxBytes: 3 * gb, txBytes: 200 * mb),
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daily pack'), findsOneWidget);
    expect(find.text('1.15 GB of 1.5 GB'), findsOneWidget);
    expect(find.text('360 MB left'), findsOneWidget);
    expect(find.text('76%'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Resets in 5 h 0 min'), findsOneWidget);
    expect(find.text('Mobile today'), findsOneWidget);
    expect(find.text('3.2 GB'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PackRing)).getSemanticsData().label,
      contains('76 percent of your pack used'),
    );
    semantics.dispose();
  });

  testWidgets('says when the pack is used up, not by colour alone', (
    tester,
  ) async {
    await tester.pumpScreen(
      screen,
      overrides: fakeOverrides(
        clock: clock,
        pack: FakePackRepository(
          const PackSettings(plan: DailyPack(limitBytes: gb)),
        ),
        usage: FakeUsageRepository(
          usage: {
            todayStart: const DeviceUsage(
              mobile: Traffic(rxBytes: gb, txBytes: 100 * mb),
              wifi: Traffic.zero,
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pack used up'), findsOneWidget);
    expect(find.text('100 MB over your pack'), findsOneWidget);
  });

  testWidgets('offers pack setup when no pack is set', (tester) async {
    await tester.pumpScreen(screen, overrides: fakeOverrides(clock: clock));
    expect(find.text('Set up your data pack'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set-up-pack')));
    expect(setUpTapped, 1);
  });

  testWidgets('explains Usage Access before opening settings', (tester) async {
    final usage = FakeUsageRepository(access: false);
    await tester.pumpScreen(
      screen,
      overrides: fakeOverrides(clock: clock, usage: usage),
    );
    expect(find.text('Allow usage access to count your data'), findsOneWidget);

    await tester.tap(find.byKey(const Key('allow-usage-access')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The counts stay on your phone'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(usage.settingsOpened, 0);

    await tester.tap(find.byKey(const Key('allow-usage-access')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-usage-settings')));
    await tester.pumpAndSettle();
    expect(usage.settingsOpened, 1);
  });

  testWidgets('shows a retry when Android fails', (tester) async {
    final usage = FakeUsageRepository(fail: true);
    await tester.pumpScreen(
      screen,
      overrides: fakeOverrides(clock: clock, usage: usage),
    );
    expect(find.text("Couldn't read data use from Android."), findsOneWidget);

    usage.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Set up your data pack'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final gate = Completer<void>();
    await tester.pumpScreen(
      screen,
      overrides: fakeOverrides(
        clock: clock,
        usage: FakeUsageRepository(gate: gate),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Set up your data pack'), findsOneWidget);
  });
}
