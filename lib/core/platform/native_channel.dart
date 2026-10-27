import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import '../errors.dart';

/// Method calls into the app's Kotlin code (MainActivity.kt).
const MethodChannel nativeChannel = MethodChannel(
  'dev.chandra.data_pack_meter/native',
);

/// Live speed samples from the Kotlin side, one map per second.
const EventChannel speedChannel = EventChannel(
  'dev.chandra.data_pack_meter/speed',
);

/// Error code the Kotlin side uses when Usage Access is off.
const String kNoUsageAccessCode = 'NO_USAGE_ACCESS';

/// Calls [method] and maps platform failures to typed [AppException]s.
Future<T?> invokeNative<T>(
  String method, [
  Map<String, Object?>? arguments,
  MethodChannel channel = nativeChannel,
]) async {
  try {
    return await channel.invokeMethod<T>(method, arguments);
  } on PlatformException catch (e, stack) {
    if (e.code == kNoUsageAccessCode) {
      throw UsageAccessDeniedException(e.message ?? method);
    }
    developer.log(
      'Native call $method failed',
      name: 'native',
      error: e,
      stackTrace: stack,
    );
    throw NativeCallException('$method: ${e.code}');
  } on MissingPluginException catch (e, stack) {
    developer.log(
      'Native call $method missing',
      name: 'native',
      error: e,
      stackTrace: stack,
    );
    throw NativeCallException('$method: not implemented');
  }
}

/// Reads an int that may arrive as any [num] from the platform side.
int readInt(Map<Object?, Object?> map, String key, [int fallback = 0]) {
  final value = map[key];
  return value is num ? value.toInt() : fallback;
}

bool readBool(Map<Object?, Object?> map, String key, [bool fallback = false]) {
  final value = map[key];
  return value is bool ? value : fallback;
}

String? readString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}
