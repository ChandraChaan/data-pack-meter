import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/features/pack/domain/pack_plan.dart';
import 'package:data_pack_meter/features/pack/presentation/pack_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test('saving with alerts on asks for notifications', () async {
    final pack = FakePackRepository();
    final meter = FakeMeterRepository();
    final container = ProviderContainer.test(
      retry: noRetry,
      overrides: fakeOverrides(
        clock: FixedClock(DateTime.utc(2026)),
        pack: pack,
        meter: meter,
      ),
    );
    await container.read(packControllerProvider.future);
    const settings = PackSettings(plan: DailyPack(limitBytes: gb));
    await container.read(packControllerProvider.notifier).save(settings);
    expect(pack.settings, settings);
    expect(container.read(packControllerProvider).value, settings);
    expect(meter.permissionRequests, 1);
  });

  test('saving with alerts off does not ask', () async {
    final meter = FakeMeterRepository();
    final container = ProviderContainer.test(
      retry: noRetry,
      overrides: fakeOverrides(
        clock: FixedClock(DateTime.utc(2026)),
        meter: meter,
      ),
    );
    await container.read(packControllerProvider.future);
    await container
        .read(packControllerProvider.notifier)
        .save(
          const PackSettings(
            plan: DailyPack(limitBytes: gb),
            alertsEnabled: false,
          ),
        );
    expect(meter.permissionRequests, 0);
  });
}
