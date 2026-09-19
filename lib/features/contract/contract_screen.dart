import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scrollguard/core/auth/auth_controller.dart';
import 'package:scrollguard/core/contracts/contract_controller.dart';
import 'package:scrollguard/core/contracts/contract_models.dart';
import 'package:scrollguard/core/contracts/contract_repository.dart';
import 'package:scrollguard/core/contracts/stripe_service.dart';

/// Screen managing voluntary financial commitment contracts,
/// Stripe card binding, caps enforcement, and charge dispute history.
class ContractScreen extends ConsumerStatefulWidget {
  const ContractScreen({super.key});

  @override
  ConsumerState<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends ConsumerState<ContractScreen> {
  final _confirmationController = TextEditingController();
  bool _isTermsExpanded = false;

  int _selectedPerPenalty = 500;
  int _selectedDailyCap = 1500;
  int _selectedWeeklyCap = 3000;
  ContractDestination _selectedDestination = ContractDestination.charity;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contractState = ref.watch(contractControllerProvider);
    final user = ref.watch(currentUserProvider);

    // 1. Require registered account
    if (user == null || user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commitment Contract')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  'Account Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Financial commitment contracts require a registered account to link payment methods and enforce liability caps.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    try {
                      context.push('/auth');
                    } on Object {
                      // Standalone widget tests without GoRouter mount
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In or Register'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final contract = contractState.contract;
    final isDraft = contract == null || contract.status == ContractStatus.draft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitment Contract'),
      ),
      body: SafeArea(
        child: contractState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (contractState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contractState.errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isDraft)
                    _buildDraftSetup(context, theme, contractState)
                  else
                    _buildActiveContractView(
                      context,
                      theme,
                      contractState,
                      contract,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildDraftSetup(
    BuildContext context,
    ThemeData theme,
    ContractState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          theme,
          title: 'Voluntary Stake & Accountability',
          subtitle:
              'Set real financial stakes to break compulsive short-video habits. You control strict daily and weekly caps, and penalties are donated to verified digital wellness charities.',
          icon: Icons.shield_outlined,
          color: Colors.blue,
        ),
        const SizedBox(height: 20),
        Text(
          '1. Choose Consequences & Hard Caps',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildPerPenaltySelector(theme),
        const SizedBox(height: 12),
        _buildDailyCapSelector(theme),
        const SizedBox(height: 12),
        _buildWeeklyCapSelector(theme),
        const SizedBox(height: 12),
        _buildDestinationSelector(theme),
        const SizedBox(height: 24),
        Text(
          '2. Legal Agreement & 24h Cooling-Off',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildTermsCard(theme, state.terms),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: state.hasAcceptedTerms,
          onChanged: (val) {
            ref
                .read(contractControllerProvider.notifier)
                .setTermsAccepted(accepted: val ?? false);
          },
          title: const Text(
            'I have read and agree to the ScrollGuard Voluntary Commitment Agreement terms and 24-hour cooling-off policy.',
            style: TextStyle(fontSize: 13),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        Text(
          '3. Type Confirmation Phrase',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Type "I AGREE TO CAPS" to activate financial consequences:',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmationController,
          decoration: const InputDecoration(
            hintText: 'I AGREE TO CAPS',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
            ref
                .read(contractControllerProvider.notifier)
                .setTypedConfirmation(val);
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: state.canActivate
                ? () => _handleCardSetupAndActivate(context)
                : null,
            icon: const Icon(Icons.credit_card),
            label: const Text(
              'Save Card & Activate Contract',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveContractView(
    BuildContext context,
    ThemeData theme,
    ContractState state,
    CommitmentContract contract,
  ) {
    final isPaused = contract.status == ContractStatus.paused;
    final isCancelled = contract.status == ContractStatus.cancelled;
    final inCoolingOff = contract.isInCoolingOff;

    final badgeColor = isCancelled
        ? Colors.grey
        : isPaused
            ? Colors.orange
            : Colors.green;

    final badgeText = isCancelled
        ? 'CANCELLED'
        : isPaused
            ? 'PAUSED'
            : (inCoolingOff ? 'COOLING-OFF (24H)' : 'ACTIVE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: badgeColor.withAlpha(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: badgeColor.withAlpha(100)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield, color: badgeColor),
                    const SizedBox(width: 8),
                    Text(
                      'Commitment Status',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCapRow(
                  'Per Strike Penalty',
                  '\$${(contract.perPenaltyCents / 100).toStringAsFixed(2)}',
                  theme,
                ),
                const Divider(height: 12),
                _buildCapRow(
                  'Daily Maximum Cap',
                  '\$${(contract.dailyCapCents / 100).toStringAsFixed(2)}',
                  theme,
                ),
                const Divider(height: 12),
                _buildCapRow(
                  'Weekly Maximum Cap',
                  '\$${(contract.weeklyCapCents / 100).toStringAsFixed(2)}',
                  theme,
                ),
                const Divider(height: 12),
                _buildCapRow(
                  'Funds Destination',
                  contract.destination == ContractDestination.charity
                      ? 'Verified Digital Wellness Non-Profit'
                      : 'Platform Fee',
                  theme,
                ),
                if (contract.stripePmId != null) ...[
                  const Divider(height: 12),
                  _buildCapRow(
                    'Saved Payment Method',
                    'Card (${contract.stripePmId!.substring(0, contract.stripePmId!.length.clamp(0, 12))}...)',
                    theme,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (inCoolingOff) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cooling-off in effect until ${DateFormat('MMM d, h:mm a').format(contract.coolingOffUntil!)}. Existing limits remain active until the period expires.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (isPaused)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      ref.read(contractControllerProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume Contract'),
                ),
              )
            else if (!isCancelled) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(contractControllerProvider.notifier)
                      .requestPause(),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancelContract(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Contract'),
                ),
              ),
            ] else ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ref
                        .read(contractControllerProvider.notifier)
                        .setTermsAccepted(accepted: false);
                    ref
                        .read(contractControllerProvider.notifier)
                        .setTypedConfirmation('');
                    ref
                        .read(contractControllerProvider.notifier)
                        .updateDraft();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Contract'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Charge & Accountability History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Every consequence charge is linked to the exact detection event. You may dispute any charge with one tap.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (state.charges.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No consequence charges recorded. Keep your streak going!',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...state.charges.map((ch) => _buildChargeTile(context, theme, ch)),
      ],
    );
  }

  Widget _buildChargeTile(
    BuildContext context,
    ThemeData theme,
    ContractCharge charge,
  ) {
    final dateStr = DateFormat('MMM d, h:mm a').format(charge.createdAt);
    final amountStr = '\$${(charge.amountCents / 100).toStringAsFixed(2)}';

    final isSuccess = charge.status == 'succeeded';
    final statusColor = isSuccess ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  amountStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    charge.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text(dateStr, style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              charge.penaltyReason ?? 'Exceeded strike doomscroll limit',
              style: theme.textTheme.bodySmall,
            ),
            if (charge.isDisputed) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Under Review: Disputed by user',
                  style: TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ),
            ] else if (isSuccess) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _showDisputeDialog(context, charge.id),
                  icon: const Icon(Icons.flag_outlined, size: 14),
                  label: const Text('I Disagree', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, String chargeId) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispute Consequence Charge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If this penalty occurred during educational, work, or non-feed app usage, report it here. False positives flagged with detection anomalies or stale rules are automatically refunded.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Describe the false detection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.of(ctx).pop();
              ref.read(contractControllerProvider.notifier).disputeCharge(
                    chargeId,
                    reason.isNotEmpty ? reason : 'Unspecified false positive',
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dispute submitted. Reviewing detection logs.'),
                ),
              );
            },
            child: const Text('Submit Dispute'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelContract(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Contract Cancellation?'),
        content: const Text(
          'To preserve the psychological integrity of your commitment device, cancellation requires a mandatory 24-hour cooling-off period. During these 24 hours, existing consequences remain in effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(contractControllerProvider.notifier).requestCancel();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cancellation initiated with 24-hour cooling-off.'),
                ),
              );
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCardSetupAndActivate(BuildContext context) async {
    try {
      final repo = ref.read(contractRepositoryProvider);
      final setupRes = await repo.createSetupIntent();
      final clientSecret = setupRes['client_secret'] as String? ?? '';
      final customerId = setupRes['customer_id'] as String? ?? 'cus_1';

      final stripeService = ref.read(stripeServiceProvider);
      final pmId = await stripeService.setupCard(
        clientSecret: clientSecret,
        customerId: customerId,
      );

      final success = await ref
          .read(contractControllerProvider.notifier)
          .activateContract(pmId);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commitment contract activated!')),
        );
      }
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activation error: $e')),
      );
    }
  }

  Widget _buildCapRow(String title, String val, ThemeData theme) {
    return Row(
      children: [
        Text(title, style: theme.textTheme.bodySmall),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerPenaltySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Per-Strike Consequence', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 200, label: Text(r'$2.00')),
            ButtonSegment(value: 500, label: Text(r'$5.00')),
            ButtonSegment(value: 1000, label: Text(r'$10.00')),
            ButtonSegment(value: 2000, label: Text(r'$20.00')),
          ],
          selected: {_selectedPerPenalty},
          onSelectionChanged: (set) {
            setState(() => _selectedPerPenalty = set.first);
            ref.read(contractControllerProvider.notifier).updateDraft(
                  perPenaltyCents: _selectedPerPenalty,
                );
          },
        ),
      ],
    );
  }

  Widget _buildDailyCapSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily Maximum Cap', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1000, label: Text(r'$10.00')),
            ButtonSegment(value: 1500, label: Text(r'$15.00')),
            ButtonSegment(value: 3000, label: Text(r'$30.00')),
            ButtonSegment(value: 5000, label: Text(r'$50.00')),
          ],
          selected: {_selectedDailyCap},
          onSelectionChanged: (set) {
            setState(() => _selectedDailyCap = set.first);
            ref.read(contractControllerProvider.notifier).updateDraft(
                  dailyCapCents: _selectedDailyCap,
                );
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyCapSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weekly Maximum Cap', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2500, label: Text(r'$25.00')),
            ButtonSegment(value: 3000, label: Text(r'$30.00')),
            ButtonSegment(value: 5000, label: Text(r'$50.00')),
            ButtonSegment(value: 10000, label: Text(r'$100.00')),
          ],
          selected: {_selectedWeeklyCap},
          onSelectionChanged: (set) {
            setState(() => _selectedWeeklyCap = set.first);
            ref.read(contractControllerProvider.notifier).updateDraft(
                  weeklyCapCents: _selectedWeeklyCap,
                );
          },
        ),
      ],
    );
  }

  Widget _buildDestinationSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Funds Destination', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        SegmentedButton<ContractDestination>(
          segments: const [
            ButtonSegment(
              value: ContractDestination.charity,
              label: Text('Charity Donation'),
              icon: Icon(Icons.volunteer_activism_outlined),
            ),
            ButtonSegment(
              value: ContractDestination.fee,
              label: Text('Service Stake'),
              icon: Icon(Icons.savings_outlined),
            ),
          ],
          selected: {_selectedDestination},
          onSelectionChanged: (set) {
            setState(() => _selectedDestination = set.first);
            ref.read(contractControllerProvider.notifier).updateDraft(
                  destination: _selectedDestination,
                );
          },
        ),
      ],
    );
  }

  Widget _buildTermsCard(ThemeData theme, ContractTerms terms) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    terms.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  terms.version,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(terms.summary, style: theme.textTheme.bodySmall),
            if (_isTermsExpanded) ...[
              const Divider(height: 16),
              Text(
                terms.fullText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                setState(() => _isTermsExpanded = !_isTermsExpanded);
              },
              child: Text(
                _isTermsExpanded ? 'Collapse Full Terms' : 'View Full Terms (5 Clauses)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
