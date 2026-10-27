import 'meter_models.dart';

/// Controls the status bar speed meter, a foreground service on Android.
abstract interface class MeterRepository {
  Future<MeterState> load();

  Future<void> start();

  Future<void> stop();

  Future<void> setStartOnBoot({required bool enabled});

  /// Asks for the notification permission; returns whether it is granted.
  Future<bool> requestNotificationPermission();

  /// Live device speed, sampled once a second while listened to.
  Stream<LiveSpeed> liveSpeed();
}
