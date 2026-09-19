import 'package:flutter/foundation.dart';

/// Logging level for application diagnostics.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A privacy-first logger wrapper.
///
/// HARD PRIVACY RULE: Never read, log, store, or upload on-screen text,
/// messages, usernames, or video titles. Only use view IDs, class names,
/// package names, event types, and timestamps.
class AppLogger {
  const AppLogger._();

  static void log(
    String tag,
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && level == LogLevel.debug) return;

    final prefix = switch (level) {
      LogLevel.debug => 'DEBUG',
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERROR',
    };

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] [$prefix] [$tag] $message');
    if (error != null) {
      debugPrint('[$timestamp] [$prefix] [$tag] Error: $error');
    }
    if (stackTrace != null && (level == LogLevel.error || !kReleaseMode)) {
      debugPrint('[$timestamp] [$prefix] [$tag] StackTrace:\n$stackTrace');
    }
  }

  static void d(String tag, String message) =>
      log(tag, message, level: LogLevel.debug);

  static void i(String tag, String message) =>
      log(tag, message);

  static void w(String tag, String message, [Object? error]) =>
      log(tag, message, level: LogLevel.warning, error: error);

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) =>
      log(
        tag,
        message,
        level: LogLevel.error,
        error: error,
        stackTrace: stackTrace,
      );
}
