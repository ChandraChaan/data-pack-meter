import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/formatting.dart';
import '../../../core/ui/section_card.dart';
import '../../meter/presentation/live_speed_card.dart';
import '../../meter/presentation/meter_controller.dart';
import '../../pack/presentation/pack_controller.dart';
import '../../pack/presentation/pack_form.dart';
import '../../usage/presentation/usage_access_card.dart';
import '../../usage/presentation/usage_access_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pack = ref.watch(packControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: l10n.packSection,
            child: switch (pack) {
              AsyncData(:final value) => PackForm(initial: value),
              AsyncError() => ErrorRetry(
                message: l10n.loadFailed,
                retryLabel: l10n.retry,
                onRetry: () => ref.invalidate(packControllerProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.meterSection,
            child: const Column(children: [MeterSwitch(), _BootSwitch()]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.privacySection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.privacyBody),
                const SizedBox(height: 8),
                const _UsageAccessTile(),
                Text(
                  l10n.accuracyNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BootSwitch extends ConsumerWidget {
  const _BootSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meter = ref.watch(meterControllerProvider).value;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.l10n.meterBootSwitch),
      value: meter?.startOnBoot ?? false,
      onChanged: meter == null
          ? null
          : (on) => ref
                .read(meterControllerProvider.notifier)
                .setStartOnBoot(enabled: on),
    );
  }
}

class _UsageAccessTile extends ConsumerWidget {
  const _UsageAccessTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final granted = ref.watch(usageAccessProvider).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        granted == true ? Icons.verified_user_outlined : Icons.lock_outline,
      ),
      title: Text(l10n.usageAccessTile),
      subtitle: Text(
        granted == true ? l10n.usageAccessOn : l10n.usageAccessOff,
      ),
      onTap: granted == true
          ? null
          : () => showUsageAccessExplainer(context, ref),
    );
  }
}
