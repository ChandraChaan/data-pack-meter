// Renders the README screenshots from the real screens with sample data.
//
//   flutter test tool/screenshots --update-goldens
//
// then copy tool/screenshots/out/*.png to docs/screenshots/. Kept out of
// test/ because font rendering differs between machines.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:data_pack_meter/app.dart';
import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/features/meter/domain/meter_models.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/usage/domain/usage_models.dart';
import 'package:data_pack_meter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/fakes.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Light']) {
    roboto.addFont(read('$fonts/Roboto-$weight.ttf'));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('$fonts/MaterialIcons-Regular.otf'))).load();
  // The SDK's Roboto has no arrows; phones fall back to a system font.
  await (FontLoader(
    'Arrows',
  )..addFont(read('/System/Library/Fonts/Supplemental/Arial.ttf'))).load();
}

/// A simple coloured app tile with a glyph, standing in for app icons.
Future<Uint8List> _icon(Color color, IconData glyph) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 96.0;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, size, size),
      const Radius.circular(24),
    ),
    Paint()..color = color,
  );
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(glyph.codePoint),
      style: TextStyle(
        fontFamily: glyph.fontFamily,
        fontSize: 58,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset((size - painter.width) / 2, (size - painter.height) / 2),
  );
  final image = await recorder.endRecording().toImage(96, 96);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

ThemeData _withArrows(ThemeData theme) => theme.copyWith(
  textTheme: theme.textTheme.apply(fontFamilyFallback: const ['Arrows']),
);

void main() {
  // 16:20 on 27 October in India: the daily pack renews in 7 h 40 min.
  final clock = FixedClock(DateTime.utc(2026, 10, 27, 10, 50));
  final todayStart = DateTime.utc(2026, 10, 26, 18, 30);

  late List<AppUsage> mobileApps;

  setUpAll(() async {
    await _loadFonts();
    Future<AppUsage> app(
      int uid,
      String label,
      Color color,
      IconData glyph,
      double rxMb,
      double txMb,
    ) async => AppUsage(
      uid: uid,
      kind: AppKind.app,
      label: label,
      traffic: Traffic(
        rxBytes: (rxMb * mb).round(),
        txBytes: (txMb * mb).round(),
      ),
      icon: await _icon(color, glyph),
    );
    mobileApps = [
      await app(
        10101,
        'Video Player',
        const Color(0xFFD84343),
        Icons.play_arrow,
        512,
        9.4,
      ),
      await app(
        10102,
        'Short Clips',
        const Color(0xFF7E57C2),
        Icons.movie,
        233,
        4.1,
      ),
      await app(
        10103,
        'Chat',
        const Color(0xFF2E9E5B),
        Icons.chat_bubble,
        96.4,
        31.2,
      ),
      await app(10104, 'Maps', const Color(0xFF1E88E5), Icons.place, 58.7, 6.3),
      await app(
        10105,
        'Music',
        const Color(0xFFF4511E),
        Icons.music_note,
        41.2,
        0.9,
      ),
      await app(
        10106,
        'Browser',
        const Color(0xFF00897B),
        Icons.public,
        27.5,
        3.2,
      ),
      await app(
        10107,
        'Photos Backup',
        const Color(0xFFFFB300),
        Icons.photo,
        2.1,
        18.6,
      ),
      const AppUsage(
        uid: 1000,
        kind: AppKind.system,
        label: '',
        traffic: Traffic(rxBytes: 9 * mb, txBytes: 3 * mb),
      ),
    ];
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required int tab,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final meter = FakeMeterRepository(
      state: const MeterState(
        running: true,
        startOnBoot: true,
        notificationsAllowed: true,
      ),
    );
    addTearDown(meter.close);
    await tester.pumpWidget(
      ProviderScope(
        retry: noRetry,
        overrides: fakeOverrides(
          clock: clock,
          pack: FakePackRepository(
            PackSettings(plan: DailyPack(limitBytes: (1.5 * gb).round())),
          ),
          meter: meter,
          usage: FakeUsageRepository(
            usage: {
              todayStart: DeviceUsage(
                mobile: Traffic(rxBytes: (1.02 * gb).round(), txBytes: 76 * mb),
                wifi: Traffic(rxBytes: (2.3 * gb).round(), txBytes: 140 * mb),
              ),
            },
            apps: {NetworkKind.mobile: mobileApps},
          ),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _withArrows(buildTheme(Brightness.light)),
          darkTheme: _withArrows(buildTheme(Brightness.dark)),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pump();
    meter.speeds.add(
      LiveSpeed(rxPerSecond: (1.4 * mb).round(), txPerSecond: 86 * 1024),
    );
    if (tab != 0) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
    }
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Decode the PNG app icons before the shot.
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  testWidgets('today', (t) => shoot(t, name: 'today', tab: 0));
  testWidgets('apps', (t) => shoot(t, name: 'apps', tab: 1));
  testWidgets('settings', (t) => shoot(t, name: 'settings', tab: 2));
  testWidgets(
    'today dark',
    (t) => shoot(t, name: 'today-dark', tab: 0, brightness: Brightness.dark),
  );
}
