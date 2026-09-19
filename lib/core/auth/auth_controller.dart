import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';

/// StateNotifier orchestrating authentication flows.
class AuthController extends StateNotifier<AppAuthState> {
  AuthController(this._repository)
      : super(
          _repository.currentUser != null
              ? AppAuthenticated(_repository.currentUser!)
              : const AppUnauthenticated(),
        ) {
    _repository.watchAuthState().listen((newState) {
      state = newState;
    });
  }

  final AuthRepository _repository;

  Future<void> signInWithEmail(String email, String password) async {
    state = const AppAuthLoading();
    try {
      final user = await _repository.signInWithEmail(email, password);
      state = AppAuthenticated(user);
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AppAuthLoading();
    try {
      final user = await _repository.signUpWithEmail(email, password);
      state = AppAuthenticated(user);
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AppAuthLoading();
    try {
      final user = await _repository.signInWithGoogle();
      state = AppAuthenticated(user);
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }

  Future<void> continueAsGuest() async {
    state = const AppAuthLoading();
    try {
      final user = await _repository.continueAsGuest();
      state = AppAuthenticated(user);
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }

  Future<void> signOut() async {
    state = const AppAuthLoading();
    try {
      await _repository.signOut();
      state = const AppUnauthenticated();
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }

  Future<Map<String, dynamic>> exportData() async {
    return _repository.exportData();
  }

  Future<void> deleteAccount() async {
    state = const AppAuthLoading();
    try {
      await _repository.deleteAccount();
      state = const AppUnauthenticated();
    } on Object catch (e) {
      state = AppUnauthenticated(e.toString());
    }
  }
}

/// Provider for [AuthController].
final authControllerProvider =
    StateNotifierProvider<AuthController, AppAuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

/// Convenience provider returning the currently authenticated user, if any.
final currentUserProvider = Provider<UserAccount?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return switch (authState) {
    AppAuthenticated(:final user) => user,
    _ => null,
  };
});
