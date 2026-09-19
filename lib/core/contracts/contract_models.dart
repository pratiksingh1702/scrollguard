import 'package:flutter/foundation.dart';

/// Lifecycle status of a commitment contract.
enum ContractStatus {
  draft,
  active,
  paused,
  cancelled;

  static ContractStatus fromString(String value) {
    return switch (value.toLowerCase()) {
      'active' => ContractStatus.active,
      'paused' => ContractStatus.paused,
      'cancelled' => ContractStatus.cancelled,
      _ => ContractStatus.draft,
    };
  }
}

/// Destination of collected penalty funds.
enum ContractDestination {
  charity,
  fee;

  static ContractDestination fromString(String value) {
    return switch (value.toLowerCase()) {
      'fee' => ContractDestination.fee,
      _ => ContractDestination.charity,
    };
  }
}

/// A voluntary financial commitment contract set up by the user.
@immutable
class CommitmentContract {
  const CommitmentContract({
    required this.id,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.stripeCustomerId,
    this.stripePmId,
    this.perPenaltyCents = 500,
    this.dailyCapCents = 1500,
    this.weeklyCapCents = 3000,
    this.strikeThreshold = 3,
    this.destination = ContractDestination.charity,
    this.termsVersion = 'v1.0',
    this.acceptedAt,
    this.coolingOffUntil,
  });

  factory CommitmentContract.fromJson(Map<String, dynamic> json) {
    return CommitmentContract(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: ContractStatus.fromString(json['status'] as String? ?? 'draft'),
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripePmId: json['stripe_pm_id'] as String?,
      perPenaltyCents: (json['per_penalty_cents'] as num?)?.toInt() ?? 500,
      dailyCapCents: (json['daily_cap_cents'] as num?)?.toInt() ?? 1500,
      weeklyCapCents: (json['weekly_cap_cents'] as num?)?.toInt() ?? 3000,
      strikeThreshold: (json['strike_threshold'] as num?)?.toInt() ?? 3,
      destination: ContractDestination.fromString(
        json['destination'] as String? ?? 'charity',
      ),
      termsVersion: json['terms_version'] as String? ?? 'v1.0',
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      coolingOffUntil: json['cooling_off_until'] != null
          ? DateTime.parse(json['cooling_off_until'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final ContractStatus status;
  final String? stripeCustomerId;
  final String? stripePmId;
  final int perPenaltyCents;
  final int dailyCapCents;
  final int weeklyCapCents;
  final int strikeThreshold;
  final ContractDestination destination;
  final String termsVersion;
  final DateTime? acceptedAt;
  final DateTime? coolingOffUntil;
  final DateTime createdAt;

  /// Whether the contract is currently undergoing a cooling-off delay.
  bool get isInCoolingOff =>
      coolingOffUntil != null && coolingOffUntil!.isAfter(DateTime.now());

  /// Helper to check if contract is actively enforcing monetary penalties.
  bool get isEnforcing => status == ContractStatus.active && !isInCoolingOff;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'status': status.name,
        if (stripeCustomerId != null) 'stripe_customer_id': stripeCustomerId,
        if (stripePmId != null) 'stripe_pm_id': stripePmId,
        'per_penalty_cents': perPenaltyCents,
        'daily_cap_cents': dailyCapCents,
        'weekly_cap_cents': weeklyCapCents,
        'strike_threshold': strikeThreshold,
        'destination': destination.name,
        'terms_version': termsVersion,
        if (acceptedAt != null) 'accepted_at': acceptedAt!.toIso8601String(),
        if (coolingOffUntil != null)
          'cooling_off_until': coolingOffUntil!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  CommitmentContract copyWith({
    String? id,
    String? userId,
    ContractStatus? status,
    String? stripeCustomerId,
    String? stripePmId,
    int? perPenaltyCents,
    int? dailyCapCents,
    int? weeklyCapCents,
    int? strikeThreshold,
    ContractDestination? destination,
    String? termsVersion,
    DateTime? acceptedAt,
    DateTime? coolingOffUntil,
    DateTime? createdAt,
    bool clearCoolingOff = false,
  }) {
    return CommitmentContract(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripePmId: stripePmId ?? this.stripePmId,
      perPenaltyCents: perPenaltyCents ?? this.perPenaltyCents,
      dailyCapCents: dailyCapCents ?? this.dailyCapCents,
      weeklyCapCents: weeklyCapCents ?? this.weeklyCapCents,
      strikeThreshold: strikeThreshold ?? this.strikeThreshold,
      destination: destination ?? this.destination,
      termsVersion: termsVersion ?? this.termsVersion,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      coolingOffUntil:
          clearCoolingOff ? null : (coolingOffUntil ?? this.coolingOffUntil),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A financial consequence charge incurred from reaching a strike threshold.
@immutable
class ContractCharge {
  const ContractCharge({
    required this.id,
    required this.contractId,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.penaltyEventId,
    this.stripePaymentIntentId,
    this.failureReason,
    this.penaltyReason,
    this.isDisputed = false,
  });

  factory ContractCharge.fromJson(Map<String, dynamic> json) {
    return ContractCharge(
      id: json['id'] as String,
      contractId: json['contract_id'] as String,
      penaltyEventId: json['penalty_event_id'] as String?,
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      failureReason: json['failure_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      penaltyReason: json['penalty_reason'] as String?,
      isDisputed: json['is_disputed'] as bool? ?? false,
    );
  }

  final String id;
  final String contractId;
  final String? penaltyEventId;
  final int amountCents;
  final String? stripePaymentIntentId;
  final String status;
  final String? failureReason;
  final DateTime createdAt;
  final String? penaltyReason;
  final bool isDisputed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'contract_id': contractId,
        if (penaltyEventId != null) 'penalty_event_id': penaltyEventId,
        'amount_cents': amountCents,
        if (stripePaymentIntentId != null)
          'stripe_payment_intent_id': stripePaymentIntentId,
        'status': status,
        if (failureReason != null) 'failure_reason': failureReason,
        'created_at': createdAt.toIso8601String(),
        if (penaltyReason != null) 'penalty_reason': penaltyReason,
        'is_disputed': isDisputed,
      };

  ContractCharge copyWith({
    String? id,
    String? contractId,
    String? penaltyEventId,
    int? amountCents,
    String? stripePaymentIntentId,
    String? status,
    String? failureReason,
    DateTime? createdAt,
    String? penaltyReason,
    bool? isDisputed,
  }) {
    return ContractCharge(
      id: id ?? this.id,
      contractId: contractId ?? this.contractId,
      penaltyEventId: penaltyEventId ?? this.penaltyEventId,
      amountCents: amountCents ?? this.amountCents,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      penaltyReason: penaltyReason ?? this.penaltyReason,
      isDisputed: isDisputed ?? this.isDisputed,
    );
  }
}

/// Versioned legal agreement terms for commitment contracts.
@immutable
class ContractTerms {
  const ContractTerms({
    required this.version,
    required this.title,
    required this.summary,
    required this.fullText,
    required this.effectiveDate,
  });

  final String version;
  final String title;
  final String summary;
  final String fullText;
  final String effectiveDate;

  static const defaultTerms = ContractTerms(
    version: 'v1.0',
    title: 'ScrollGuard Voluntary Commitment Agreement',
    summary:
        'You are voluntarily creating a commitment device with financial stakes to curb compulsive short-form doomscrolling. All penalties are capped and fully transparent.',
    effectiveDate: 'September 2026',
    fullText: r'''
1. VOLUNTARY COMMITMENT DEVICE
By activating this contract, you enter into a self-binding agreement to hold yourself accountable against doomscrolling short-form video feeds (YouTube Shorts, Instagram Reels, TikTok).

2. FINANCIAL CONSEQUENCES & CAPS
- Penalties only trigger when you exceed your user-defined budget and strike threshold.
- Per-penalty charge: Default $5.00 (configured by user).
- Daily cap: Default $15.00 max in any 24-hour logical day.
- Weekly cap: Default $30.00 max in any rolling 7-day period.
- No charge will ever exceed the hard caps defined in your active contract.

3. CHARITY & FUNDS DESTINATION
All funds collected under this contract (net of payment processor processing fees) are allocated to verified non-profit partners supporting digital wellness and mental health education.

4. 24-HOUR COOLING-OFF PERIOD
To preserve the psychological power of your commitment device and prevent impulsive cancellations during a scrolling episode, modifications to reduce penalties or cancel the contract take effect after a mandatory 24-hour cooling-off period.

5. TRANSPARENCY & DISPUTE RIGHTS
Every charge is recorded with the exact timestamp, application, and strike trigger reason. If you believe a charge occurred due to a detection anomaly, you may tap "I Disagree" within 7 days to trigger an automated review and immediate refund if detection drift is detected.
''',
  );
}
