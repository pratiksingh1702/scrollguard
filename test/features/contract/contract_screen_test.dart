import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';
import 'package:scrollguard/core/contracts/contract_repository.dart';
import 'package:scrollguard/core/contracts/stripe_service.dart';
import 'package:scrollguard/features/contract/contract_screen.dart';

void main() {
  Widget createTestWidget({
    UserAccount? user = const UserAccount(
      id: 'usr-1',
      email: 'verified@scrollguard.app',
    ),
    CommitmentContract? contract,
    List<ContractCharge> charges = const [],
    FakeContractRepository? contractRepo,
    FakeStripeService? stripeService,
  }) {
    final fakeAuthRepo = FakeAuthRepository(initialUser: user);
    final repo = contractRepo ?? FakeContractRepository(initialContract: contract);
    for (final ch in charges) {
      repo.addCharge(ch);
    }

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        contractRepositoryProvider.overrideWithValue(repo),
        stripeServiceProvider.overrideWithValue(
          stripeService ?? FakeStripeService(mockPmId: 'pm_card_visa_1234'),
        ),
      ],
      child: const MaterialApp(
        home: ContractScreen(),
      ),
    );
  }

  testWidgets('ContractScreen renders account required when user is guest',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        user: const UserAccount(id: 'guest_1', isGuest: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Required'), findsOneWidget);
    expect(find.text('Sign In or Register'), findsOneWidget);
  });

  testWidgets('ContractScreen renders draft setup for verified user without contract',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Voluntary Stake & Accountability'), findsOneWidget);
    expect(find.text('1. Choose Consequences & Hard Caps'), findsOneWidget);
    expect(find.text('2. Legal Agreement & 24h Cooling-Off'), findsOneWidget);
    expect(find.text('3. Type Confirmation Phrase'), findsOneWidget);
    expect(find.text('Save Card & Activate Contract'), findsOneWidget);
  });

  testWidgets('ContractScreen full activation flow with checkbox and confirmation phrase',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final activateButton = find.widgetWithText(
      FilledButton,
      'Save Card & Activate Contract',
    );

    // Button should be disabled initially
    var btnWidget = tester.widget<FilledButton>(activateButton);
    expect(btnWidget.onPressed, isNull);

    // Check terms agreement checkbox
    final checkboxFinder = find.byType(Checkbox);
    await tester.ensureVisible(checkboxFinder);
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    // Type confirmation phrase
    final textFieldFinder = find.byType(TextField);
    await tester.ensureVisible(textFieldFinder);
    await tester.enterText(textFieldFinder, 'I AGREE TO CAPS');
    await tester.pumpAndSettle();

    // Button should now be enabled
    btnWidget = tester.widget<FilledButton>(activateButton);
    expect(btnWidget.onPressed, isNotNull);

    // Tap activate
    await tester.tap(activateButton);
    await tester.pumpAndSettle();

    // Now screen should show active contract
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Per Strike Penalty'), findsOneWidget);
    expect(find.text('Daily Maximum Cap'), findsOneWidget);
    expect(find.text('Weekly Maximum Cap'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Cancel Contract'), findsOneWidget);
  });

  testWidgets('ContractScreen active contract pause and cancellation with 24h cooling-off',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final activeContract = CommitmentContract(
      id: 'c-active-1',
      userId: 'usr-1',
      status: ContractStatus.active,
      stripePmId: 'pm_card_visa',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createTestWidget(contract: activeContract));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsOneWidget);

    // Pause contract
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Resume Contract'), findsOneWidget);

    // Resume contract
    await tester.tap(find.text('Resume Contract'));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsOneWidget);

    // Cancel contract (cooling-off confirmation)
    await tester.tap(find.text('Cancel Contract'));
    await tester.pumpAndSettle();

    expect(find.text('Request Contract Cancellation?'), findsOneWidget);
    expect(find.text('Confirm Cancellation'), findsOneWidget);

    await tester.tap(find.text('Confirm Cancellation'));
    await tester.pumpAndSettle();

    expect(find.text('CANCELLED'), findsOneWidget);
    expect(find.text('COOLING-OFF (24H)'), findsNothing);
  });

  testWidgets('ContractScreen displays charge history and handles I Disagree dispute',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final activeContract = CommitmentContract(
      id: 'c-active-1',
      userId: 'usr-1',
      status: ContractStatus.active,
      createdAt: DateTime.now(),
    );

    final charges = [
      ContractCharge(
        id: 'ch-999',
        contractId: 'c-active-1',
        amountCents: 500,
        status: 'succeeded',
        createdAt: DateTime.now(),
        penaltyReason: 'Exceeded 3 strikes in Instagram Reels',
      ),
    ];

    await tester.pumpWidget(
      createTestWidget(contract: activeContract, charges: charges),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$5.00'), findsNWidgets(2));
    expect(find.text('SUCCEEDED'), findsOneWidget);
    expect(find.text('Exceeded 3 strikes in Instagram Reels'), findsOneWidget);
    expect(find.text('I Disagree'), findsOneWidget);

    // Tap I Disagree
    await tester.tap(find.text('I Disagree'));
    await tester.pumpAndSettle();

    expect(find.text('Dispute Consequence Charge'), findsOneWidget);
    expect(find.text('Submit Dispute'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, ''),
      'Was watching educational reel for school work',
    );
    await tester.tap(find.text('Submit Dispute'));
    await tester.pumpAndSettle();

    expect(find.text('Under Review: Disputed by user'), findsOneWidget);
  });
}
