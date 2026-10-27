import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channel_meter_repository.dart';
import '../domain/meter_models.dart';

final meterControllerProvider =
    AsyncNotifierProvider<MeterController, MeterState>(MeterController.new);

/// Download and upload speed, once a second, while someone is watching.
final liveSpeedProvider = StreamProvider.autoDispose<LiveSpeed>(
  (ref) => ref.watch(meterRepositoryProvider).liveSpeed(),
);

class MeterController extends AsyncNotifier<MeterState> {
  @override
  Future<MeterState> build() => ref.watch(meterRepositoryProvider).load();

  /// Turns the status bar meter on or off, asking for the notification
  /// permission first when Android needs it.
  Future<void> setRunning({required bool running}) async {
    final repo = ref.read(meterRepositoryProvider);
    if (running) {
      final current = state.value ?? await repo.load();
      if (!current.notificationsAllowed &&
          !await repo.requestNotificationPermission()) {
        if (!ref.mounted) return;
        state = AsyncData(
          current.copyWith(
            running: false,
            notificationsAllowed: false,
            permissionRefused: true,
          ),
        );
        return;
      }
      await repo.start();
    } else {
      await repo.stop();
    }
    await _reload();
  }

  Future<void> setStartOnBoot({required bool enabled}) async {
    await ref.read(meterRepositoryProvider).setStartOnBoot(enabled: enabled);
    await _reload();
  }

  /// Picks up permission changes made in system settings.
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    final next = await AsyncValue.guard(ref.read(meterRepositoryProvider).load);
    if (!ref.mounted) return;
    state = next;
  }
}
