import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract defining authentication operations.
abstract class AuthRepository {
  Future<UserAccount> signInWithEmail(String email, String password);
  Future<UserAccount> signUpWithEmail(String email, String password);
  Future<UserAccount> signInWithGoogle();
  Future<UserAccount> continueAsGuest();
  Future<void> signOut();
  Future<Map<String, dynamic>> exportData();
  Future<void> deleteAccount();
  Stream<AppAuthState> watchAuthState();
  UserAccount? get currentUser;
}

/// Production implementation of [AuthRepository] using [SupabaseClient].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;
  UserAccount? _guestUser;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  UserAccount? get currentUser {
    if (_guestUser != null) return _guestUser;
    final user = client.auth.currentUser;
    if (user == null) return null;
    return UserAccount(
      id: user.id,
      email: user.email,
    );
  }

  @override
  Future<UserAccount> signInWithEmail(String email, String password) async {
    _guestUser = null;
    final res = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw Exception('Sign in failed: no user returned.');
    }
    return UserAccount(id: user.id, email: user.email);
  }

  @override
  Future<UserAccount> signUpWithEmail(String email, String password) async {
    _guestUser = null;
    final res = await client.auth.signUp(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw Exception('Sign up failed: no user returned.');
    }
    return UserAccount(id: user.id, email: user.email);
  }

  @override
  Future<UserAccount> signInWithGoogle() async {
    _guestUser = null;
    await client.auth.signInWithOAuth(OAuthProvider.google);
    final user = client.auth.currentUser;
    if (user == null) {
      return const UserAccount(id: 'google-pending');
    }
    return UserAccount(id: user.id, email: user.email);
  }

  @override
  Future<UserAccount> continueAsGuest() async {
    final guest = UserAccount(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      isGuest: true,
    );
    _guestUser = guest;
    return guest;
  }

  @override
  Future<void> signOut() async {
    _guestUser = null;
    await client.auth.signOut();
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final res = await client.functions.invoke('export-data');
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    if (res.data is String) {
      return jsonDecode(res.data as String) as Map<String, dynamic>;
    }
    return <String, dynamic>{'raw': res.data};
  }

  @override
  Future<void> deleteAccount() async {
    await client.functions.invoke('delete-account');
    await signOut();
  }

  @override
  Stream<AppAuthState> watchAuthState() {
    return client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user != null) {
        return AppAuthenticated(UserAccount(id: user.id, email: user.email));
      }
      if (_guestUser != null) {
        return AppAuthenticated(_guestUser!);
      }
      return const AppUnauthenticated();
    });
  }
}

/// Fake implementation of [AuthRepository] for tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({UserAccount? initialUser}) {
    if (initialUser != null) {
      _currentUser = initialUser;
      _controller.add(AppAuthenticated(initialUser));
    } else {
      _controller.add(const AppUnauthenticated());
    }
  }

  final _controller = StreamController<AppAuthState>.broadcast();
  UserAccount? _currentUser;

  @override
  UserAccount? get currentUser => _currentUser;

  @override
  Future<UserAccount> signInWithEmail(String email, String password) async {
    if (password == 'wrong') {
      throw Exception('Invalid credentials');
    }
    final user = UserAccount(id: 'usr_${email.hashCode}', email: email);
    _currentUser = user;
    _controller.add(AppAuthenticated(user));
    return user;
  }

  @override
  Future<UserAccount> signUpWithEmail(String email, String password) async {
    if (email.contains('taken')) {
      throw Exception('Email already registered');
    }
    final user = UserAccount(id: 'usr_${email.hashCode}', email: email);
    _currentUser = user;
    _controller.add(AppAuthenticated(user));
    return user;
  }

  @override
  Future<UserAccount> signInWithGoogle() async {
    const user = UserAccount(id: 'google-user-123', email: 'test@google.com');
    _currentUser = user;
    _controller.add(const AppAuthenticated(user));
    return user;
  }

  @override
  Future<UserAccount> continueAsGuest() async {
    const guest = UserAccount(id: 'guest-123', isGuest: true);
    _currentUser = guest;
    _controller.add(const AppAuthenticated(guest));
    return guest;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(const AppUnauthenticated());
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    return <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'user': {
        'id': _currentUser?.id ?? 'guest-123',
        'email': _currentUser?.email,
      },
      'dailyStats': <dynamic>[],
      'penaltyEvents': <dynamic>[],
      'guardEvents': <dynamic>[],
      'privacyNotice':
          'ScrollGuard stores zero screen text, video titles, or messaging content.',
    };
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
    _controller.add(const AppUnauthenticated());
  }

  @override
  Stream<AppAuthState> watchAuthState() => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

/// Provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});
