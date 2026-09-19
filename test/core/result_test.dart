import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/errors/app_failure.dart';
import 'package:scrollguard/core/result/result.dart';

void main() {
  group('Result and AppFailure mapping', () {
    test('Result.ok holds value and pattern matches ok', () {
      const result = Result.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.failureOrNull, isNull);

      final mapped = result.map((val) => val * 2);
      expect(mapped.dataOrNull, equals(84));

      final value = result.when(
        ok: (val) => 'value: $val',
        err: (err) => 'error: ${err.message}',
      );
      expect(value, equals('value: 42'));
    });

    test('Result.err holds failure and pattern matches err', () {
      const failure = BridgeFailure('Connection failed');
      const result = Result<int>.err(failure);

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, equals(failure));

      final mapped = result.map((val) => val * 2);
      expect(mapped.isErr, isTrue);
      expect(mapped.failureOrNull, equals(failure));

      final value = result.when(
        ok: (val) => 'value: $val',
        err: (err) => 'error: ${err.message}',
      );
      expect(value, equals('error: Connection failed'));
    });

    test('AppFailure subclasses format toString correctly', () {
      const bridgeErr = BridgeFailure('Channel disconnected');
      const storageErr = StorageFailure('Disk full');
      const authErr = AuthFailure('Token expired');
      const networkErr = NetworkFailure('500 Server Error');
      const validationErr = ValidationFailure('Invalid budget');
      const unexpectedErr = UnexpectedFailure('Null pointer');

      expect(bridgeErr.toString(), contains('BridgeFailure: Channel disconnected'));
      expect(storageErr.toString(), contains('StorageFailure: Disk full'));
      expect(authErr.toString(), contains('AuthFailure: Token expired'));
      expect(networkErr.toString(), contains('NetworkFailure: 500 Server Error'));
      expect(validationErr.toString(), contains('ValidationFailure: Invalid budget'));
      expect(unexpectedErr.toString(), contains('UnexpectedFailure: Null pointer'));
    });
  });
}
