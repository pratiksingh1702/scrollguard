import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/auth/auth_controller.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/features/auth/auth_screen.dart';

void main() {
  group('AuthController & FakeAuthRepository', () {
    late FakeAuthRepository repository;
    late AuthController controller;

    setUp(() {
      repository = FakeAuthRepository();
      controller = AuthController(repository);
    });

    tearDown(() {
      repository.dispose();
      controller.dispose();
    });

    test('Initial state is Unauthenticated when repository has no user', () {
      expect(controller.state, const AppUnauthenticated());
    });

    test('signInWithEmail updates state to Authenticated on valid credentials',
        () async {
      await controller.signInWithEmail('test@example.com', 'secret123');

      expect(controller.state, isA<AppAuthenticated>());
      final authed = controller.state as AppAuthenticated;
      expect(authed.user.email, 'test@example.com');
      expect(authed.user.isGuest, isFalse);
    });

    test('signInWithEmail updates state to Unauthenticated on failure', () async {
      await controller.signInWithEmail('test@example.com', 'wrong');

      expect(controller.state, isA<AppUnauthenticated>());
      final unauthed = controller.state as AppUnauthenticated;
      expect(unauthed.errorMessage, contains('Invalid credentials'));
    });

    test('signUpWithEmail creates user and updates state', () async {
      await controller.signUpWithEmail('new@example.com', 'secret123');

      expect(controller.state, isA<AppAuthenticated>());
      final authed = controller.state as AppAuthenticated;
      expect(authed.user.email, 'new@example.com');
    });

    test('continueAsGuest sets user as guest', () async {
      await controller.continueAsGuest();

      expect(controller.state, isA<AppAuthenticated>());
      final authed = controller.state as AppAuthenticated;
      expect(authed.user.isGuest, isTrue);
    });

    test('signInWithGoogle signs in Google user', () async {
      await controller.signInWithGoogle();

      expect(controller.state, isA<AppAuthenticated>());
      final authed = controller.state as AppAuthenticated;
      expect(authed.user.email, 'test@google.com');
    });

    test('signOut resets state to Unauthenticated', () async {
      await controller.signInWithEmail('test@example.com', 'secret123');
      expect(controller.state, isA<AppAuthenticated>());

      await controller.signOut();
      expect(controller.state, const AppUnauthenticated());
    });
  });

  group('AuthScreen Widget Tests', () {
    late FakeAuthRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeAuthRepository();
    });

    tearDown(() {
      fakeRepo.dispose();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: AuthScreen(),
        ),
      );
    }

    testWidgets('AuthScreen validates email and password fields',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);

      // Tap submit with empty form
      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('AuthScreen signs in with valid credentials', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('auth_email_field')),
        'valid@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth_password_field')),
        'password123',
      );

      await tester.tap(find.byKey(const Key('auth_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentUser?.email, 'valid@example.com');
    });

    testWidgets('Tapping Continue as Guest activates guest mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('auth_guest_button')));
      await tester.tap(find.byKey(const Key('auth_guest_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentUser?.isGuest, isTrue);
    });

    testWidgets('Tapping Continue with Google activates Google auth',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('auth_google_button')));
      await tester.tap(find.byKey(const Key('auth_google_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.currentUser?.email, 'test@google.com');
    });
  });
}
