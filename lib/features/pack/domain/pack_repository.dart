import 'pack_plan.dart';

/// Stores the pack setup where the Android side (alerts, the widget, the
/// status bar meter) can read it too.
abstract interface class PackRepository {
  Future<PackSettings> load();

  Future<void> save(PackSettings settings);
}
