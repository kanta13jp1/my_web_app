-- Keep AI analysis history inserts from failing when legacy request
-- fingerprints contain full JSON payloads.

drop index if exists public.asset_management_ai_analysis_history_user_fingerprint_idx;

create index if not exists asset_management_ai_analysis_history_user_fingerprint_idx
  on public.asset_management_ai_analysis_history (user_id, md5(request_fingerprint));
