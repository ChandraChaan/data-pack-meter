import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:data_pack_meter/features/usage/presentation/apps_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 13, 30));

  final mobileApps = [
    const AppUsage(
      uid: 10101,
      kind: AppKind.app,
      label: 'Maps',
      traffic: Traffic(rxBytes: 40 * mb, txBytes: 2 * mb),
    ),
    const AppUsage(
      uid: 10102,
      kind: AppKind.app,
      label: 'Video Player',
      traffic: Traffic(rxBytes: 600 * mb, txBytes: 12 * mb),
    ),
    const AppUsage(
      uid: 1000,
      kind: AppKind.system,
      label: '',
      traffic: Traffic(rxBytes: 5 * mb, txBytes: mb),
    ),
  ];

  testWidgets('lists apps by data used, biggest first', (tester) async {
    await tester.pumpScreen(
      const AppsScreen(),
      overrides: fakeOverrides(
        clock: clock,
        usage: FakeUsageRepository(apps: {NetworkKind.mobile: mobileApps}),
      ),
    );
    final names = tester
        .widgetList<AppUsageTile>(find.byType(AppUsageTile))
        .map((t) => t.app.uid);
    expect(names, [10102, 10101, 1000]);
    expect(find.text('Video Player'), findsOneWidget);
    expect(find.text('Android system'), findsOneWidget);
    expect(find.text('660 MB in total'), findsOneWidget);
  });

  testWidgets('switches to Wi-Fi and to longer ranges', (tester) async {
    final usage = FakeUsageRepository(apps: {NetworkKind.mobile: mobileApps});
    await tester.pumpScreen(
      const AppsScreen(),
      overrides: fakeOverrides(clock: clock, usage: usage),
    );
    await tester.tap(find.text('Wi-Fi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No Wi-Fi data used in this time.'), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await tester.pump();
    await tester.pump();
    final window = usage.queried.last;
    expect(window.endUtc.difference(window.startUtc).inDays, 30);
  });

  testWidgets('shows the access card when Usage Access is off', (tester) async {
    await tester.pumpScreen(
      const AppsScreen(),
      overrides: fakeOverrides(
        clock: clock,
        usage: FakeUsageRepository(access: false),
      ),
    );
    expect(find.byKey(const Key('allow-usage-access')), findsOneWidget);
  });

  testWidgets('shows a retry on other errors', (tester) async {
    await tester.pumpScreen(
      const AppsScreen(),
      overrides: fakeOverrides(
        clock: clock,
        usage: FakeUsageRepository(fail: true),
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
  });
}
