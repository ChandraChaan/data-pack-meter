import 'package:data_pack_meter/features/meter/domain/meter_models.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 13, 30));

  testWidgets('saves a daily pack in GB', (tester) async {
    final pack = FakePackRepository();
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(clock: clock, pack: pack),
    );
    await tester.enterText(find.byKey(const Key('pack-amount')), '1.5');
    await tester.tap(find.byKey(const Key('save-pack')));
    await tester.pump();
    expect(pack.settings.plan, DailyPack(limitBytes: (1.5 * gb).round()));
    expect(find.text('Pack saved'), findsOneWidget);
  });

  testWidgets('saves a monthly pack in MB with its renewal day', (
    tester,
  ) async {
    final pack = FakePackRepository();
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(clock: clock, pack: pack),
    );
    await tester.tap(find.text('Per month'));
    await tester.pump();
    await tester.tap(find.text('MB'));
    await tester.enterText(find.byKey(const Key('pack-amount')), '750');
    final resetDay = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(resetDay);
    await tester.tap(resetDay);
    await tester.pumpAndSettle();
    await tester.tap(find.text('3').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-pack')));
    await tester.tap(find.byKey(const Key('save-pack')));
    await tester.pump();
    expect(
      pack.settings.plan,
      const MonthlyPack(limitBytes: 750 * mb, resetDay: 3),
    );
  });

  testWidgets('prefills the saved pack', (tester) async {
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(
        clock: clock,
        pack: FakePackRepository(
          const PackSettings(plan: DailyPack(limitBytes: 2 * gb)),
        ),
      ),
    );
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
  });

  testWidgets('rejects an empty or zero pack', (tester) async {
    final pack = FakePackRepository();
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(clock: clock, pack: pack),
    );
    await tester.tap(find.byKey(const Key('save-pack')));
    await tester.pump();
    expect(find.text('Enter a number, like 1.5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pack-amount')), '0');
    await tester.tap(find.byKey(const Key('save-pack')));
    await tester.pump();
    expect(find.text('Enter an amount above zero'), findsOneWidget);
    expect(pack.saves, 0);
  });

  testWidgets('turns the status bar meter on', (tester) async {
    final meter = FakeMeterRepository();
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(clock: clock, meter: meter),
    );
    await tester.tap(find.byKey(const Key('meter-switch')));
    await tester.pump();
    await tester.pump();
    expect(meter.state.running, isTrue);
  });

  testWidgets('explains notifications only after a refusal', (tester) async {
    await tester.pumpScreen(
      const SettingsScreen(),
      overrides: fakeOverrides(
        clock: clock,
        meter: FakeMeterRepository(
          state: const MeterState(
            running: false,
            startOnBoot: false,
            notificationsAllowed: false,
          ),
          grantOnRequest: false,
        ),
      ),
    );
    expect(find.textContaining('Allow notifications'), findsNothing);
    await tester.tap(find.byKey(const Key('meter-switch')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Allow notifications'), findsOneWidget);
  });
}
