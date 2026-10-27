import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../meter/data/channel_meter_repository.dart';
import '../../meter/presentation/meter_controller.dart';
import '../../usage/presentation/today_controller.dart';
import '../data/channel_pack_repository.dart';
import '../domain/pack_plan.dart';

final packControllerProvider =
    AsyncNotifierProvider<PackController, PackSettings>(PackController.new);

class PackController extends AsyncNotifier<PackSettings> {
  @override
  Future<PackSettings> build() => ref.watch(packRepositoryProvider).load();

  Future<void> save(PackSettings settings) async {
    await ref.read(packRepositoryProvider).save(settings);
    if (!ref.mounted) return;
    state = AsyncData(settings);
    ref.invalidate(todayControllerProvider);
    if (settings.alertsEnabled) {
      // The 80% and 100% alerts are notifications (Android 13+ asks first).
      await ref.read(meterRepositoryProvider).requestNotificationPermission();
      if (!ref.mounted) return;
      ref.invalidate(meterControllerProvider);
    }
  }
}
