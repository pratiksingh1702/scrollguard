import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';

abstract class SessionRepository {
  Future<List<SessionRecord>> getSessions(int fromEpochMs, int toEpochMs);
  Future<void> deleteSessionsBefore(int epochMs);
}

class BridgeSessionRepository implements SessionRepository {
  BridgeSessionRepository(this._bridge);

  final NativeBridge _bridge;

  @override
  Future<List<SessionRecord>> getSessions(
    int fromEpochMs,
    int toEpochMs,
  ) {
    return _bridge.getSessions(fromEpochMs, toEpochMs);
  }

  @override
  Future<void> deleteSessionsBefore(int epochMs) async {
    // Data retention clean-up hook
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return BridgeSessionRepository(bridge);
});
