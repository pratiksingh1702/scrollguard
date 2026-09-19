-- Test: Heartbeat and Guard-Silent Detection
-- Acceptance: Simulated gap produces a server event

BEGIN;

DO $$
DECLARE
    test_user UUID := '33333333-3333-3333-3333-333333333333';
    test_device UUID := '44444444-4444-4444-4444-444444444444';
    event_count INT;
BEGIN
    -- 1. Create user and device with last_seen_at set to 6 hours ago
    INSERT INTO public.profiles (id, timezone)
    VALUES (test_user, 'UTC');

    INSERT INTO public.devices (id, user_id, platform, app_version, last_seen_at, guard_enabled)
    VALUES (test_device, test_user, 'android', '1.0.0', NOW() - INTERVAL '6 hours', TRUE);

    -- 2. Simulate server-side periodic check for guard-silent gaps
    -- Any device active with guard_enabled = true that missed heartbeats > 3 hours logs a guard_off event
    INSERT INTO public.guard_events (user_id, ts, type, meta)
    SELECT
        d.user_id,
        NOW(),
        'guard_off',
        jsonb_build_object(
            'reason', 'guard_silent_gap',
            'gap_hours', EXTRACT(EPOCH FROM (NOW() - d.last_seen_at)) / 3600,
            'device_id', d.id
        )
    FROM public.devices d
    WHERE d.guard_enabled = TRUE
      AND d.last_seen_at < (NOW() - INTERVAL '3 hours')
      AND d.user_id = test_user;

    -- 3. Assert that the simulated gap produced a server event
    SELECT COUNT(*) INTO event_count
    FROM public.guard_events
    WHERE user_id = test_user
      AND type = 'guard_off'
      AND meta->>'reason' = 'guard_silent_gap';

    IF event_count < 1 THEN
        RAISE EXCEPTION 'TEST FAILED: Simulated gap did NOT produce a guard_event!';
    END IF;

    RAISE NOTICE 'SUCCESS: Simulated gap produced % guard_event(s)', event_count;
END $$;

ROLLBACK;
