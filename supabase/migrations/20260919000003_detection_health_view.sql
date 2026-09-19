-- Migration: 20260919000003_detection_health_view.sql
-- Description: Detection health monitoring view to track rules_stale and divergence rates per app

CREATE OR REPLACE VIEW public.detection_health AS
WITH event_counts AS (
    SELECT
        COALESCE(payload->>'app', payload->>'app_id', 'unknown') AS app_id,
        COALESCE(payload->>'app_version', 'unknown') AS target_app_version,
        COUNT(*) AS total_guard_events,
        COUNT(*) FILTER (WHERE event_type = 'rules_stale') AS stale_events_count,
        COUNT(*) FILTER (WHERE event_type = 'usage_divergence') AS divergence_events_count,
        MAX(ts) AS last_stale_event_at
    FROM public.guard_events
    WHERE ts >= NOW() - INTERVAL '24 hours'
    GROUP BY 1, 2
)
SELECT
    app_id,
    target_app_version,
    total_guard_events,
    stale_events_count,
    divergence_events_count,
    ROUND((stale_events_count::numeric / NULLIF(total_guard_events, 0)::numeric) * 100, 2) AS stale_rate_pct,
    CASE
        WHEN stale_events_count = 0 THEN 'HEALTHY'
        WHEN (stale_events_count::numeric / NULLIF(total_guard_events, 0)::numeric) < 0.10 THEN 'WARNING'
        ELSE 'CRITICAL'
    END AS status,
    last_stale_event_at
FROM event_counts;

-- Allow authenticated admins / service role to view detection health
COMMENT ON VIEW public.detection_health IS 'Tracks detector health, stale rules, and divergence rates across guarded applications over the last 24 hours.';
