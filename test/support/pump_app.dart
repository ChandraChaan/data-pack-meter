import 'package:data_pack_meter/app.dart';
import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

extension PumpApp on WidgetTester {
  /// Shows [child] with the app's theme and strings and the given overrides.
  Future<void> pumpScreen(
    Widget child, {
    required List<Override> overrides,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: noRetry,
        child: MaterialApp(
          theme: buildTheme(brightness),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    // Let the fake repositories' futures complete.
    await pump();
    await pump();
  }
}
