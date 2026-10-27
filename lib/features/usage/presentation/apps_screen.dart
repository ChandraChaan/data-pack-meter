import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/ui/formatting.dart';
import '../../../core/ui/section_card.dart';
import '../domain/usage_models.dart';
import 'apps_controller.dart';
import 'usage_access_card.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(appsFilterProvider);
    final filters = ref.read(appsFilterProvider.notifier);
    final apps = ref.watch(appUsageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                SegmentedButton<AppsRange>(
                  segments: [
                    ButtonSegment(
                      value: AppsRange.today,
                      label: Text(l10n.rangeToday),
                    ),
                    ButtonSegment(
                      value: AppsRange.week,
                      label: Text(l10n.rangeWeek),
                    ),
                    ButtonSegment(
                      value: AppsRange.month,
                      label: Text(l10n.rangeMonth),
                    ),
                  ],
                  selected: {filter.range},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => filters.setRange(s.first),
                ),
                SegmentedButton<NetworkKind>(
                  segments: [
                    ButtonSegment(
                      value: NetworkKind.mobile,
                      icon: const Icon(Icons.signal_cellular_alt),
                      label: Text(l10n.networkMobile),
                    ),
                    ButtonSegment(
                      value: NetworkKind.wifi,
                      icon: const Icon(Icons.wifi),
                      label: Text(l10n.networkWifi),
                    ),
                  ],
                  selected: {filter.network},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => filters.setNetwork(s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(appUsageProvider.future),
              child: switch (apps) {
                AsyncData(:final value) when value.isEmpty => _Message(
                  filter.network == NetworkKind.mobile
                      ? l10n.appsEmptyMobile
                      : l10n.appsEmptyWifi,
                ),
                AsyncData(:final value) => _AppList(apps: value),
                AsyncError(error: UsageAccessDeniedException()) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [UsageAccessCard()],
                ),
                AsyncError() => ListView(
                  children: [
                    ErrorRetry(
                      message: l10n.loadFailed,
                      retryLabel: l10n.retry,
                      onRetry: () => ref.invalidate(appUsageProvider),
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Icon(
          Icons.data_saver_off,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps});

  final List<AppUsage> apps;

  @override
  Widget build(BuildContext context) {
    final total = apps.fold<int>(0, (sum, a) => sum + a.traffic.totalBytes);
    final top = apps.first.traffic.totalBytes;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: apps.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              context.l10n.appsTotal(context.bytes.bytes(total)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          );
        }
        final app = apps[i - 1];
        return AppUsageTile(
          key: ValueKey(app.uid),
          app: app,
          share: top == 0 ? 0 : app.traffic.totalBytes / top,
        );
      },
    );
  }
}

class AppUsageTile extends StatelessWidget {
  const AppUsageTile({required this.app, required this.share, super.key});

  final AppUsage app;

  /// This app's traffic relative to the busiest app, 0 to 1.
  final double share;

  @override
  Widget build(BuildContext context) {
    final bytes = context.bytes;
    final theme = Theme.of(context);
    final icon = app.icon;
    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: icon != null
            ? Image.memory(
                icon,
                cacheWidth: 120,
                excludeFromSemantics: true,
                gaplessPlayback: true,
              )
            : CircleAvatar(
                child: Icon(switch (app.kind) {
                  AppKind.system => Icons.android,
                  AppKind.removed => Icons.delete_outline,
                  AppKind.tethering => Icons.wifi_tethering,
                  AppKind.app => Icons.apps,
                }),
              ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              context.appName(app),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            bytes.bytes(app.traffic.totalBytes),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: share, minHeight: 6),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.downUp(
              bytes.bytes(app.traffic.rxBytes),
              bytes.bytes(app.traffic.txBytes),
            ),
          ),
        ],
      ),
    );
  }
}
