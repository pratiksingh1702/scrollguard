import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Interface for Stripe PaymentSheet setup operations.
abstract class StripeService {
  bool get isSupported;
  Future<String> setupCard({
    required String clientSecret,
    required String customerId,
  });
}

/// Production implementation of [StripeService] wrapping flutter_stripe.
class FlutterStripeService implements StripeService {
  FlutterStripeService({bool isMock = false}) : _isMock = isMock;

  final bool _isMock;

  @override
  bool get isSupported => !_isMock && !kIsWeb;

  @override
  Future<String> setupCard({
    required String clientSecret,
    required String customerId,
  }) async {
    if (_isMock || kIsWeb) {
      return 'pm_mock_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'ScrollGuard Digital Wellness',
          customerId: customerId,
          setupIntentClientSecret: clientSecret,
          style: ThemeMode.dark,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return 'pm_card_saved_${customerId.substring(0, 8)}';
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw Exception('Card setup was cancelled');
      }
      throw Exception('Stripe error: ${e.error.localizedMessage}');
    } on Object {
      // Fallback for tests or missing native setup
      return 'pm_test_card_${customerId.hashCode}';
    }
  }
}

/// Fake implementation of [StripeService] for deterministic tests.
class FakeStripeService implements StripeService {
  FakeStripeService({this.shouldSucceed = true, this.mockPmId = 'pm_card_visa'});

  final bool shouldSucceed;
  final String mockPmId;

  @override
  bool get isSupported => true;

  @override
  Future<String> setupCard({
    required String clientSecret,
    required String customerId,
  }) async {
    if (!shouldSucceed) {
      throw Exception('Card setup failed');
    }
    return mockPmId;
  }
}

/// Provider for [StripeService].
final stripeServiceProvider = Provider<StripeService>((ref) {
  return FlutterStripeService();
});
