import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/auth/auth_models.dart';
import 'package:scrollguard/core/auth/auth_repository.dart';
import 'package:scrollguard/core/contracts/contract_controller.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';
import 'package:scrollguard/core/contracts/contract_repository.dart';

void main() {
  group('CommitmentContract Models & Serialization', () {
    test('serializes and deserializes CommitmentContract correctly', () {
      final now = DateTime.utc(2026, 9, 19, 12);
      final contract = CommitmentContract(
        id: 'c-123',
        userId: 'u-456',
        status: ContractStatus.active,
        stripeCustomerId: 'cus_123',
        stripePmId: 'pm_456',
        perPenaltyCents: 1000,
        dailyCapCents: 2500,
        weeklyCapCents: 5000,
        strikeThreshold: 4,
        destination: ContractDestination.fee,
        acceptedAt: now,
        coolingOffUntil: now.add(const Duration(hours: 24)),
        createdAt: now,
      );

      final json = contract.toJson();
      final deserialized = CommitmentContract.fromJson(json);

      expect(deserialized.id, 'c-123');
      expect(deserialized.userId, 'u-456');
      expect(deserialized.status, ContractStatus.active);
      expect(deserialized.stripeCustomerId, 'cus_123');
      expect(deserialized.stripePmId, 'pm_456');
      expect(deserialized.perPenaltyCents, 1000);
      expect(deserialized.dailyCapCents, 2500);
      expect(deserialized.weeklyCapCents, 5000);
      expect(deserialized.strikeThreshold, 4);
      expect(deserialized.destination, ContractDestination.fee);
      expect(deserialized.termsVersion, 'v1.0');
      expect(deserialized.acceptedAt, now);
      expect(deserialized.coolingOffUntil, now.add(const Duration(hours: 24)));
    });

    test('cooling-off and enforcement status logic', () {
      final now = DateTime.now();
      final activeNoCooling = CommitmentContract(
        id: 'c-1',
        userId: 'u-1',
        status: ContractStatus.active,
        createdAt: now,
      );
      expect(activeNoCooling.isInCoolingOff, isFalse);
      expect(activeNoCooling.isEnforcing, isTrue);

      final activeInCooling = CommitmentContract(
        id: 'c-2',
        userId: 'u-1',
        status: ContractStatus.active,
        coolingOffUntil: now.add(const Duration(hours: 12)),
        createdAt: now,
      );
      expect(activeInCooling.isInCoolingOff, isTrue);
      expect(activeInCooling.isEnforcing, isFalse);

      final draftContract = CommitmentContract(
        id: 'c-3',
        userId: 'u-1',
        status: ContractStatus.draft,
        createdAt: now,
      );
      expect(draftContract.isEnforcing, isFalse);
    });

    test('serializes and deserializes ContractCharge', () {
      final now = DateTime.utc(2026, 9, 19, 12, 30);
      final charge = ContractCharge(
        id: 'ch-1',
        contractId: 'c-1',
        penaltyEventId: 'pe-1',
        amountCents: 500,
        stripePaymentIntentId: 'pi_test',
        status: 'succeeded',
        createdAt: now,
        penaltyReason: 'Budget exceeded in YouTube Shorts',
      );

      final json = charge.toJson();
      final deserialized = ContractCharge.fromJson(json);

      expect(deserialized.id, 'ch-1');
      expect(deserialized.contractId, 'c-1');
      expect(deserialized.amountCents, 500);
      expect(deserialized.penaltyReason, 'Budget exceeded in YouTube Shorts');
      expect(deserialized.status, 'succeeded');
      expect(deserialized.isDisputed, isFalse);
    });
  });

  group('ContractController State Machine', () {
    late FakeAuthRepository authRepo;
    late FakeContractRepository contractRepo;
    late ProviderContainer container;

    setUp(() {
      authRepo = FakeAuthRepository(
        initialUser: const UserAccount(
          id: 'user-777',
          email: 'test@scrollguard.app',
        ),
      );
      contractRepo = FakeContractRepository();

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          contractRepositoryProvider.overrideWithValue(contractRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      contractRepo.dispose();
      authRepo.dispose();
    });

    test('activation requires terms acceptance and typed confirmation', () async {
      final controller = container.read(contractControllerProvider.notifier);

      // 1. Without terms acceptance
      var success = await controller.activateContract('pm_card_visa');
      expect(success, isFalse);
      expect(
        container.read(contractControllerProvider).errorMessage,
        contains('accept the agreement terms first'),
      );

      // 2. Accept terms, but wrong confirmation phrase
      controller
        ..setTermsAccepted(accepted: true)
        ..setTypedConfirmation('YES I AGREE');
      success = await controller.activateContract('pm_card_visa');
      expect(success, isFalse);
      expect(
        container.read(contractControllerProvider).errorMessage,
        contains('I AGREE TO CAPS'),
      );

      // 3. Exact confirmation phrase typed (case-insensitive)
      controller.setTypedConfirmation('i agree to caps');
      success = await controller.activateContract('pm_card_visa');
      expect(success, isTrue);

      final state = container.read(contractControllerProvider);
      expect(state.contract?.status, ContractStatus.active);
      expect(state.contract?.stripePmId, 'pm_card_visa');
      expect(container.read(isContractActiveProvider), isTrue);
    });

    test('state transitions: active -> paused -> active', () async {
      final controller = container.read(contractControllerProvider.notifier)
        ..setTermsAccepted(accepted: true)
        ..setTypedConfirmation('I AGREE TO CAPS');
      await controller.activateContract('pm_card_visa');

      expect(container.read(contractControllerProvider).contract?.status,
          ContractStatus.active);

      // Pause
      await controller.requestPause();
      expect(container.read(contractControllerProvider).contract?.status,
          ContractStatus.paused);
      expect(container.read(isContractActiveProvider), isFalse);

      // Resume
      await controller.resume();
      expect(container.read(contractControllerProvider).contract?.status,
          ContractStatus.active);
      expect(container.read(isContractActiveProvider), isTrue);
    });

    test('cancellation sets cooling-off period', () async {
      final controller = container.read(contractControllerProvider.notifier)
        ..setTermsAccepted(accepted: true)
        ..setTypedConfirmation('I AGREE TO CAPS');
      await controller.activateContract('pm_card_visa');

      // Request cancellation with 24-hour cooling off
      await controller.requestCancel();

      final contract = container.read(contractControllerProvider).contract;
      expect(contract?.status, ContractStatus.cancelled);
      expect(contract?.isInCoolingOff, isTrue);
      expect(contract?.coolingOffUntil, isNotNull);
      expect(contract?.isEnforcing, isFalse);
    });

    test('disputeCharge updates charge status and failureReason', () async {
      final controller = container.read(contractControllerProvider.notifier)
        ..setTermsAccepted(accepted: true)
        ..setTypedConfirmation('I AGREE TO CAPS');
      await controller.activateContract('pm_card_visa');

      contractRepo.addCharge(
        ContractCharge(
          id: 'ch-test-1',
          contractId: contractRepo.getContractForUser('user-777').then((c) => c!.id).toString(),
          amountCents: 500,
          status: 'succeeded',
          createdAt: DateTime.now(),
        ),
      );

      await controller.disputeCharge('ch-test-1', 'False detection while playing normal video');

      final charges = await contractRepo.getCharges('any');
      expect(charges.first.isDisputed, isTrue);
      expect(charges.first.failureReason, contains('False detection'));
    });
  });
}
