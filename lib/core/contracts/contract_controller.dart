import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/auth/auth_controller.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';
import 'package:scrollguard/core/contracts/contract_repository.dart';

/// State representation for contract screen and domain logic.
class ContractState {
  const ContractState({
    this.isLoading = false,
    this.contract,
    this.charges = const [],
    this.terms = ContractTerms.defaultTerms,
    this.hasAcceptedTerms = false,
    this.typedConfirmation = '',
    this.errorMessage,
    this.isFeatureFlagEnabled = true,
  });

  final bool isLoading;
  final CommitmentContract? contract;
  final List<ContractCharge> charges;
  final ContractTerms terms;
  final bool hasAcceptedTerms;
  final String typedConfirmation;
  final String? errorMessage;
  final bool isFeatureFlagEnabled;

  /// Required typed text to confirm activation of financial liability.
  static const requiredConfirmationPhrase = 'I AGREE TO CAPS';

  bool get isConfirmationValid =>
      typedConfirmation.trim().toUpperCase() == requiredConfirmationPhrase;

  bool get canActivate =>
      hasAcceptedTerms && isConfirmationValid && !isLoading;

  ContractState copyWith({
    bool? isLoading,
    CommitmentContract? contract,
    List<ContractCharge>? charges,
    ContractTerms? terms,
    bool? hasAcceptedTerms,
    String? typedConfirmation,
    String? errorMessage,
    bool? isFeatureFlagEnabled,
    bool clearError = false,
  }) {
    return ContractState(
      isLoading: isLoading ?? this.isLoading,
      contract: contract ?? this.contract,
      charges: charges ?? this.charges,
      terms: terms ?? this.terms,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      typedConfirmation: typedConfirmation ?? this.typedConfirmation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isFeatureFlagEnabled:
          isFeatureFlagEnabled ?? this.isFeatureFlagEnabled,
    );
  }
}

/// StateNotifier controlling commitment contract lifecycle and business rules.
class ContractController extends StateNotifier<ContractState> {
  ContractController(this._repository, this._ref)
      : super(const ContractState()) {
    loadContract();
  }

  final ContractRepository _repository;
  final Ref _ref;

  Future<void> loadContract() async {
    final user = _ref.read(currentUserProvider);
    if (user == null || user.isGuest) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final contract = await _repository.getContractForUser(user.id);
      var charges = const <ContractCharge>[];
      if (contract != null) {
        charges = await _repository.getCharges(contract.id);
      }
      state = state.copyWith(
        isLoading: false,
        contract: contract,
        charges: charges,
      );
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load contract: $e',
      );
    }
  }

  void setTermsAccepted({required bool accepted}) {
    state = state.copyWith(hasAcceptedTerms: accepted, clearError: true);
  }

  void setTypedConfirmation(String text) {
    state = state.copyWith(typedConfirmation: text, clearError: true);
  }

  Future<void> updateDraft({
    int? perPenaltyCents,
    int? dailyCapCents,
    int? weeklyCapCents,
    int? strikeThreshold,
    ContractDestination? destination,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || user.isGuest) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.createOrUpdateDraft(
        userId: user.id,
        perPenaltyCents: perPenaltyCents,
        dailyCapCents: dailyCapCents,
        weeklyCapCents: weeklyCapCents,
        strikeThreshold: strikeThreshold,
        destination: destination,
      );
      state = state.copyWith(isLoading: false, contract: updated);
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update draft: $e',
      );
    }
  }

  Future<bool> activateContract(String paymentMethodId) async {
    if (!state.hasAcceptedTerms) {
      state = state.copyWith(
        errorMessage: 'You must review and accept the agreement terms first.',
      );
      return false;
    }

    if (!state.isConfirmationValid) {
      state = state.copyWith(
        errorMessage:
            'Please type "${ContractState.requiredConfirmationPhrase}" to confirm caps.',
      );
      return false;
    }

    var contract = state.contract;
    final user = _ref.read(currentUserProvider);
    if (user == null || user.isGuest) {
      state = state.copyWith(
        errorMessage: 'A verified account is required for commitment contracts.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      contract ??= await _repository.createOrUpdateDraft(userId: user.id);

      final activated = await _repository.activateContract(
        contractId: contract.id,
        paymentMethodId: paymentMethodId,
        termsVersion: state.terms.version,
      );

      state = state.copyWith(
        isLoading: false,
        contract: activated,
        hasAcceptedTerms: true,
      );
      return true;
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Activation failed: $e',
      );
      return false;
    }
  }

  Future<void> requestPause() async {
    final contract = state.contract;
    if (contract == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.requestPause(contract.id);
      state = state.copyWith(isLoading: false, contract: updated);
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to pause contract: $e',
      );
    }
  }

  Future<void> resume() async {
    final contract = state.contract;
    if (contract == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.resume(contract.id);
      state = state.copyWith(isLoading: false, contract: updated);
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to resume contract: $e',
      );
    }
  }

  Future<void> requestCancel({
    Duration coolingOffDuration = const Duration(hours: 24),
  }) async {
    final contract = state.contract;
    if (contract == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _repository.requestCancel(
        contract.id,
        coolingOffDuration: coolingOffDuration,
      );
      state = state.copyWith(isLoading: false, contract: updated);
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initiate cancellation: $e',
      );
    }
  }

  Future<void> disputeCharge(String chargeId, String reason) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.disputeCharge(chargeId, reason);
      if (state.contract != null) {
        final charges = await _repository.getCharges(state.contract!.id);
        state = state.copyWith(isLoading: false, charges: charges);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on Object catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to dispute charge: $e',
      );
    }
  }
}

/// Provider for [ContractController].
final contractControllerProvider =
    StateNotifierProvider<ContractController, ContractState>((ref) {
  final repo = ref.watch(contractRepositoryProvider);
  return ContractController(repo, ref);
});

/// Convenience provider indicating if the user has an active, enforcing contract.
final isContractActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(contractControllerProvider);
  return state.contract?.isEnforcing ?? false;
});
