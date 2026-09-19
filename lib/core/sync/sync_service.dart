import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result summary of a synchronization pass.
@immutable
class SyncResult {
  const SyncResult({
    required this.success,
    required this.syncedCount,
    this.errorMessage,
  });

  final bool success;
  final int syncedCount;
  final String? errorMessage;
}

/// Abstract contract for device-to-cloud synchronization.
abstract class SyncService {
  Future<SyncResult> syncPendingData();
  Future<int> getPendingCount();
}

/// Production implementation of [SyncService] transmitting pending local
/// records to Supabase.
class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required NativeBridge bridge,
    required AuthRepository authRepo,
    SupabaseClient? client,
  })  : _bridge = bridge,
        _authRepo = authRepo,
        _client = client;

  final NativeBridge _bridge;
  final AuthRepository _authRepo;
  final SupabaseClient? _client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  Future<SyncResult> syncPendingData() async {
    final user = _authRepo.currentUser;
    if (user == null || user.isGuest) {
      // Guest mode or unauthenticated: data stays exclusively on-device
      return const SyncResult(success: true, syncedCount: 0);
    }

    final pendingItems = await _bridge.getPendingSync();
    if (pendingItems.isEmpty) {
      return const SyncResult(success: true, syncedCount: 0);
    }

    final dailyStats = <Map<String, dynamic>>[];
    final penaltyEvents = <Map<String, dynamic>>[];
    final guardEvents = <Map<String, dynamic>>[];

    for (final item in pendingItems) {
      try {
        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        switch (item.type) {
          case 'daily_stats':
            dailyStats.add(payload);
          case 'penalty_event':
            penaltyEvents.add(payload);
          case 'guard_event':
            guardEvents.add(payload);
        }
      } on Object {
        // Skip malformed item payload
      }
    }

    try {
      final response = await client.functions.invoke(
        'sync-day',
        body: {
          'dailyStats': dailyStats,
          'penaltyEvents': penaltyEvents,
          'guardEvents': guardEvents,
        },
      );

      if (response.status != 200) {
        return SyncResult(
          success: false,
          syncedCount: 0,
          errorMessage: 'Server responded with status ${response.status}',
        );
      }

      final syncedIds = pendingItems.map((i) => i.id).toList();
      await _bridge.markSynced(syncedIds);

      return SyncResult(
        success: true,
        syncedCount: syncedIds.length,
      );
    } on Object catch (e) {
      return SyncResult(
        success: false,
        syncedCount: 0,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<int> getPendingCount() async {
    final items = await _bridge.getPendingSync();
    return items.length;
  }
}

/// Fake implementation of [SyncService] for offline/unit tests.
class FakeSyncService implements SyncService {
  FakeSyncService({
    required NativeBridge bridge,
    required AuthRepository authRepo,
  })  : _bridge = bridge,
        _authRepo = authRepo;

  final NativeBridge _bridge;
  final AuthRepository _authRepo;
  int syncCallCount = 0;

  @override
  Future<SyncResult> syncPendingData() async {
    syncCallCount++;
    final user = _authRepo.currentUser;
    if (user == null || user.isGuest) {
      return const SyncResult(success: true, syncedCount: 0);
    }

    final items = await _bridge.getPendingSync();
    final ids = items.map((i) => i.id).toList();
    await _bridge.markSynced(ids);
    return SyncResult(success: true, syncedCount: ids.length);
  }

  @override
  Future<int> getPendingCount() async {
    final items = await _bridge.getPendingSync();
    return items.length;
  }
}

/// Provider for [SyncService].
final syncServiceProvider = Provider<SyncService>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return SupabaseSyncService(bridge: bridge, authRepo: authRepo);
});

/// StateNotifier orchestrating reactive sync triggers.
class SyncController extends StateNotifier<AsyncValue<SyncResult?>> {
  SyncController(this._service) : super(const AsyncValue.data(null));

  final SyncService _service;

  Future<SyncResult> performSync() async {
    state = const AsyncValue.loading();
    final result = await _service.syncPendingData();
    state = AsyncValue.data(result);
    return result;
  }
}

/// Provider for [SyncController].
final syncControllerProvider =
    StateNotifierProvider<SyncController, AsyncValue<SyncResult?>>((ref) {
  final service = ref.watch(syncServiceProvider);
  return SyncController(service);
});
