import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract defining persistence and lifecycle operations for commitment contracts.
abstract class ContractRepository {
  Future<CommitmentContract?> getContractForUser(String userId);
  Future<CommitmentContract> createOrUpdateDraft({
    required String userId,
    int? perPenaltyCents,
    int? dailyCapCents,
    int? weeklyCapCents,
    int? strikeThreshold,
    ContractDestination? destination,
  });
  Future<Map<String, dynamic>> createSetupIntent();
  Future<CommitmentContract> activateContract({
    required String contractId,
    required String paymentMethodId,
    required String termsVersion,
  });
  Future<CommitmentContract> requestPause(String contractId);
  Future<CommitmentContract> resume(String contractId);
  Future<CommitmentContract> requestCancel(
    String contractId, {
    Duration coolingOffDuration = const Duration(hours: 24),
  });
  Future<List<ContractCharge>> getCharges(String contractId);
  Future<void> disputeCharge(String chargeId, String reason);
  Stream<CommitmentContract?> watchContract(String userId);
}

/// Production implementation of [ContractRepository] backed by Supabase & Edge Functions.
class SupabaseContractRepository implements ContractRepository {
  SupabaseContractRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  Future<CommitmentContract?> getContractForUser(String userId) async {
    final res = await client
        .from('contracts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return CommitmentContract.fromJson(res);
  }

  @override
  Future<CommitmentContract> createOrUpdateDraft({
    required String userId,
    int? perPenaltyCents,
    int? dailyCapCents,
    int? weeklyCapCents,
    int? strikeThreshold,
    ContractDestination? destination,
  }) async {
    final existing = await getContractForUser(userId);
    if (existing != null && existing.status == ContractStatus.draft) {
      final updated = await client
          .from('contracts')
          .update({
            if (perPenaltyCents != null) 'per_penalty_cents': perPenaltyCents,
            if (dailyCapCents != null) 'daily_cap_cents': dailyCapCents,
            if (weeklyCapCents != null) 'weekly_cap_cents': weeklyCapCents,
            if (strikeThreshold != null) 'strike_threshold': strikeThreshold,
            if (destination != null) 'destination': destination.name,
          })
          .eq('id', existing.id)
          .select()
          .single();
      return CommitmentContract.fromJson(updated);
    }

    final inserted = await client
        .from('contracts')
        .insert({
          'user_id': userId,
          'status': 'draft',
          'per_penalty_cents': perPenaltyCents ?? 500,
          'daily_cap_cents': dailyCapCents ?? 1500,
          'weekly_cap_cents': weeklyCapCents ?? 3000,
          'strike_threshold': strikeThreshold ?? 3,
          'destination': (destination ?? ContractDestination.charity).name,
          'terms_version': ContractTerms.defaultTerms.version,
        })
        .select()
        .single();

    return CommitmentContract.fromJson(inserted);
  }

  @override
  Future<Map<String, dynamic>> createSetupIntent() async {
    final res = await client.functions.invoke('create-setup-intent');
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return <String, dynamic>{'client_secret': res.data.toString()};
  }

  @override
  Future<CommitmentContract> activateContract({
    required String contractId,
    required String paymentMethodId,
    required String termsVersion,
  }) async {
    final res = await client.functions.invoke(
      'activate-contract',
      body: {
        'contract_id': contractId,
        'payment_method_id': paymentMethodId,
        'terms_version': termsVersion,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) {
      final contractObj = data['contract'];
      if (contractObj is Map<String, dynamic>) {
        return CommitmentContract.fromJson(contractObj);
      }
    }

    final updated = await client
        .from('contracts')
        .update({
          'status': 'active',
          'stripe_pm_id': paymentMethodId,
          'terms_version': termsVersion,
          'accepted_at': DateTime.now().toIso8601String(),
          'cooling_off_until': null,
        })
        .eq('id', contractId)
        .select()
        .single();

    return CommitmentContract.fromJson(updated);
  }

  @override
  Future<CommitmentContract> requestPause(String contractId) async {
    final updated = await client
        .from('contracts')
        .update({
          'status': 'paused',
        })
        .eq('id', contractId)
        .select()
        .single();

    return CommitmentContract.fromJson(updated);
  }

  @override
  Future<CommitmentContract> resume(String contractId) async {
    final updated = await client
        .from('contracts')
        .update({
          'status': 'active',
          'cooling_off_until': null,
        })
        .eq('id', contractId)
        .select()
        .single();

    return CommitmentContract.fromJson(updated);
  }

  @override
  Future<CommitmentContract> requestCancel(
    String contractId, {
    Duration coolingOffDuration = const Duration(hours: 24),
  }) async {
    final coolingOffUntil = DateTime.now().add(coolingOffDuration);
    final updated = await client
        .from('contracts')
        .update({
          'cooling_off_until': coolingOffUntil.toIso8601String(),
          'status': 'cancelled',
        })
        .eq('id', contractId)
        .select()
        .single();

    return CommitmentContract.fromJson(updated);
  }

  @override
  Future<List<ContractCharge>> getCharges(String contractId) async {
    final res = await client
        .from('charges')
        .select('*, penalty_events(reason)')
        .eq('contract_id', contractId)
        .order('created_at', ascending: false);

    return res.map((item) {
      final map = Map<String, dynamic>.from(item);
      final penaltyEvents = map['penalty_events'];
      if (penaltyEvents is Map) {
        map['penalty_reason'] = penaltyEvents['reason'] as String?;
      }
      return ContractCharge.fromJson(map);
    }).toList();
  }

  @override
  Future<void> disputeCharge(String chargeId, String reason) async {
    await client
        .from('charges')
        .update({'failure_reason': 'Disputed by user: $reason'})
        .eq('id', chargeId);
  }

  @override
  Stream<CommitmentContract?> watchContract(String userId) {
    return client
        .from('contracts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return CommitmentContract.fromJson(rows.first);
        });
  }
}

/// Fake in-memory implementation of [ContractRepository] for tests.
class FakeContractRepository implements ContractRepository {
  FakeContractRepository({CommitmentContract? initialContract})
      : _contract = initialContract;

  CommitmentContract? _contract;
  final List<ContractCharge> _charges = [];
  final _streamController = StreamController<CommitmentContract?>.broadcast();

  @override
  Future<CommitmentContract?> getContractForUser(String userId) async {
    return _contract;
  }

  @override
  Future<CommitmentContract> createOrUpdateDraft({
    required String userId,
    int? perPenaltyCents,
    int? dailyCapCents,
    int? weeklyCapCents,
    int? strikeThreshold,
    ContractDestination? destination,
  }) async {
    if (_contract != null && _contract!.status == ContractStatus.draft) {
      _contract = _contract!.copyWith(
        perPenaltyCents: perPenaltyCents,
        dailyCapCents: dailyCapCents,
        weeklyCapCents: weeklyCapCents,
        strikeThreshold: strikeThreshold,
        destination: destination,
      );
    } else {
      _contract = CommitmentContract(
        id: 'draft_contract_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        status: ContractStatus.draft,
        perPenaltyCents: perPenaltyCents ?? 500,
        dailyCapCents: dailyCapCents ?? 1500,
        weeklyCapCents: weeklyCapCents ?? 3000,
        strikeThreshold: strikeThreshold ?? 3,
        destination: destination ?? ContractDestination.charity,
        createdAt: DateTime.now(),
      );
    }
    _streamController.add(_contract);
    return _contract!;
  }

  @override
  Future<Map<String, dynamic>> createSetupIntent() async {
    return <String, dynamic>{
      'client_secret': 'seti_test_secret_12345',
      'customer_id': 'cus_test_12345',
    };
  }

  @override
  Future<CommitmentContract> activateContract({
    required String contractId,
    required String paymentMethodId,
    required String termsVersion,
  }) async {
    final existing = _contract ??
        CommitmentContract(
          id: contractId,
          userId: 'user-1',
          status: ContractStatus.draft,
          createdAt: DateTime.now(),
        );

    _contract = existing.copyWith(
      status: ContractStatus.active,
      stripePmId: paymentMethodId,
      termsVersion: termsVersion,
      acceptedAt: DateTime.now(),
      clearCoolingOff: true,
    );
    _streamController.add(_contract);
    return _contract!;
  }

  @override
  Future<CommitmentContract> requestPause(String contractId) async {
    if (_contract != null) {
      _contract = _contract!.copyWith(status: ContractStatus.paused);
      _streamController.add(_contract);
    }
    return _contract!;
  }

  @override
  Future<CommitmentContract> resume(String contractId) async {
    if (_contract != null) {
      _contract = _contract!.copyWith(
        status: ContractStatus.active,
        clearCoolingOff: true,
      );
      _streamController.add(_contract);
    }
    return _contract!;
  }

  @override
  Future<CommitmentContract> requestCancel(
    String contractId, {
    Duration coolingOffDuration = const Duration(hours: 24),
  }) async {
    if (_contract != null) {
      final coolingOffUntil = DateTime.now().add(coolingOffDuration);
      _contract = _contract!.copyWith(
        status: ContractStatus.cancelled,
        coolingOffUntil: coolingOffUntil,
      );
      _streamController.add(_contract);
    }
    return _contract!;
  }

  @override
  Future<List<ContractCharge>> getCharges(String contractId) async {
    return List.unmodifiable(_charges);
  }

  void addCharge(ContractCharge charge) {
    _charges.add(charge);
  }

  @override
  Future<void> disputeCharge(String chargeId, String reason) async {
    final idx = _charges.indexWhere((c) => c.id == chargeId);
    if (idx != -1) {
      _charges[idx] = _charges[idx].copyWith(
        isDisputed: true,
        failureReason: 'Disputed: $reason',
      );
    }
  }

  @override
  Stream<CommitmentContract?> watchContract(String userId) =>
      _streamController.stream;

  void dispose() {
    _streamController.close();
  }
}

/// Provider for [ContractRepository].
final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return SupabaseContractRepository();
});
