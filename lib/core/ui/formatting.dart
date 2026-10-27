import 'package:flutter/widgets.dart';

import '../../features/usage/domain/usage_models.dart';
import '../../l10n/app_localizations.dart';
import '../format/byte_format.dart';
import '../format/duration_parts.dart';

extension FormattingContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ByteFormatter get bytes =>
      ByteFormatter(Localizations.localeOf(this).toLanguageTag());

  /// "5 h 12 min", "2 d 4 h" or "12 min".
  String duration(Duration duration) => switch (DurationParts.of(duration)) {
    DaysHours(:final days, :final hours) => l10n.durationDaysHours(days, hours),
    HoursMinutes(:final hours, :final minutes) => l10n.durationHoursMinutes(
      hours,
      minutes,
    ),
    Minutes(:final minutes) => l10n.durationMinutes(minutes),
  };

  /// The name to show for an app row, including Android's pseudo-apps.
  String appName(AppUsage app) => switch (app.kind) {
    AppKind.system => l10n.kindSystem,
    AppKind.removed => l10n.kindRemoved,
    AppKind.tethering => l10n.kindTethering,
    AppKind.app when app.label.isNotEmpty => app.label,
    AppKind.app => app.packageName ?? l10n.unknownApp(app.uid),
  };
}
