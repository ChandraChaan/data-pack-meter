import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'time/clock.dart';

/// The clock every controller reads, replaced with a fixed one in tests.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Turns off Riverpod's automatic retries: failures go straight to the
/// screen's error state, which has its own retry button.
Duration? noRetry(int retryCount, Object error) => null;
