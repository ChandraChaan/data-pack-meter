import '../../pack/domain/pack_period.dart';
import 'usage_models.dart';

/// Reads Android's network statistics.
///
/// Every query throws `UsageAccessDeniedException` while Usage Access is off.
abstract interface class UsageRepository {
  Future<bool> hasUsageAccess();

  /// Opens the system screen where the user can turn on Usage Access.
  Future<void> openUsageAccessSettings();

  Future<DeviceUsage> deviceUsage(PackPeriod window);

  /// Traffic per app on [network] within [window].
  Future<List<AppUsage>> appUsage(NetworkKind network, PackPeriod window);
}
