import 'package:flutter/foundation.dart';

/// Represents a user account session in ScrollGuard.
@immutable
class UserAccount {
  const UserAccount({
    required this.id,
    this.email,
    this.isGuest = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? const _DefaultDateTime();

  final String id;
  final String? email;
  final bool isGuest;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccount &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          isGuest == other.isGuest;

  @override
  int get hashCode => Object.hash(id, email, isGuest);
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// State of user authentication in ScrollGuard.
@immutable
sealed class AppAuthState {
  const AppAuthState();
}

class AppAuthInitial extends AppAuthState {
  const AppAuthInitial();
}

class AppAuthLoading extends AppAuthState {
  const AppAuthLoading();
}

class AppAuthenticated extends AppAuthState {
  const AppAuthenticated(this.user);
  final UserAccount user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppAuthenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

class AppUnauthenticated extends AppAuthState {
  const AppUnauthenticated([this.errorMessage]);
  final String? errorMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUnauthenticated &&
          runtimeType == other.runtimeType &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;
}
