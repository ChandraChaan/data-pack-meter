import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/formatting.dart';
import '../../../core/ui/section_card.dart';
import 'usage_access_controller.dart';

/// Explains Usage Access before sending the user to system settings.
class UsageAccessCard extends StatelessWidget {
  const UsageAccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_open_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.accessCardTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.accessCardBody),
          const SizedBox(height: 16),
          const UsageAccessButton(),
        ],
      ),
    );
  }
}

class UsageAccessButton extends ConsumerWidget {
  const UsageAccessButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      key: const Key('allow-usage-access'),
      onPressed: () => showUsageAccessExplainer(context, ref),
      icon: const Icon(Icons.settings_outlined),
      label: Text(context.l10n.accessCardAction),
    );
  }
}

/// Shows why the permission is needed; opens settings only if the user agrees.
Future<void> showUsageAccessExplainer(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.data_usage),
      title: Text(l10n.accessDialogTitle),
      content: SingleChildScrollView(child: Text(l10n.accessDialogBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.notNow),
        ),
        FilledButton(
          key: const Key('open-usage-settings'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.openSettings),
        ),
      ],
    ),
  );
  if (open != true) return;
  await ref.read(openUsageAccessProvider)();
}
