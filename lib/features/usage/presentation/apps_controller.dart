import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/time/clock.dart';
import '../../pack/domain/pack_period.dart';
import '../data/channel_usage_repository.dart';
import '../domain/usage_models.dart';

enum AppsRange {
  today(1),
  week(7),
  month(30);

  const AppsRange(this.days);

  final int days;
}

/// Which slice of per-app traffic the Apps screen shows.
final class AppsFilter {
  const AppsFilter({
    this.range = AppsRange.today,
    this.network = NetworkKind.mobile,
  });

  final AppsRange range;
  final NetworkKind network;

  AppsFilter copyWith({AppsRange? range, NetworkKind? network}) =>
      AppsFilter(range: range ?? this.range, network: network ?? this.network);

  @override
  bool operator ==(Object other) =>
      other is AppsFilter && other.range == range && other.network == network;

  @override
  int get hashCode => Object.hash(range, network);
}

final appsFilterProvider = NotifierProvider<AppsFilterController, AppsFilter>(
  AppsFilterController.new,
);

class AppsFilterController extends Notifier<AppsFilter> {
  @override
  AppsFilter build() => const AppsFilter();

  void setRange(AppsRange range) => state = state.copyWith(range: range);

  void setNetwork(NetworkKind network) =>
      state = state.copyWith(network: network);
}

/// Per-app traffic for the current filter, largest first.
final appUsageProvider = FutureProvider<List<AppUsage>>((ref) {
  final filter = ref.watch(appsFilterProvider);
  final clock = ref.watch(clockProvider);
  final window = PackPeriod.lastDays(
    filter.range.days,
    clock.nowUtc(),
    WallClock.of(clock),
  );
  return ref.watch(usageRepositoryProvider).appUsage(filter.network, window);
});
