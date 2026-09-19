-- Migration: 20260919000002_detector_rules_rollout.sql
-- Description: Add rollout_percentage column to detector_rules for staged deployments

ALTER TABLE public.detector_rules
ADD COLUMN IF NOT EXISTS rollout_percentage INT NOT NULL DEFAULT 100
CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100);

-- Update existing rows to 100% rollout
UPDATE public.detector_rules
SET rollout_percentage = 100
WHERE rollout_percentage IS NULL;

-- Public read access for active detector rules
DROP POLICY IF EXISTS "Detector rules are readable by everyone" ON public.detector_rules;
CREATE POLICY "Detector rules are readable by everyone"
    ON public.detector_rules FOR SELECT
    USING (is_active = true);
