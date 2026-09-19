import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';
import 'package:scrollguard/core/sync/sync_service.dart';

void main() {
  group('SyncService & SyncController Tests', () {
    late FakeNativeBridge fakeBridge;
    late FakeAuthRepository fakeAuthRepo;
    late FakeSyncService syncService;

    setUp(() {
      fakeBridge = FakeNativeBridge();
      fakeAuthRepo = FakeAuthRepository();
      syncService = FakeSyncService(
        bridge: fakeBridge,
        authRepo: fakeAuthRepo,
      );
    });

    tearDown(() {
      fakeAuthRepo.dispose();
    });

    test('Sync does not upload when user is in guest mode', () async {
      await fakeAuthRepo.continueAsGuest();
      expect(fakeAuthRepo.currentUser?.isGuest, isTrue);

      fakeBridge.pendingSync.add(
        const PendingSyncItem(
          id: 'item-1',
          type: 'daily_stats',
          payloadJson: '{"date":"2026-09-19"}',
        ),
      );

      final result = await syncService.syncPendingData();

      expect(result.success, isTrue);
      expect(result.syncedCount, 0);
      expect(fakeBridge.markedSyncedIds, isEmpty);
    });

    test('Sync does not upload when unauthenticated', () async {
      expect(fakeAuthRepo.currentUser, isNull);

      fakeBridge.pendingSync.add(
        const PendingSyncItem(
          id: 'item-1',
          type: 'daily_stats',
          payloadJson: '{"date":"2026-09-19"}',
        ),
      );

      final result = await syncService.syncPendingData();

      expect(result.success, isTrue);
      expect(result.syncedCount, 0);
      expect(fakeBridge.markedSyncedIds, isEmpty);
    });

    test('Sync transmits pending items and marks synced on bridge for authenticated user',
        () async {
      await fakeAuthRepo.signInWithEmail('authed@example.com', 'secret123');

      fakeBridge.pendingSync.addAll([
        const PendingSyncItem(
          id: 'item-1',
          type: 'daily_stats',
          payloadJson: '{"date":"2026-09-19"}',
        ),
        const PendingSyncItem(
          id: 'item-2',
          type: 'penalty_event',
          payloadJson: '{"level":1}',
        ),
      ]);

      final result = await syncService.syncPendingData();

      expect(result.success, isTrue);
      expect(result.syncedCount, 2);
      expect(fakeBridge.markedSyncedIds, containsAll(['item-1', 'item-2']));
    });

    test('SyncController performs sync and updates state', () async {
      await fakeAuthRepo.signInWithEmail('authed@example.com', 'secret123');
      fakeBridge.pendingSync.add(
        const PendingSyncItem(
          id: 'stat-1',
          type: 'daily_stats',
          payloadJson: '{}',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(syncControllerProvider.notifier);
      final result = await controller.performSync();

      expect(result.success, isTrue);
      expect(result.syncedCount, 1);
      expect(container.read(syncControllerProvider).value?.syncedCount, 1);
    });
  });
}
