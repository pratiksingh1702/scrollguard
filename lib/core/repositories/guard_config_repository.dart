import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/bridge/native_bridge.dart';
import 'package:scrollguard/core/models/guard_models.dart';

abstract class GuardConfigRepository {
  Future<GuardConfig> getConfig();
  Future<void> saveConfig(GuardConfig config);
}

class BridgeGuardConfigRepository implements GuardConfigRepository {
  BridgeGuardConfigRepository(this._bridge, [GuardConfig? initialConfig])
      : _cachedConfig = initialConfig ?? const GuardConfig();

  final NativeBridge _bridge;
  GuardConfig _cachedConfig;

  @override
  Future<GuardConfig> getConfig() async {
    return _cachedConfig;
  }

  @override
  Future<void> saveConfig(GuardConfig config) async {
    _cachedConfig = config;
    await _bridge.applyConfig(config);
  }
}

final guardConfigRepositoryProvider = Provider<GuardConfigRepository>((ref) {
  final bridge = ref.watch(nativeBridgeProvider);
  return BridgeGuardConfigRepository(bridge);
});
