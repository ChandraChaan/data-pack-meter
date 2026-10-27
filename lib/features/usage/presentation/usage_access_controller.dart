import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channel_usage_repository.dart';

/// Whether Usage Access is on; re-checked whenever the app comes back.
final usageAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(usageRepositoryProvider).hasUsageAccess(),
);

/// Sends the user to the system Usage Access screen.
final openUsageAccessProvider = Provider<Future<void> Function()>(
  (ref) => ref.watch(usageRepositoryProvider).openUsageAccessSettings,
);
