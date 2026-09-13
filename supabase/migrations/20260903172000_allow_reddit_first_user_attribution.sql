-- Add the human-reviewed Reddit community launch to the privacy-minimized
-- first_user_growth cohort. RLS and service-role-only grants remain unchanged.
ALTER TABLE public.first_user_acquisition_events
  DROP CONSTRAINT IF EXISTS first_user_acquisition_events_utm_source_check;

ALTER TABLE public.first_user_acquisition_events
  ADD CONSTRAINT first_user_acquisition_events_utm_source_check
  CHECK (utm_source IN ('x', 'zenn', 'reddit')) NOT VALID;

ALTER TABLE public.first_user_acquisition_events
  VALIDATE CONSTRAINT first_user_acquisition_events_utm_source_check;

COMMENT ON TABLE public.first_user_acquisition_events IS
  'Privacy-minimized unique-visitor funnel for approved first_user_growth acquisition channels.';
