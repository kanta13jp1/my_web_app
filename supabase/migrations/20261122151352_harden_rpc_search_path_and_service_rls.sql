-- Security Advisor WARN hardening: service_role RLS scoping,
-- least-privilege EXECUTE revocation for non-public SECURITY DEFINER functions,
-- and fixed search_path for all 70 user-defined public functions.
-- Note: intentionally preserves anon EXECUTE on public RLS/guest helpers:
--   is_user_admin(uuid), is_musubi_thread_member(uuid,uuid), increment_lp_view(date),
--   record_landing_experiment_event(uuid,text), update_site_statistics().

-- =============================================================
-- Block A: Scope service-role-only RLS policies from PUBLIC to service_role
-- =============================================================
DO $$
BEGIN
  IF to_regclass('public.ai_hub_chat_logs') IS NOT NULL THEN
    DROP POLICY IF EXISTS "service role full access" ON public.ai_hub_chat_logs;
    CREATE POLICY "service role full access"
      ON public.ai_hub_chat_logs
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;

  IF to_regclass('public.competitor_monitoring') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Service role full access on competitor_monitoring" ON public.competitor_monitoring;
    CREATE POLICY "Service role full access on competitor_monitoring"
      ON public.competitor_monitoring
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

-- =============================================================
-- Block B1: Restrict triggers / cron / admin-only SECURITY DEFINER RPCs to service_role
-- =============================================================
DO $$
DECLARE
  v_sig text;
  v_proc regprocedure;
  v_sigs text[] := ARRAY[
    'public.capture_investment_portfolio_history()',
    'public.handle_new_user_stats()',
    'public.notify_ai_circuit_breaker_open()',
    'public.set_anonymous_flag()',
    'public.trg_auto_award_badges()',
    'public.update_user_count()',
    'public.auto_record_growth_metrics()',
    'public.award_ai_university_badge(uuid,text,text,text,text)',
    'public.get_attachment_stats(uuid)',
    'public.increment_points(uuid,integer)',
    'public.increment_wbs_rebalance_count(uuid)',
    'public.purge_mcp_audit_log()',
    'public.purge_user_api_audit_log()',
    'public.record_daily_growth_metrics()',
    'public.record_task_budget_spend(text,text,numeric)',
    'public.seed_12dept_20agents(uuid)',
    'public.wbs_auto_repair_dependencies()',
    'public.increment_access_count(text)',
    'public.increment_conversion()',
    'public.increment_landing_view(text)'
  ];
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_proc := to_regprocedure(v_sig);
    IF v_proc IS NOT NULL THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', v_proc);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', v_proc);
    END IF;
  END LOOP;
END
$$;

-- =============================================================
-- Block B2: Restrict authenticated-only SECURITY DEFINER RPCs (revoke anon/PUBLIC)
-- =============================================================
DO $$
DECLARE
  v_sig text;
  v_proc regprocedure;
  v_sigs text[] := ARRAY[
    'public.get_billing_paid_conversion_summary()',
    'public.musubi_start_direct_thread(uuid)',
    'public.record_activation_experiment_event(text)',
    'public.update_ai_university_streak(uuid)'
  ];
BEGIN
  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_proc := to_regprocedure(v_sig);
    IF v_proc IS NOT NULL THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', v_proc);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', v_proc);
    END IF;
  END LOOP;
END
$$;

-- =============================================================
-- Block C: Pin search_path on all 70 user-defined public functions
-- (generate_share_token includes extensions for gen_random_bytes)
-- =============================================================
DO $$
DECLARE
  v_sig text;
  v_proc regprocedure;
  v_sigs text[] := ARRAY[
    'public.auto_record_growth_metrics()',
    'public.award_ai_university_badge(uuid,text,text,text,text)',
    'public.calculate_profile_completeness(user_profiles)',
    'public.cfo_total_assets()',
    'public.claim_challenge_reward(bigint)',
    'public.generate_referral_code()',
    'public.get_attachment_stats(uuid)',
    'public.get_my_daily_challenges(date)',
    'public.get_wasteful_category_label(text)',
    'public.handle_new_user_stats()',
    'public.increment_access_count(text)',
    'public.increment_challenge_progress(uuid,text,integer)',
    'public.increment_conversion()',
    'public.increment_edge_function_call_count(text)',
    'public.increment_landing_view(text)',
    'public.increment_points(uuid,integer)',
    'public.is_overdue(timestamp with time zone)',
    'public.match_kg_embeddings(vector,integer,double precision,text[])',
    'public.match_memory_index(vector,integer,double precision)',
    'public.normalize_blog_platform(text)',
    'public.record_daily_growth_metrics()',
    'public.run_agent_heartbeat(uuid)',
    'public.run_agent_memory_forgetting(uuid,integer)',
    'public.run_agent_nightly_consolidation(uuid)',
    'public.run_agent_runtime_cycle(uuid,boolean,boolean)',
    'public.seed_12dept_20agents(uuid)',
    'public.set_agent_org_updated_at()',
    'public.set_anomaly_detections_updated_at()',
    'public.set_anonymous_flag()',
    'public.set_asset_liability_updated_at()',
    'public.set_asset_management_ai_analysis_history_updated_at()',
    'public.set_billing_updated_at()',
    'public.set_cfo_cost_ledger_updated_at()',
    'public.set_corporate_bank_fee_plans_updated_at()',
    'public.set_daily_status_updated_at()',
    'public.set_debt_safety_guidance_master_updated_at()',
    'public.set_department_kpi_links_updated_at()',
    'public.set_finance_ai_updated_at()',
    'public.set_investment_assets_updated_at()',
    'public.set_investment_market_price_cache_updated_at()',
    'public.set_maintenance_windows_updated_at()',
    'public.set_monthly_asset_reports_updated_at()',
    'public.shop_touch_updated_at()',
    'public.sync_blog_post_to_tech_blog_posts()',
    'public.sync_salary_income_from_payslip()',
    'public.track_and_get_page_stats(text,text,text)',
    'public.track_and_get_page_stats(text,text)',
    'public.trg_auto_award_badges()',
    'public.update_ai_university_streak(uuid)',
    'public.update_ai_university_updated_at()',
    'public.update_app_feedback_updated_at()',
    'public.update_app_theme_updated_at()',
    'public.update_attachments_updated_at()',
    'public.update_blog_posts_updated_at()',
    'public.update_conversation_updated_at()',
    'public.update_edge_function_ui_status_updated_at()',
    'public.update_english_reading_lessons_updated_at()',
    'public.update_guitar_recordings_updated_at()',
    'public.update_prefecture_election_news_updated_at()',
    'public.update_profile_completeness()',
    'public.update_timers_updated_at()',
    'public.update_tracked_product_on_price_log()',
    'public.update_university_faculty_updated_at()',
    'public.update_updated_at_column()',
    'public.update_user_count()',
    'public.update_user_skills_updated_at()',
    'public.update_wbs_tasks_updated_at()',
    'public.wbs_enforce_recovery_plan()',
    'public.wbs_request_ai_review_on_complete()'
  ];
BEGIN
  v_proc := to_regprocedure('public.generate_share_token()');
  IF v_proc IS NOT NULL THEN
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions, pg_temp', v_proc);
  END IF;

  FOREACH v_sig IN ARRAY v_sigs LOOP
    v_proc := to_regprocedure(v_sig);
    IF v_proc IS NOT NULL THEN
      EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', v_proc);
    END IF;
  END LOOP;
END
$$;
