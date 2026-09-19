// tool/publish_rules.dart
// ignore_for_file: avoid_catches_without_on_clauses, omit_local_variable_types, cascade_invocations
// Admin CLI script to validate and publish detector_rules to Supabase.
// Usage:
//   dart run tool/publish_rules.dart [--file=assets/detector_rules.json] [--rollout=100] [--min-app-build=1] [--dry-run]

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  String filePath = 'assets/detector_rules.json';
  int? versionOverride;
  int rolloutPercentage = 100;
  int minAppBuild = 1;
  bool dryRun = false;
  String? supabaseUrl = Platform.environment['SUPABASE_URL'];
  String? supabaseKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  for (final arg in args) {
    if (arg.startsWith('--file=')) {
      filePath = arg.substring('--file='.length);
    } else if (arg.startsWith('--version=')) {
      versionOverride = int.tryParse(arg.substring('--version='.length));
    } else if (arg.startsWith('--rollout=')) {
      rolloutPercentage = int.tryParse(arg.substring('--rollout='.length)) ?? 100;
    } else if (arg.startsWith('--min-app-build=')) {
      minAppBuild = int.tryParse(arg.substring('--min-app-build='.length)) ?? 1;
    } else if (arg == '--dry-run') {
      dryRun = true;
    } else if (arg.startsWith('--supabase-url=')) {
      supabaseUrl = arg.substring('--supabase-url='.length);
    } else if (arg.startsWith('--supabase-key=')) {
      supabaseKey = arg.substring('--supabase-key='.length);
    }
  }

  stdout.writeln('=== ScrollGuard Detector Rules Publisher ===');
  stdout.writeln('Source File: $filePath');
  stdout.writeln('Rollout: $rolloutPercentage%');
  stdout.writeln('Min App Build: $minAppBuild');
  stdout.writeln('Dry Run: $dryRun');

  final file = File(filePath);
  if (!file.existsSync()) {
    stderr.writeln('Error: File not found at $filePath');
    exit(1);
  }

  final content = file.readAsStringSync();
  dynamic parsedJson;
  try {
    parsedJson = jsonDecode(content);
  } catch (e) {
    stderr.writeln('Error: Malformed JSON in $filePath: $e');
    exit(1);
  }

  if (parsedJson is! Map<String, dynamic>) {
    stderr.writeln('Error: Root JSON must be an object');
    exit(1);
  }

  // Schema Validation
  final validationErrors = validateRuleSchema(parsedJson);
  if (validationErrors.isNotEmpty) {
    stderr.writeln('Validation Failed:');
    for (final err in validationErrors) {
      stderr.writeln('  - $err');
    }
    exit(1);
  }

  final version = versionOverride ?? (parsedJson['version'] as int);
  stdout.writeln('Validated ruleset successfully for version: $version (${(parsedJson['apps'] as List).length} apps)');

  if (dryRun) {
    stdout.writeln('[Dry Run] Schema valid. Skipping publishing to Supabase.');
    exit(0);
  }

  if (supabaseUrl == null || supabaseKey == null) {
    stderr.writeln('Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set to publish (or use --dry-run).');
    exit(1);
  }

  // Publish to Supabase via REST API
  final endpoint = Uri.parse('$supabaseUrl/rest/v1/detector_rules');
  final client = HttpClient();
  try {
    final request = await client.postUrl(endpoint);
    request.headers.set('apikey', supabaseKey);
    request.headers.set('Authorization', 'Bearer $supabaseKey');
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Prefer', 'resolution=merge-duplicates');

    final payload = jsonEncode({
      'version': version,
      'rules': parsedJson,
      'min_app_build': minAppBuild,
      'rollout_percentage': rolloutPercentage,
      'is_active': true,
    });

    request.write(payload);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      stdout.writeln('Successfully published detector rules v$version to Supabase (Status ${response.statusCode})!');
    } else {
      stderr.writeln('Failed to publish rules. Status ${response.statusCode}: $responseBody');
      exit(1);
    }
  } catch (e) {
    stderr.writeln('Error connecting to Supabase: $e');
    exit(1);
  } finally {
    client.close();
  }
}

List<String> validateRuleSchema(Map<String, dynamic> json) {
  final errors = <String>[];

  if (!json.containsKey('version') || json['version'] is! int) {
    errors.add('Missing or invalid "version" (must be an integer)');
  }

  if (!json.containsKey('apps') || json['apps'] is! List) {
    errors.add('Missing or invalid "apps" (must be a list)');
    return errors;
  }

  final apps = json['apps'] as List;
  if (apps.isEmpty) {
    errors.add('"apps" list cannot be empty');
  }

  final forbiddenPrivacyKeywords = ['text', 'title', 'caption', 'username', 'handle', 'comment'];

  for (var i = 0; i < apps.length; i++) {
    final app = apps[i];
    if (app is! Map<String, dynamic>) {
      errors.add('apps[$i] must be an object');
      continue;
    }

    final id = app['id'];
    if (id is! String || id.isEmpty) {
      errors.add('apps[$i].id is missing or empty');
    }

    final pkg = app['package'];
    if (pkg is! String || pkg.isEmpty) {
      errors.add('apps[$i].package is missing or empty');
    }

    // Privacy rule check
    for (final key in app.keys) {
      if (forbiddenPrivacyKeywords.contains(key.toLowerCase())) {
        errors.add('Privacy violation: apps[$i] contains forbidden field "$key"');
      }
    }

    if (app.containsKey('feedSignals')) {
      final signals = app['feedSignals'];
      if (signals is! List) {
        errors.add('apps[$i].feedSignals must be a list');
      } else {
        for (var s = 0; s < signals.length; s++) {
          final sig = signals[s];
          if (sig is! Map<String, dynamic>) {
            errors.add('apps[$i].feedSignals[$s] must be an object');
          } else {
            if (!sig.containsKey('type') || sig['type'] is! String) {
              errors.add('apps[$i].feedSignals[$s].type is missing or invalid');
            }
            if (!sig.containsKey('ids') || sig['ids'] is! List) {
              errors.add('apps[$i].feedSignals[$s].ids is missing or invalid');
            }
          }
        }
      }
    }
  }

  return errors;
}
