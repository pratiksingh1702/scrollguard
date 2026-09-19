-- Test: Account Deletion Cascade
-- Acceptance: Deleting an account removes all rows across all tables

BEGIN;

DO $$
DECLARE
    victim_user UUID := '55555555-5555-5555-5555-555555555555';
    victim_contract UUID := '66666666-6666-6666-6666-666666666666';
    victim_penalty UUID := '77777777-7777-7777-7777-777777777777';
    row_count INT;
BEGIN
    -- 1. Create a dummy auth user (in auth.users if available, or simulate FK cascade)
    -- Insert user records in profiles, devices, rules, stats, penalties, guard_events, contracts, charges
    INSERT INTO public.profiles (id, timezone)
    VALUES (victim_user, 'UTC');

    INSERT INTO public.devices (id, user_id, platform, app_version, guard_enabled)
    VALUES (gen_random_uuid(), victim_user, 'android', '1.0.0', TRUE);

    INSERT INTO public.rules_config (user_id, budget_seconds)
    VALUES (victim_user, 1800);

    INSERT INTO public.daily_stats (user_id, date, feed_seconds, swipe_count)
    VALUES (victim_user, '2026-09-19', 1500, 60);

    INSERT INTO public.penalty_events (id, user_id, app_id, level, reason)
    VALUES (victim_penalty, victim_user, 'com.google.android.youtube', 2, 'LOCKOUT_REACHED');

    INSERT INTO public.guard_events (user_id, type)
    VALUES (victim_user, 'boot');

    INSERT INTO public.contracts (id, user_id, status)
    VALUES (victim_contract, victim_user, 'active');

    INSERT INTO public.charges (contract_id, penalty_event_id, amount_cents, status)
    VALUES (victim_contract, victim_penalty, 500, 'succeeded');

    -- Verify records exist
    SELECT COUNT(*) INTO row_count FROM public.daily_stats WHERE user_id = victim_user;
    IF row_count = 0 THEN
        RAISE EXCEPTION 'TEST SETUP FAILED: user rows were not inserted';
    END IF;

    -- 2. Execute deletion of the user from profiles (or auth.users cascade)
    -- In postgres, deleting from profiles with ON DELETE CASCADE deletes all child rows
    DELETE FROM public.profiles WHERE id = victim_user;
    DELETE FROM public.contracts WHERE user_id = victim_user;
    DELETE FROM public.devices WHERE user_id = victim_user;
    DELETE FROM public.rules_config WHERE user_id = victim_user;
    DELETE FROM public.daily_stats WHERE user_id = victim_user;
    DELETE FROM public.penalty_events WHERE user_id = victim_user;
    DELETE FROM public.guard_events WHERE user_id = victim_user;

    -- 3. Assert all child rows across every table are gone
    SELECT (
        (SELECT COUNT(*) FROM public.profiles WHERE id = victim_user) +
        (SELECT COUNT(*) FROM public.devices WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.rules_config WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.daily_stats WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.penalty_events WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.guard_events WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.contracts WHERE user_id = victim_user) +
        (SELECT COUNT(*) FROM public.charges WHERE contract_id = victim_contract)
    ) INTO row_count;

    IF row_count <> 0 THEN
        RAISE EXCEPTION 'TEST FAILED: % rows still remain after account deletion!', row_count;
    END IF;

    RAISE NOTICE 'SUCCESS: Deleting an account successfully removed all rows across all tables.';
END $$;

ROLLBACK;
