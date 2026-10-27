import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/formatting.dart';
import '../../../core/ui/pack_ring.dart';
import '../../../core/ui/section_card.dart';
import '../../meter/presentation/live_speed_card.dart';
import '../../pack/domain/pack_plan.dart';
import '../../pack/domain/pack_status.dart';
import '../domain/usage_models.dart';
import 'today_controller.dart';
import 'usage_access_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({required this.onSetUpPack, super.key});

  /// Takes the user to the pack form.
  final VoidCallback onSetUpPack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(todayControllerProvider.notifier).refresh(),
        child: switch (today) {
          AsyncData(:final value) => _TodayList(
            state: value,
            onSetUpPack: onSetUpPack,
          ),
          AsyncError() => ListView(
            children: [
              ErrorRetry(
                message: context.l10n.loadFailed,
                retryLabel: context.l10n.retry,
                onRetry: () => ref.invalidate(todayControllerProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  const _TodayList({required this.state, required this.onSetUpPack});

  final TodayState state;
  final VoidCallback onSetUpPack;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    final children = <Widget>[
      if (state is TodayNeedsAccess) const UsageAccessCard(),
      if (state is TodayReady)
        if (state.status case final status?)
          PackStatusCard(status: status)
        else
          _SetUpPackCard(onSetUpPack: onSetUpPack),
      if (state is TodayReady) _TodayTotals(usage: state.today),
      const LiveSpeedCard(),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// The ring, how much is used and left, and when the pack renews.
class PackStatusCard extends StatelessWidget {
  const PackStatusCard({required this.status, super.key});

  final PackStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bytes = context.bytes;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (
      Color color,
      String levelText,
      IconData levelIcon,
    ) = switch (status.level) {
      PackLevel.ok => (scheme.primary, l10n.levelOk, Icons.check_circle),
      PackLevel.nearLimit => (
        scheme.tertiary,
        l10n.levelNear,
        Icons.warning_amber_rounded,
      ),
      PackLevel.exceeded => (scheme.error, l10n.levelExceeded, Icons.block),
    };
    final remaining = status.overBytes > 0
        ? l10n.packOver(bytes.bytes(status.overBytes))
        : l10n.packLeft(bytes.bytes(status.remainingBytes));
    return SectionCard(
      title: switch (status.plan) {
        DailyPack() => l10n.dailyPackLabel,
        MonthlyPack() => l10n.monthlyPackLabel,
      },
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
            child: AspectRatio(
              aspectRatio: 1,
              child: PackRing(
                fraction: status.fraction,
                color: color,
                semanticsLabel: l10n.ringSemantics(status.percentUsed),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.percentUsed(status.percentUsed),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.percentUsedLabel,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.packOfLimit(
              bytes.bytes(status.usedBytes),
              bytes.bytes(status.limitBytes),
            ),
            key: const Key('pack-used'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(remaining, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(levelIcon, color: color, size: 18),
                label: Text(levelText),
              ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(l10n.resetsIn(context.duration(status.timeLeft))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetUpPackCard extends StatelessWidget {
  const _SetUpPackCard({required this.onSetUpPack});

  final VoidCallback onSetUpPack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      title: l10n.setupCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setupCardBody),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('set-up-pack'),
            onPressed: onSetUpPack,
            child: Text(l10n.setupCardAction),
          ),
        ],
      ),
    );
  }
}

class _TodayTotals extends StatelessWidget {
  const _TodayTotals({required this.usage});

  final DeviceUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TotalTile(
            icon: Icons.signal_cellular_alt,
            title: l10n.todayMobile,
            traffic: usage.mobile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TotalTile(
            icon: Icons.wifi,
            title: l10n.todayWifi,
            traffic: usage.wifi,
          ),
        ),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.icon,
    required this.title,
    required this.traffic,
  });

  final IconData icon;
  final String title;
  final Traffic traffic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = context.bytes;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: theme.textTheme.labelLarge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bytes.bytes(traffic.totalBytes),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.downUp(
              bytes.bytes(traffic.rxBytes),
              bytes.bytes(traffic.txBytes),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
