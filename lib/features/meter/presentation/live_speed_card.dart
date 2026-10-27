import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/formatting.dart';
import '../../../core/ui/section_card.dart';
import '../domain/meter_models.dart';
import 'meter_controller.dart';

/// Current speed, plus the switch for the status bar meter.
class LiveSpeedCard extends ConsumerWidget {
  const LiveSpeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final speed = ref.watch(liveSpeedProvider).value ?? LiveSpeed.zero;
    final bytes = context.bytes;
    return SectionCard(
      title: l10n.liveSpeedTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.liveSpeedValue(
              bytes.speed(speed.rxPerSecond),
              bytes.speed(speed.txPerSecond),
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          const MeterSwitch(),
        ],
      ),
    );
  }
}

/// On/off for the status bar meter, with the permission hint when needed.
class MeterSwitch extends ConsumerWidget {
  const MeterSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final meter = ref.watch(meterControllerProvider).value;
    final controller = ref.read(meterControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('meter-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.meterSwitch),
          subtitle: Text(l10n.meterSwitchHint),
          value: meter?.running ?? false,
          onChanged: meter == null
              ? null
              : (on) => controller.setRunning(running: on),
        ),
        if (meter != null && meter.permissionRefused)
          Text(
            l10n.notificationsDenied,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
