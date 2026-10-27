/// Download and upload speed over the last second.
final class LiveSpeed {
  const LiveSpeed({required this.rxPerSecond, required this.txPerSecond});

  static const zero = LiveSpeed(rxPerSecond: 0, txPerSecond: 0);

  final int rxPerSecond;
  final int txPerSecond;

  @override
  bool operator ==(Object other) =>
      other is LiveSpeed &&
      other.rxPerSecond == rxPerSecond &&
      other.txPerSecond == txPerSecond;

  @override
  int get hashCode => Object.hash(rxPerSecond, txPerSecond);
}

/// The status bar meter's switches and Android's notification permission.
final class MeterState {
  const MeterState({
    required this.running,
    required this.startOnBoot,
    required this.notificationsAllowed,
    this.permissionRefused = false,
  });

  /// Whether the speed notification is showing.
  final bool running;

  /// Whether to bring the meter back after the phone restarts.
  final bool startOnBoot;

  /// Without it Android hides the meter (Android 13 and later).
  final bool notificationsAllowed;

  /// The user just said no to notifications when turning the meter on.
  final bool permissionRefused;

  MeterState copyWith({
    bool? running,
    bool? startOnBoot,
    bool? notificationsAllowed,
    bool? permissionRefused,
  }) => MeterState(
    running: running ?? this.running,
    startOnBoot: startOnBoot ?? this.startOnBoot,
    notificationsAllowed: notificationsAllowed ?? this.notificationsAllowed,
    permissionRefused: permissionRefused ?? this.permissionRefused,
  );

  @override
  bool operator ==(Object other) =>
      other is MeterState &&
      other.running == running &&
      other.startOnBoot == startOnBoot &&
      other.notificationsAllowed == notificationsAllowed &&
      other.permissionRefused == permissionRefused;

  @override
  int get hashCode => Object.hash(
    running,
    startOnBoot,
    notificationsAllowed,
    permissionRefused,
  );
}
