import 'dart:typed_data';

enum NetworkKind { mobile, wifi }

/// Bytes received and sent.
final class Traffic {
  const Traffic({required this.rxBytes, required this.txBytes});

  static const zero = Traffic(rxBytes: 0, txBytes: 0);

  final int rxBytes;
  final int txBytes;

  int get totalBytes => rxBytes + txBytes;

  Traffic operator +(Traffic other) => Traffic(
    rxBytes: rxBytes + other.rxBytes,
    txBytes: txBytes + other.txBytes,
  );

  @override
  bool operator ==(Object other) =>
      other is Traffic && other.rxBytes == rxBytes && other.txBytes == txBytes;

  @override
  int get hashCode => Object.hash(rxBytes, txBytes);

  @override
  String toString() => 'Traffic(rx: $rxBytes, tx: $txBytes)';
}

/// Whole-device traffic over some window.
final class DeviceUsage {
  const DeviceUsage({required this.mobile, required this.wifi});

  static const zero = DeviceUsage(mobile: Traffic.zero, wifi: Traffic.zero);

  final Traffic mobile;
  final Traffic wifi;

  @override
  bool operator ==(Object other) =>
      other is DeviceUsage && other.mobile == mobile && other.wifi == wifi;

  @override
  int get hashCode => Object.hash(mobile, wifi);
}

/// What a traffic row belongs to. Android reports some traffic under
/// pseudo-apps rather than real packages.
enum AppKind {
  /// An installed app the user can recognise.
  app,

  /// Android itself and system services sharing a system user id.
  system,

  /// Apps that were uninstalled after using data.
  removed,

  /// Data shared with other devices through hotspot or tethering.
  tethering,
}

/// One app's traffic over a window, on one network.
final class AppUsage {
  const AppUsage({
    required this.uid,
    required this.kind,
    required this.label,
    required this.traffic,
    this.packageName,
    this.icon,
  });

  /// Android's user id for the app; several packages may share one.
  final int uid;
  final AppKind kind;

  /// The app's name as the launcher shows it; empty for pseudo-apps.
  final String label;
  final Traffic traffic;
  final String? packageName;

  /// PNG bytes of the app's icon, if it has one.
  final Uint8List? icon;
}

/// Sorts rows by total traffic, largest first, dropping rows with none.
List<AppUsage> rankByTraffic(Iterable<AppUsage> rows) =>
    rows.where((r) => r.traffic.totalBytes > 0).toList()..sort((a, b) {
      final byBytes = b.traffic.totalBytes.compareTo(a.traffic.totalBytes);
      return byBytes != 0 ? byBytes : a.uid.compareTo(b.uid);
    });
