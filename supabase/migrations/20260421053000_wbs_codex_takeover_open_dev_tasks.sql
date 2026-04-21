-- Superseded broad Codex takeover migration.
--
-- This migration previously reassigned every open development task to Codex.
-- The current operating rule is stricter: only tasks Codex actually starts may
-- be reassigned. Kept as a no-op so fresh environments do not apply the broad
-- fallback; production environments that already ran the original migration are
-- corrected by 20260421063000_wbs_codex_takeover_scope_correction.sql.

DO $$
BEGIN
  RAISE NOTICE '20260421053000 superseded: Codex takeover is scoped by 20260421063000';
END $$;
