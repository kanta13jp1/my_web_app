-- Join the first unknown-user X campaign to the downstream activation and
-- payment funnel without storing email, name, prompt text, IP address, or user
-- agent. One visitor can contribute at most once to each campaign stage.
CREATE TABLE public.first_user_acquisition_events (
  visitor_id uuid NOT NULL,
  auth_user_id uuid
    REFERENCES auth.users (id) ON DELETE SET NULL,
  stage text NOT NULL
    CHECK (
      stage IN (
        'view',
        'trial',
        'signup_submit',
        'signup_complete',
        'first_action_completed',
        'billing_view',
        'supporter_checkout'
      )
    ),
  utm_source text NOT NULL
    CHECK (utm_source = 'x'),
  utm_medium text NOT NULL
    CHECK (utm_medium ~ '^[a-z0-9_-]{1,64}$'),
  utm_campaign text NOT NULL
    CHECK (utm_campaign = 'first_user_growth'),
  utm_content text NOT NULL
    CHECK (utm_content ~ '^[a-z0-9_-]{1,64}$'),
  first_occurred_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (
    visitor_id,
    utm_source,
    utm_medium,
    utm_campaign,
    utm_content,
    stage
  )
);

COMMENT ON TABLE public.first_user_acquisition_events IS
  'Privacy-minimized unique-visitor funnel for the unknown-user first_user_growth X campaign.';

CREATE INDEX first_user_acquisition_events_report_idx
  ON public.first_user_acquisition_events (
    utm_campaign,
    utm_content,
    first_occurred_at DESC
  );

ALTER TABLE public.first_user_acquisition_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.first_user_acquisition_events
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON TABLE public.first_user_acquisition_events
  TO service_role;
