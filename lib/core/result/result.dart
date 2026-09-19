import 'package:flutter/foundation.dart';
import 'package:scrollguard/core/errors/app_failure.dart';

/// Sealed class representing the result of an operation that can succeed or fail.
@immutable
sealed class Result<T> {
  const Result();

  /// Create a successful result containing [data].
  const factory Result.ok(T data) = Success<T>;

  /// Create a failed result containing [failure].
  const factory Result.err(AppFailure failure) = Failure<T>;

  /// Whether this result is a success.
  bool get isOk => this is Success<T>;

  /// Whether this result is a failure.
  bool get isErr => this is Failure<T>;

  /// Returns data if successful, null otherwise.
  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  /// Returns failure if failed, null otherwise.
  AppFailure? get failureOrNull => switch (this) {
        Success() => null,
        Failure(:final failure) => failure,
      };

  /// Pattern match over the result.
  R when<R>({
    required R Function(T data) ok,
    required R Function(AppFailure failure) err,
  }) =>
      switch (this) {
        Success(:final data) => ok(data),
        Failure(:final failure) => err(failure),
      };

  /// Map data if successful.
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success(:final data) => Result.ok(transform(data)),
        Failure(:final failure) => Result.err(failure),
      };
}

/// A successful result.
@immutable
final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Result.ok($data)';
}

/// A failed result.
@immutable
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Result.err($failure)';
}
