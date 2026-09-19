-- ScrollGuard Supabase RLS Policies
-- Migration: 20260919000001_rls_policies.sql

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rules_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.penalty_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guard_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detector_rules ENABLE ROW LEVEL SECURITY;

-- 1. Profiles Policies
CREATE POLICY "Users can select their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can delete their own profile"
    ON public.profiles FOR DELETE
    USING (auth.uid() = id);

-- 2. Devices Policies
CREATE POLICY "Users can view their own devices"
    ON public.devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can register their own devices"
    ON public.devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own devices"
    ON public.devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own devices"
    ON public.devices FOR DELETE
    USING (auth.uid() = user_id);

-- 3. Rules Config Policies
CREATE POLICY "Users can view their own rules"
    ON public.rules_config FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can set their own rules"
    ON public.rules_config FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own rules"
    ON public.rules_config FOR UPDATE
    USING (auth.uid() = user_id);

-- 4. Daily Stats Policies
CREATE POLICY "Users can view their own daily stats"
    ON public.daily_stats FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own daily stats"
    ON public.daily_stats FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own daily stats"
    ON public.daily_stats FOR UPDATE
    USING (auth.uid() = user_id);

-- 5. Penalty Events Policies
CREATE POLICY "Users can view their own penalty events"
    ON public.penalty_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can record their own penalty events"
    ON public.penalty_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 6. Guard Events Policies
CREATE POLICY "Users can view their own guard events"
    ON public.guard_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can record their own guard events"
    ON public.guard_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 7. Contracts Policies
CREATE POLICY "Users can view their own contracts"
    ON public.contracts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own contract"
    ON public.contracts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own contract"
    ON public.contracts FOR UPDATE
    USING (auth.uid() = user_id);

-- 8. Charges Policies (Read-only for users, Edge functions execute charges)
CREATE POLICY "Users can view charges on their contracts"
    ON public.charges FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.contracts c
            WHERE c.id = contract_id AND c.user_id = auth.uid()
        )
    );

-- 9. Detector Rules Policies (Public read for app clients, write restricted to service role)
CREATE POLICY "Detector rules are readable by all users"
    ON public.detector_rules FOR SELECT
    USING (true);
