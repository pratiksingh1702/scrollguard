-- Supabase pgTAP / SQL verification test for contracts and charges schema & constraints
BEGIN;

-- Test 1: Insert test user
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000005', 'contract_test@scrollguard.app')
ON CONFLICT (id) DO NOTHING;

-- Test 2: Create draft contract
INSERT INTO public.contracts (
    id,
    user_id,
    status,
    per_penalty_cents,
    daily_cap_cents,
    weekly_cap_cents,
    strike_threshold,
    destination,
    terms_version
) VALUES (
    '00000000-0000-0000-0000-0000000000c1',
    '00000000-0000-0000-0000-000000000005',
    'draft',
    500,
    1500,
    3000,
    3,
    'charity',
    'v1.0'
);

-- Test 3: Verify contract row
DO $$
DECLARE
    v_status TEXT;
    v_per_penalty INT;
BEGIN
    SELECT status, per_penalty_cents INTO v_status, v_per_penalty
    FROM public.contracts
    WHERE id = '00000000-0000-0000-0000-0000000000c1';

    ASSERT v_status = 'draft', 'Expected draft status';
    ASSERT v_per_penalty = 500, 'Expected 500 cents per penalty';
END $$;

-- Test 4: Activate contract
UPDATE public.contracts
SET status = 'active',
    stripe_pm_id = 'pm_card_test_123',
    accepted_at = NOW()
WHERE id = '00000000-0000-0000-0000-0000000000c1';

-- Test 5: Insert charge
INSERT INTO public.charges (
    id,
    contract_id,
    amount_cents,
    stripe_payment_intent_id,
    status
) VALUES (
    '00000000-0000-0000-0000-0000000000d1',
    '00000000-0000-0000-0000-0000000000c1',
    500,
    'pi_test_999',
    'succeeded'
);

-- Test 6: Verify charge exists
DO $$
DECLARE
    v_charge_amt INT;
    v_charge_status TEXT;
BEGIN
    SELECT amount_cents, status INTO v_charge_amt, v_charge_status
    FROM public.charges
    WHERE id = '00000000-0000-0000-0000-0000000000d1';

    ASSERT v_charge_amt = 500, 'Expected 500 cents charge';
    ASSERT v_charge_status = 'succeeded', 'Expected succeeded charge';
END $$;

-- Test 7: Cascade deletion when user is deleted
DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000005';

DO $$
DECLARE
    v_contract_count INT;
    v_charge_count INT;
BEGIN
    SELECT COUNT(*) INTO v_contract_count FROM public.contracts WHERE id = '00000000-0000-0000-0000-0000000000c1';
    SELECT COUNT(*) INTO v_charge_count FROM public.charges WHERE id = '00000000-0000-0000-0000-0000000000d1';

    ASSERT v_contract_count = 0, 'Contract was not cascaded upon user deletion';
    ASSERT v_charge_count = 0, 'Charge was not cascaded upon contract deletion';
END $$;

ROLLBACK;
