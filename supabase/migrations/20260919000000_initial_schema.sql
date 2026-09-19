-- ScrollGuard Supabase Initial Schema
-- Migration: 20260919000000_initial_schema.sql

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    timezone TEXT NOT NULL DEFAULT 'UTC',
    day_reset_hour INT NOT NULL DEFAULT 4 CHECK (day_reset_hour BETWEEN 0 AND 23)
);

-- 2. Devices Table
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    platform TEXT NOT NULL DEFAULT 'android',
    app_version TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    guard_enabled BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. Rules Configuration Table
CREATE TABLE IF NOT EXISTS public.rules_config (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    budget_seconds INT NOT NULL DEFAULT 1800,
    ladder JSONB NOT NULL DEFAULT '{"l0": 0.5, "l1": 0.8, "l2": 1.0}'::jsonb,
    guarded_apps TEXT[] NOT NULL DEFAULT ARRAY['com.google.android.youtube', 'com.instagram.android', 'com.zhiliaoapp.musically'],
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Daily Stats Aggregates Table
CREATE TABLE IF NOT EXISTS public.daily_stats (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    feed_seconds INT NOT NULL DEFAULT 0,
    swipe_count INT NOT NULL DEFAULT 0,
    lock_count INT NOT NULL DEFAULT 0,
    strike_count INT NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, date)
);

-- 5. Penalty Events Table
CREATE TABLE IF NOT EXISTS public.penalty_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    app_id TEXT NOT NULL,
    level INT NOT NULL CHECK (level BETWEEN 0 AND 3),
    reason TEXT NOT NULL,
    budget_fraction DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    meta JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- 6. Guard Lifecycle Events Table
CREATE TABLE IF NOT EXISTS public.guard_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    type TEXT NOT NULL CHECK (type IN ('guard_on', 'guard_off', 'rules_stale', 'boot', 'paused', 'emergency_unlock')),
    meta JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- 7. Commitment Contracts Table
CREATE TABLE IF NOT EXISTS public.contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'paused', 'cancelled')),
    stripe_customer_id TEXT,
    stripe_pm_id TEXT,
    per_penalty_cents INT NOT NULL DEFAULT 500,
    daily_cap_cents INT NOT NULL DEFAULT 1500,
    weekly_cap_cents INT NOT NULL DEFAULT 3000,
    strike_threshold INT NOT NULL DEFAULT 3,
    destination TEXT NOT NULL DEFAULT 'charity' CHECK (destination IN ('charity', 'fee')),
    terms_version TEXT NOT NULL DEFAULT 'v1.0',
    accepted_at TIMESTAMPTZ,
    cooling_off_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Charges Table
CREATE TABLE IF NOT EXISTS public.charges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    penalty_event_id UUID REFERENCES public.penalty_events(id) ON DELETE SET NULL,
    amount_cents INT NOT NULL,
    stripe_payment_intent_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'requires_action')),
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Detector Rules Table
CREATE TABLE IF NOT EXISTS public.detector_rules (
    version INT PRIMARY KEY,
    rules JSONB NOT NULL,
    min_app_build INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_devices_user ON public.devices(user_id);
CREATE INDEX IF NOT EXISTS idx_penalty_events_user_ts ON public.penalty_events(user_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_guard_events_user_ts ON public.guard_events(user_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_contracts_user_status ON public.contracts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_charges_contract ON public.charges(contract_id);
