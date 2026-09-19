// lib/core/rules/rules_updater.dart
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for remote detector rules updater.
final rulesUpdaterProvider = Provider<RulesUpdater>((ref) {
  final nativeBridge = ref.watch(nativeBridgeProvider);
  SupabaseClient? supabase;
  try {
    supabase = Supabase.instance.client;
  } on Object {
    // Supabase might not be initialized yet (e.g. offline/guest)
    supabase = null;
  }

  return RulesUpdater(nativeBridge: nativeBridge, supabaseClient: supabase);
});

/// Fetches remote detector rules from Supabase edge function `get-rules`,
/// validates against strict schema, and pushes updates to native layer.
class RulesUpdater {
  RulesUpdater({
    required NativeBridge nativeBridge,
    SupabaseClient? supabaseClient,
    int initialVersion = 1,
  })  : _nativeBridge = nativeBridge,
        _supabaseClient = supabaseClient,
        _currentVersion = initialVersion;

  final NativeBridge _nativeBridge;
  final SupabaseClient? _supabaseClient;
  int _currentVersion;

  int get currentVersion => _currentVersion;

  /// Checks for remote rule updates. Returns true if new rules were applied.
  Future<bool> checkForUpdates({
    int appBuild = 1,
    String? deviceId,
    Map<String, dynamic>? mockResponse,
  }) async {
    try {
      Map<String, dynamic>? data;

      if (mockResponse != null) {
        data = mockResponse;
      } else if (_supabaseClient != null) {
        final res = await _supabaseClient.functions.invoke(
          'get-rules',
          body: {
            'app_build': appBuild,
            if (deviceId != null) 'device_id': deviceId,
          },
        );

        if (res.status != 200) {
          dev.log('get-rules returned status ${res.status}', name: 'RulesUpdater');
          return false;
        }

        if (res.data is Map<String, dynamic>) {
          data = res.data as Map<String, dynamic>;
        } else if (res.data is String) {
          data = jsonDecode(res.data as String) as Map<String, dynamic>;
        }
      } else {
        // Supabase client not available
        return false;
      }

      if (data == null) return false;

      // Validate payload structure
      if (!isValidRulesPayload(data)) {
        dev.log('Invalid rules payload received from server', name: 'RulesUpdater');
        return false;
      }

      final newVersion = data['version'] as int;
      if (newVersion <= _currentVersion) {
        dev.log('Rules already up to date (v$_currentVersion >= v$newVersion)', name: 'RulesUpdater');
        return false;
      }

      final rulesObj = data['rules'];
      final rulesJsonString = jsonEncode(rulesObj);

      // Apply to native bridge
      await _nativeBridge.applyDetectorRules(rulesJsonString);
      _currentVersion = newVersion;
      dev.log('Applied detector rules v$newVersion to native layer', name: 'RulesUpdater');
      return true;
    } on Object catch (e, stack) {
      dev.log('Error updating detector rules: $e', name: 'RulesUpdater', error: e, stackTrace: stack);
      return false;
    }

  }

  /// Strict validation of rules payload to prevent malformed or malicious payloads from bricking detection.
  static bool isValidRulesPayload(Map<String, dynamic> data) {
    if (!data.containsKey('version') || data['version'] is! int) {
      return false;
    }

    if (!data.containsKey('rules') || data['rules'] is! Map<String, dynamic>) {
      return false;
    }

    final rules = data['rules'] as Map<String, dynamic>;
    if (!rules.containsKey('apps') || rules['apps'] is! List) {
      return false;
    }

    final apps = rules['apps'] as List;
    if (apps.isEmpty) {
      return false;
    }

    for (final app in apps) {
      if (app is! Map<String, dynamic>) return false;
      if (!app.containsKey('id') || app['id'] is! String || (app['id'] as String).isEmpty) {
        return false;
      }
      if (!app.containsKey('package') || app['package'] is! String || (app['package'] as String).isEmpty) {
        return false;
      }

      // Privacy verification: reject any rules containing forbidden fields
      for (final key in app.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('text') ||
            lower.contains('title') ||
            lower.contains('username') ||
            lower.contains('caption')) {
          return false;
        }
      }
    }

    return true;
  }
}
