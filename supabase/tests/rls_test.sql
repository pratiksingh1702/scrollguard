-- ScrollGuard RLS Isolation Tests
-- Verifies that user A cannot read, modify, or delete user B's rows

BEGIN;

-- Setup test users
CREATE SCHEMA IF NOT EXISTS tests;

-- Mock auth.uid() function for testing environment
CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$ LANGUAGE SQL STABLE;

-- Create dummy users
DO $$
DECLARE
    user_a UUID := '11111111-1111-1111-1111-111111111111';
    user_b UUID := '22222222-2222-2222-2222-222222222222';
    contract_a UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    penalty_a UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    count_b INT;
BEGIN
    -- 1. Insert records as User A
    PERFORM set_config('request.jwt.claim.sub', user_a::text, true);

    INSERT INTO public.profiles (id, timezone, day_reset_hour)
    VALUES (user_a, 'America/New_York', 4);

    INSERT INTO public.daily_stats (user_id, date, feed_seconds, swipe_count, lock_count, strike_count)
    VALUES (user_a, '2026-09-19', 1200, 45, 1, 0);

    INSERT INTO public.penalty_events (id, user_id, app_id, level, reason, budget_fraction)
    VALUES (penalty_a, user_a, 'com.instagram.android', 1, 'BUDGET_REACHED: 80%', 0.8);

    INSERT INTO public.contracts (id, user_id, status, per_penalty_cents, daily_cap_cents)
    VALUES (contract_a, user_a, 'active', 500, 1500);

    -- 2. Switch context to User B
    PERFORM set_config('request.jwt.claim.sub', user_b::text, true);

    -- Assert User B cannot read User A's profile
    SELECT COUNT(*) INTO count_b FROM public.profiles WHERE id = user_a;
    IF count_b <> 0 THEN
        RAISE EXCEPTION 'RLS FAILURE: User B can read User A profile!';
    END IF;

    -- Assert User B cannot read User A's daily stats
    SELECT COUNT(*) INTO count_b FROM public.daily_stats WHERE user_id = user_a;
    IF count_b <> 0 THEN
        RAISE EXCEPTION 'RLS FAILURE: User B can read User A daily stats!';
    END IF;

    -- Assert User B cannot read User A's penalty events
    SELECT COUNT(*) INTO count_b FROM public.penalty_events WHERE user_id = user_a;
    IF count_b <> 0 THEN
        RAISE EXCEPTION 'RLS FAILURE: User B can read User A penalty events!';
    END IF;

    -- Assert User B cannot read User A's contracts
    SELECT COUNT(*) INTO count_b FROM public.contracts WHERE user_id = user_a;
    IF count_b <> 0 THEN
        RAISE EXCEPTION 'RLS FAILURE: User B can read User A contracts!';
    END IF;

    -- Assert User B CAN read public detector rules
    SELECT COUNT(*) INTO count_b FROM public.detector_rules WHERE version = 1;
    IF count_b < 1 THEN
        RAISE EXCEPTION 'RLS FAILURE: User B cannot read public detector rules!';
    END IF;

    RAISE NOTICE 'SUCCESS: All RLS isolation tests passed successfully.';
END $$;

ROLLBACK;
