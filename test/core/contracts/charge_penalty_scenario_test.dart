import 'package:flutter_test/flutter_test.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';

/// Simulated charge engine evaluating penalty events against contracts, caps, and safety rules.
class ChargePenaltyEngine {
  ChargePenaltyEngine({
    required this.contract,
    this.existingCharges = const [],
    this.recentGuardEvents = const [],
  });

  final CommitmentContract contract;
  final List<ContractCharge> existingCharges;
  final List<Map<String, dynamic>> recentGuardEvents;

  Map<String, dynamic> evaluateCharge({
    required String penaltyEventId,
    required Map<String, dynamic> penaltyEventMeta,
    required DateTime now,
  }) {
    // 1. Idempotency
    final existing = existingCharges.where((c) => c.penaltyEventId == penaltyEventId);
    if (existing.isNotEmpty) {
      return {
        'success': true,
        'skipped': false,
        'isIdempotent': true,
        'charge': existing.first,
      };
    }

    // 2. Contract active check
    if (contract.status != ContractStatus.active) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'Contract is not active',
      };
    }

    // 3. Cooling-off check
    if (contract.coolingOffUntil != null && contract.coolingOffUntil!.isAfter(now)) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'Contract is in cooling-off period',
      };
    }

    // 4. False-positive checks (P7-T5)
    if (penaltyEventMeta['rules_stale'] == true) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'False-positive protection: rules_stale flag set on event',
      };
    }

    final hasDivergence = recentGuardEvents.any((ev) =>
        ev['event_type'] == 'rules_stale' || ev['event_type'] == 'usage_divergence');
    if (hasDivergence) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'False-positive protection: recent usage divergence or detector drift',
      };
    }

    // 5. Caps calculation
    final startOfToday = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    var todayCents = 0;
    var weeklyCents = 0;

    for (final c in existingCharges) {
      if (c.status == 'succeeded' || c.status == 'pending') {
        if (c.createdAt.isAfter(startOfToday)) {
          todayCents += c.amountCents;
        }
        if (c.createdAt.isAfter(sevenDaysAgo)) {
          weeklyCents += c.amountCents;
        }
      }
    }

    var chargeAmount = contract.perPenaltyCents;

    if (todayCents >= contract.dailyCapCents) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'Daily penalty cap reached',
      };
    }
    if (todayCents + chargeAmount > contract.dailyCapCents) {
      chargeAmount = contract.dailyCapCents - todayCents;
    }

    if (weeklyCents >= contract.weeklyCapCents) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'Weekly penalty cap reached',
      };
    }
    if (weeklyCents + chargeAmount > contract.weeklyCapCents) {
      chargeAmount = contract.weeklyCapCents - weeklyCents;
    }

    if (chargeAmount <= 0) {
      return {
        'success': false,
        'skipped': true,
        'reason': 'Caps exceeded',
      };
    }

    return {
      'success': true,
      'skipped': false,
      'amountCents': chargeAmount,
      'charge': ContractCharge(
        id: 'ch_${DateTime.now().millisecondsSinceEpoch}',
        contractId: contract.id,
        penaltyEventId: penaltyEventId,
        amountCents: chargeAmount,
        status: 'succeeded',
        createdAt: now,
      ),
    };
  }
}

void main() {
  group('Charge Penalty Engine Scenarios (P7-T3, P7-T5)', () {
    final now = DateTime(2026, 9, 19, 14);

    final activeContract = CommitmentContract(
      id: 'c-1',
      userId: 'u-1',
      status: ContractStatus.active,
      createdAt: now.subtract(const Duration(days: 3)),
    );

    test('idempotency: same penalty_event_id produces identical charge and does not re-charge', () {
      final existingCharge = ContractCharge(
        id: 'ch-existing',
        contractId: 'c-1',
        penaltyEventId: 'evt-100',
        amountCents: 500,
        status: 'succeeded',
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      final engine = ChargePenaltyEngine(
        contract: activeContract,
        existingCharges: [existingCharge],
      );

      final result = engine.evaluateCharge(
        penaltyEventId: 'evt-100',
        penaltyEventMeta: {},
        now: now,
      );

      expect(result['success'], isTrue);
      expect(result['isIdempotent'], isTrue);
      expect((result['charge'] as ContractCharge).id, 'ch-existing');
    });

    test('false-positive protection: refuses charge when rules_stale flag is set', () {
      final engine = ChargePenaltyEngine(contract: activeContract);

      final result = engine.evaluateCharge(
        penaltyEventId: 'evt-101',
        penaltyEventMeta: {'rules_stale': true},
        now: now,
      );

      expect(result['success'], isFalse);
      expect(result['skipped'], isTrue);
      expect(result['reason'], contains('rules_stale'));
    });

    test('false-positive protection: refuses charge when usage divergence is present in window', () {
      final engine = ChargePenaltyEngine(
        contract: activeContract,
        recentGuardEvents: [
          {
            'event_type': 'usage_divergence',
            'created_at': now.subtract(const Duration(minutes: 15)).toIso8601String(),
          }
        ],
      );

      final result = engine.evaluateCharge(
        penaltyEventId: 'evt-102',
        penaltyEventMeta: {},
        now: now,
      );

      expect(result['success'], isFalse);
      expect(result['skipped'], isTrue);
      expect(result['reason'], contains('usage divergence'));
    });

    test('daily cap: caps partial charge and skips when full daily cap is reached', () {
      // 2 charges of $5.00 already today = $10.00 used of $15.00
      final engine = ChargePenaltyEngine(
        contract: activeContract,
        existingCharges: [
          ContractCharge(
            id: 'ch-1',
            contractId: 'c-1',
            penaltyEventId: 'evt-1',
            amountCents: 500,
            status: 'succeeded',
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
          ContractCharge(
            id: 'ch-2',
            contractId: 'c-1',
            penaltyEventId: 'evt-2',
            amountCents: 500,
            status: 'succeeded',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
      );

      // 3rd penalty of $5.00 hits exactly $15.00 daily cap
      final result1 = engine.evaluateCharge(
        penaltyEventId: 'evt-3',
        penaltyEventMeta: {},
        now: now,
      );
      expect(result1['success'], isTrue);
      expect(result1['amountCents'], 500);

      // Now with $15.00 already used today:
      final cappedEngine = ChargePenaltyEngine(
        contract: activeContract,
        existingCharges: [
          ...engine.existingCharges,
          result1['charge'] as ContractCharge,
        ],
      );

      final result2 = cappedEngine.evaluateCharge(
        penaltyEventId: 'evt-4',
        penaltyEventMeta: {},
        now: now,
      );
      expect(result2['success'], isFalse);
      expect(result2['skipped'], isTrue);
      expect(result2['reason'], contains('Daily penalty cap reached'));
    });

    test(r'weekly cap: prevents charges once $30.00 weekly limit is reached', () {
      final pastWeeklyCharges = List.generate(
        6,
        (i) => ContractCharge(
          id: 'ch-week-$i',
          contractId: 'c-1',
          penaltyEventId: 'evt-week-$i',
          amountCents: 500,
          status: 'succeeded',
          createdAt: now.subtract(Duration(days: i + 1)),
        ),
      ); // 6 * $5.00 = $30.00

      final engine = ChargePenaltyEngine(
        contract: activeContract,
        existingCharges: pastWeeklyCharges,
      );

      final result = engine.evaluateCharge(
        penaltyEventId: 'evt-new',
        penaltyEventMeta: {},
        now: now,
      );

      expect(result['success'], isFalse);
      expect(result['skipped'], isTrue);
      expect(result['reason'], contains('Weekly penalty cap reached'));
    });

    test('cooling-off: contract in cooling-off delay refuses new charges', () {
      final coolingContract = activeContract.copyWith(
        coolingOffUntil: now.add(const Duration(hours: 18)),
      );

      final engine = ChargePenaltyEngine(contract: coolingContract);

      final result = engine.evaluateCharge(
        penaltyEventId: 'evt-cool',
        penaltyEventMeta: {},
        now: now,
      );

      expect(result['success'], isFalse);
      expect(result['skipped'], isTrue);
      expect(result['reason'], contains('cooling-off'));
    });
  });
}
