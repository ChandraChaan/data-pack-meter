import 'package:data_pack_meter/core/providers.dart';
import 'package:data_pack_meter/features/meter/domain/meter_models.dart';
import 'package:data_pack_meter/features/meter/presentation/meter_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  ProviderContainer containerWith(FakeMeterRepository meter) =>
      ProviderContainer.test(
        retry: noRetry,
        overrides: fakeOverrides(
          clock: FixedClock(DateTime.utc(2026)),
          meter: meter,
        ),
      );

  const blocked = MeterState(
    running: false,
    startOnBoot: false,
    notificationsAllowed: false,
  );

  test('starts and stops the meter', () async {
    final meter = FakeMeterRepository();
    final container = containerWith(meter);
    await container.read(meterControllerProvider.future);
    final controller = container.read(meterControllerProvider.notifier);

    await controller.setRunning(running: true);
    expect(container.read(meterControllerProvider).value?.running, isTrue);
    expect(meter.permissionRequests, 0);

    await controller.setRunning(running: false);
    expect(container.read(meterControllerProvider).value?.running, isFalse);
  });

  test('asks for notifications first when they are blocked', () async {
    final meter = FakeMeterRepository(state: blocked);
    final container = containerWith(meter);
    await container.read(meterControllerProvider.future);

    await container
        .read(meterControllerProvider.notifier)
        .setRunning(running: true);
    expect(meter.permissionRequests, 1);
    expect(container.read(meterControllerProvider).value?.running, isTrue);
  });

  test('stays off when the user refuses notifications', () async {
    final meter = FakeMeterRepository(state: blocked, grantOnRequest: false);
    final container = containerWith(meter);
    await container.read(meterControllerProvider.future);

    await container
        .read(meterControllerProvider.notifier)
        .setRunning(running: true);
    final state = container.read(meterControllerProvider).value;
    expect(state?.running, isFalse);
    expect(state?.notificationsAllowed, isFalse);
    expect(state?.permissionRefused, isTrue);
    expect(meter.state.running, isFalse);
  });

  test('remembers start on boot', () async {
    final meter = FakeMeterRepository();
    final container = containerWith(meter);
    await container.read(meterControllerProvider.future);
    await container
        .read(meterControllerProvider.notifier)
        .setStartOnBoot(enabled: true);
    expect(container.read(meterControllerProvider).value?.startOnBoot, isTrue);
  });

  test('live speed passes samples through', () async {
    final meter = FakeMeterRepository();
    final container = containerWith(meter);
    final sub = container.listen(liveSpeedProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    meter.speeds.add(const LiveSpeed(rxPerSecond: 2048, txPerSecond: 10));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(liveSpeedProvider).value,
      const LiveSpeed(rxPerSecond: 2048, txPerSecond: 10),
    );
  });
}
