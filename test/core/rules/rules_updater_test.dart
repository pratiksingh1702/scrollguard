// test/core/rules/rules_updater_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/rules/rules_updater.dart';

class MockNativeBridge extends FakeNativeBridge {
  String? lastAppliedRulesJson;
  int applyCallCount = 0;

  @override
  Future<void> applyDetectorRules(String rulesJson) async {
    lastAppliedRulesJson = rulesJson;
    applyCallCount++;
  }
}

void main() {
  group('RulesUpdater', () {
    late MockNativeBridge mockBridge;
    late RulesUpdater updater;

    setUp(() {
      mockBridge = MockNativeBridge();
      updater = RulesUpdater(nativeBridge: mockBridge, initialVersion: 1);
    });

    test('applies valid new rules payload and increments version', () async {
      final validPayload = {
        'version': 2,
        'rules': {
          'version': 2,
          'apps': [
            {
              'id': 'youtube_shorts',
              'package': 'com.google.android.youtube',
              'label': 'YouTube Shorts',
              'feedSignals': [
                {
                  'type': 'viewIdPresent',
                  'ids': ['com.google.android.youtube:id/reel_recycler'],
                }
              ],
            },
          ],
        },
      };

      final updated = await updater.checkForUpdates(mockResponse: validPayload);

      expect(updated, isTrue);
      expect(updater.currentVersion, equals(2));
      expect(mockBridge.applyCallCount, equals(1));
      expect(mockBridge.lastAppliedRulesJson, contains('reel_recycler'));
    });

    test('ignores payload if version is less than or equal to current', () async {
      final stalePayload = {
        'version': 1,
        'rules': {
          'version': 1,
          'apps': [
            {
              'id': 'youtube_shorts',
              'package': 'com.google.android.youtube',
            },
          ],
        },
      };

      final updated = await updater.checkForUpdates(mockResponse: stalePayload);

      expect(updated, isFalse);
      expect(updater.currentVersion, equals(1));
      expect(mockBridge.applyCallCount, equals(0));
    });

    test('rejects malformed payload without calling bridge', () async {
      final malformedPayloads = [
        {'version': 'not_an_int', 'rules': {}},
        {
          'version': 2,
          'rules': {'apps': []}, // empty apps
        },
        {
          'version': 2,
          'rules': {
            'apps': [
              {'id': ''}, // missing package and empty id
            ],
          },
        },
        {
          'version': 2,
          'rules': 'not_a_map',
        },
      ];

      for (final payload in malformedPayloads) {
        final updated = await updater.checkForUpdates(
          mockResponse: payload as Map<String, dynamic>,
        );
        expect(updated, isFalse);
        expect(mockBridge.applyCallCount, equals(0));
      }
    });

    test('rejects payload with privacy-violating fields', () async {
      final privacyViolatingPayload = {
        'version': 2,
        'rules': {
          'version': 2,
          'apps': [
            {
              'id': 'youtube_shorts',
              'package': 'com.google.android.youtube',
              'videoTitle': 'Shorts Title', // Forbidden!
            },
          ],
        },
      };

      final updated = await updater.checkForUpdates(
        mockResponse: privacyViolatingPayload,
      );

      expect(updated, isFalse);
      expect(mockBridge.applyCallCount, equals(0));
    });
  });
}
