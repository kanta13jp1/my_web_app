import 'dart:async';

import 'package:my_web_app/pages/aero_lab_page.dart';
import 'package:my_web_app/pages/sound_bloom_page.dart';

import 'package:flutter/material.dart';
import 'package:my_web_app/services/version_check_service.dart';
import 'package:my_web_app/widgets/update_banner.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_web_app/data/home_tool_catalog.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';
import 'package:my_web_app/utils/route_url_sync.dart';
import 'package:my_web_app/utils/route_document_title.dart';
import 'package:my_web_app/models/site_guide_catalog_item.dart';
import 'package:my_web_app/pages/abstinence_guard_page.dart';
import 'package:my_web_app/pages/self_touch_tracker_page.dart';
import 'package:my_web_app/pages/agent_org_page.dart';
import 'package:my_web_app/pages/agent_board_page.dart';
import 'package:my_web_app/pages/autonomous_ops_console_page.dart';
import 'package:my_web_app/pages/ai_company_builder_page.dart';
import 'package:my_web_app/pages/agi_fireworks_page.dart';
import 'package:my_web_app/pages/ai_agent_page.dart';
import 'package:my_web_app/pages/behavior_review_page.dart';
import 'package:my_web_app/pages/habit_center_page.dart';
import 'package:my_web_app/pages/my_struggle_page.dart';
import 'package:my_web_app/pages/prison_mode_page.dart';
import 'package:my_web_app/pages/bookmark_folders_page.dart';
import 'package:my_web_app/pages/behavior_log_page.dart';
import 'package:my_web_app/pages/danshari_page.dart';
import 'package:my_web_app/pages/email_cleanup_page.dart';
import 'package:my_web_app/pages/local_smart_cleanup_page.dart';
import 'package:my_web_app/pages/windows_app_install_page.dart';
import 'package:my_web_app/pages/payment_reminder_page.dart';
import 'package:my_web_app/pages/shopping_list_page.dart';
import 'package:my_web_app/pages/digital_product_store_pages.dart';
import 'package:my_web_app/pages/hexciv_shop_page.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:my_web_app/pages/digest_queue_page.dart';
import 'package:my_web_app/pages/gemini_university_v2_page.dart';
import 'package:my_web_app/pages/growth_mission_page.dart';
import 'package:my_web_app/pages/site_guide_chat_page.dart';
import 'package:my_web_app/pages/user_manual_page.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';
import 'package:my_web_app/pages/import_page.dart';
import 'package:my_web_app/pages/integration_registry_page.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/pages/memory_drill_page.dart';
import 'package:my_web_app/pages/memory_search_hub_page.dart';
import 'package:my_web_app/pages/morning_briefing_page.dart';
import 'package:my_web_app/pages/note_editor_page.dart';
import 'package:my_web_app/pages/onboarding_page.dart';
import 'package:my_web_app/pages/activity_feed_page.dart';
import 'package:my_web_app/pages/public_memo_detail_page.dart';
import 'package:my_web_app/pages/public_memo_directory_page.dart';
import 'package:my_web_app/pages/ai_university_ranking_page.dart';
import 'package:my_web_app/pages/ai_university_video_page.dart';
import 'package:my_web_app/pages/ai_university_voice_page.dart';
import 'package:my_web_app/pages/content_dubbing_page.dart';
import 'package:my_web_app/pages/reality_check_page.dart';
import 'package:my_web_app/pages/comparison_page.dart';
import 'package:my_web_app/pages/competitor_browse_page.dart';
import 'package:my_web_app/pages/note_list_page.dart';
import 'package:my_web_app/pages/philosophy_page.dart';
import 'package:my_web_app/pages/legal_document_page.dart';
import 'package:my_web_app/pages/privacy_policy_page.dart';
import 'package:my_web_app/pages/ai_dev_principles_page.dart';
import 'package:my_web_app/pages/feature_requests_page.dart';
import 'package:my_web_app/pages/profile_settings_page.dart';
import 'package:my_web_app/pages/account_deletion_page.dart';
import 'package:my_web_app/pages/public_profile_page.dart';
import 'package:my_web_app/pages/blog_page.dart';
import 'package:my_web_app/pages/blog_compose_page.dart';
import 'package:my_web_app/pages/public_blog_post_page.dart';
import 'package:my_web_app/pages/tech_blog_tracker_page.dart';
import 'package:my_web_app/pages/thought_anchor_page.dart';
import 'package:my_web_app/pages/rewards_page.dart';
import 'package:my_web_app/pages/admin_analytics_page.dart';
import 'package:my_web_app/pages/admin_artifact_publishing_page.dart';
import 'package:my_web_app/pages/admin/feedback_list_page.dart';
import 'package:my_web_app/pages/admin/quota_dashboard_page.dart';
import 'package:my_web_app/pages/admin/blog_management_page.dart';
import 'package:my_web_app/pages/admin/blog_draft_editor_page.dart';
import 'package:my_web_app/pages/admin/maintenance_management_page.dart';
import 'package:my_web_app/pages/home_insights_page.dart';
import 'package:my_web_app/pages/career_monthly_kpi_page.dart';
import 'package:my_web_app/pages/goal_center_page.dart';
import 'package:my_web_app/pages/thought_capture_page.dart';
import 'package:my_web_app/pages/decision_check_page.dart';
import 'package:my_web_app/pages/eval_approval_page.dart';
import 'package:my_web_app/pages/purchase_log_page.dart';
import 'package:my_web_app/pages/price_tracker_page.dart';
import 'package:my_web_app/pages/process_quality_dashboard_page.dart';
import 'package:my_web_app/pages/ai_observability_page.dart';
import 'package:my_web_app/pages/ai_router_cost_dashboard_page.dart';
import 'package:my_web_app/pages/task_budget_assistant_page.dart';
import 'package:my_web_app/pages/agent_gpa_dashboard_page.dart';
import 'package:my_web_app/pages/conveni_store_page.dart';
import 'package:my_web_app/pages/ai_search_page.dart';
import 'package:my_web_app/pages/edge_function_status_page.dart';
import 'package:my_web_app/pages/edge_llm_playground_page.dart';
import 'package:my_web_app/pages/election_management_dashboard.dart';
import 'package:my_web_app/pages/election_victory_page.dart';
import 'package:my_web_app/pages/template_marketplace_page.dart';
import 'package:my_web_app/pages/referral_page.dart';
import 'package:my_web_app/pages/kanban_board_page.dart';
import 'package:my_web_app/pages/compatibility_check_page.dart';
import 'package:my_web_app/models/iq_test.dart';
import 'package:my_web_app/pages/iq_test_page.dart';
import 'package:my_web_app/pages/iq_test_questions_page.dart';
import 'package:my_web_app/pages/iq_test_result_page.dart';
import 'package:my_web_app/pages/iq_training_drill_page.dart';
import 'package:my_web_app/pages/iq_training_page.dart';
import 'package:my_web_app/pages/personality_test_questions_page.dart';
import 'package:my_web_app/pages/personality_test_result_page.dart';
import 'package:my_web_app/pages/table_data_page.dart';
import 'package:my_web_app/pages/work_menu_page.dart';
import 'package:my_web_app/pages/ai_suggest_tags_page.dart';
import 'package:my_web_app/pages/analyze_reality_page.dart';
import 'package:my_web_app/pages/support_tickets_page.dart';
import 'package:my_web_app/pages/growth_achievement_summary_page.dart';
import 'package:my_web_app/pages/growth_acquisition_page.dart';
import 'package:my_web_app/pages/growth_acquisition_report_page.dart';
import 'package:my_web_app/pages/growth_command_center_page.dart';
import 'package:my_web_app/pages/growth_share_signal_page.dart';
import 'package:my_web_app/pages/growth_weekly_digest_page.dart';
import 'package:my_web_app/pages/memo_reactions_page.dart';
import 'package:my_web_app/pages/note_comments_page.dart';
import 'package:my_web_app/pages/growth_acquisition_signal_page.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:my_web_app/pages/corporate_bank_account_simulator_page.dart';
import 'package:my_web_app/pages/corporate_site_readiness_page.dart';
import 'package:my_web_app/pages/ai_secretary_page.dart';
import 'package:my_web_app/pages/api_playground_page.dart';
import 'package:my_web_app/pages/categories_page.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:my_web_app/pages/embedding_lab_page.dart';
import 'package:my_web_app/pages/financial_report_page.dart';
import 'package:my_web_app/pages/payment_channel_ledger_page.dart';
import 'package:my_web_app/pages/feedback_page.dart';
import 'package:my_web_app/pages/health_page.dart';
import 'package:my_web_app/pages/medical_notes_page.dart';
import 'package:my_web_app/pages/mental_check_page.dart';
import 'package:my_web_app/pages/settings_page.dart';
import 'package:my_web_app/pages/ai_form_assistant_page.dart';
import 'package:my_web_app/pages/theme_selector_page.dart';
import 'package:my_web_app/pages/ai_university_faculty_select_page.dart';
import 'package:my_web_app/pages/ai_university_department_select_page.dart';
import 'package:my_web_app/pages/team_workspace_page.dart';
import 'package:my_web_app/pages/ai_status_page.dart';
import 'package:my_web_app/pages/tiger_review_lane_status_page.dart';
import 'package:my_web_app/pages/ai_provider_status_page.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/pages/asset_chat_history_page.dart';
import 'package:my_web_app/pages/cfo_office_page.dart';
import 'package:my_web_app/pages/cho_office_page.dart';
import 'package:my_web_app/pages/chro_office_page.dart';
import 'package:my_web_app/pages/cmo_office_page.dart';
import 'package:my_web_app/pages/cmo_page.dart';
import 'package:my_web_app/pages/election_strategy_page.dart';
import 'package:my_web_app/pages/mind_map_page.dart';
import 'package:my_web_app/pages/mindless_task_page.dart';
import 'package:my_web_app/pages/real_world_danshari_page.dart';
import 'package:my_web_app/pages/stock_tasks_page.dart';
import 'package:my_web_app/pages/notifications_page.dart';
import 'package:my_web_app/pages/wardrobe_page.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/growth_mission_service.dart';
import 'package:my_web_app/widgets/maintenance_banner.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:my_web_app/pages/carbon_footprint_tracker_page.dart';
import 'package:my_web_app/pages/donation_crowdfunding_page.dart';
import 'package:my_web_app/pages/emergency_contacts_page.dart';
import 'package:my_web_app/pages/knowledge_base_page.dart';
import 'package:my_web_app/pages/knowledge_graph_page.dart';
import 'package:my_web_app/pages/user_knowledge_graph_page.dart';
import 'package:my_web_app/pages/market_intelligence_page.dart';
import 'package:my_web_app/pages/meeting_manager_page.dart';
import 'package:my_web_app/pages/news_rss_aggregator_page.dart';
import 'package:my_web_app/pages/mcp_file_search_page.dart';
import 'package:my_web_app/pages/semantic_search_page.dart';
import 'package:my_web_app/pages/smart_inbox_triage_page.dart';
import 'package:my_web_app/pages/social_feed_page.dart';
import 'package:my_web_app/pages/sobriety_campaign_page.dart';
import 'package:my_web_app/pages/family_sharing_manager_page.dart';
import 'package:my_web_app/pages/gift_registry_page.dart';
import 'package:my_web_app/pages/mindmap_diagram_page.dart';
import 'package:my_web_app/pages/auction_marketplace_page.dart';
import 'package:my_web_app/pages/qr_code_generator_page.dart';
import 'package:my_web_app/pages/parking_reservation_page.dart';
import 'package:my_web_app/pages/analytics_export_page.dart';
import 'package:my_web_app/pages/workflow_templates_page.dart';
import 'package:my_web_app/pages/customer_feedback_page.dart';
import 'package:my_web_app/pages/address_book_page.dart';
import 'package:my_web_app/pages/subscription_billing_page.dart';
import 'package:my_web_app/pages/maintenance_mode_page.dart';
import 'package:my_web_app/pages/appointment_scheduler_page.dart';
import 'package:my_web_app/pages/budget_financial_planner_page.dart';
import 'package:my_web_app/pages/feature_flags_page.dart';
import 'package:my_web_app/pages/workflow_automation_page.dart';
import 'package:my_web_app/pages/social_media_scheduler_page.dart';
import 'package:my_web_app/pages/video_meeting_page.dart';
import 'package:my_web_app/pages/krisp_audio_quality_page.dart';
import 'package:my_web_app/pages/gantt_timeline_page.dart';
import 'package:my_web_app/pages/ai_image_generator_page.dart';
import 'package:my_web_app/pages/viral_ad_campaign_page.dart';
import 'package:my_web_app/pages/virtual_pet_page.dart';
import 'package:my_web_app/pages/affiliate_marketing_page.dart';
import 'package:my_web_app/pages/calendar_events_page.dart';
import 'package:my_web_app/pages/google_calendar_sync_page.dart';
import 'package:my_web_app/pages/money_forward_page.dart';
import 'package:my_web_app/pages/discord_notification_page.dart';
import 'package:my_web_app/pages/github_pr_page.dart';
import 'package:my_web_app/pages/line_notification_page.dart';
import 'package:my_web_app/pages/weekly_slip_report_page.dart';
import 'package:my_web_app/pages/slack_notification_page.dart';
import 'package:my_web_app/pages/expense_tracker_page.dart';
import 'package:my_web_app/pages/reading_list_page.dart';
import 'package:my_web_app/pages/ar_navigation_page.dart';
import 'package:my_web_app/pages/dns_domain_manager_page.dart';
import 'package:my_web_app/pages/focus_timer_page.dart';
import 'package:my_web_app/pages/digital_wallet_page.dart';
import 'package:my_web_app/pages/loyalty_points_page.dart';
import 'package:my_web_app/pages/viral_ad_generator_page.dart';
import 'package:my_web_app/pages/growth_automation_controller_page.dart';
import 'package:my_web_app/pages/landing_ab_test_page.dart';
import 'package:my_web_app/ui/features/video_studio/video_studio_feature.dart';
import 'package:my_web_app/ui/features/notion_migration/notion_migration_feature.dart';
import 'package:my_web_app/ui/features/procrastination_reset/procrastination_reset_feature.dart';
import 'package:my_web_app/ui/features/proactive_form_check/proactive_form_check_feature.dart';
import 'package:my_web_app/ui/features/custom_task_list/custom_task_list_feature.dart';
import 'package:my_web_app/pages/youtube_stats_page.dart';
import 'package:my_web_app/pages/audio_effects_processor_page.dart';
import 'package:my_web_app/pages/fitness_health_tracker_page.dart';
import 'package:my_web_app/pages/guitar_recording_studio_page.dart';
import 'package:my_web_app/pages/public_guitar_gallery_page.dart';
import 'package:my_web_app/pages/music_collaboration_page.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';
import 'package:my_web_app/pages/event_ticketing_page.dart';
import 'package:my_web_app/pages/ai_assistant_chat_page.dart';
import 'package:my_web_app/pages/writing_center_page.dart';
import 'package:my_web_app/pages/wiki_database_page.dart';
import 'package:my_web_app/pages/time_tracker_page.dart';
import 'package:my_web_app/pages/voice_memo_transcriber_page.dart';
import 'package:my_web_app/pages/form_builder_page.dart';
import 'package:my_web_app/pages/music_playlist_manager_page.dart';
import 'package:my_web_app/pages/virtual_organization_page.dart';
import 'package:my_web_app/pages/crm_sales_pipeline_page.dart';
import 'package:my_web_app/pages/horse_racing_predictor_page.dart';
import 'package:my_web_app/pages/horse_provider_leaderboard_page.dart';
import 'package:my_web_app/pages/travel_itinerary_page.dart';
import 'package:my_web_app/pages/art_museum_directory_page.dart';
import 'package:my_web_app/pages/virtual_whiteboard_page.dart';
import 'package:my_web_app/pages/recipe_meal_planner_page.dart';
import 'package:my_web_app/pages/meal_log_page.dart';
import 'package:my_web_app/pages/life_goals_kpi_page.dart';
import 'package:my_web_app/pages/language_learning_page.dart';
import 'package:my_web_app/pages/focus_capture_game_page.dart';
import 'package:my_web_app/pages/code_playground_page.dart';
import 'package:my_web_app/pages/real_estate_tracker_page.dart';
import 'package:my_web_app/ui/features/local_business_map/local_business_map_feature.dart';
import 'package:my_web_app/pages/spreadsheet_database_page.dart';
import 'package:my_web_app/pages/changelog_manager_page.dart';
import 'package:my_web_app/pages/release_notes_page.dart';
import 'package:my_web_app/pages/pet_care_manager_page.dart';
import 'package:my_web_app/pages/photo_gallery_manager_page.dart';
import 'package:my_web_app/pages/elearning_course_manager_page.dart';
import 'package:my_web_app/pages/document_esignature_page.dart';
import 'package:my_web_app/pages/vehicle_fleet_manager_page.dart';
import 'package:my_web_app/pages/recruitment_job_board_page.dart';
import 'package:my_web_app/pages/home_iot_manager_page.dart';
import 'package:my_web_app/pages/legal_compliance_manager_page.dart';
import 'package:my_web_app/pages/user_tasks_page.dart';
import 'package:my_web_app/pages/email_template_builder_page.dart';
import 'package:my_web_app/pages/two_factor_auth_page.dart';
import 'package:my_web_app/pages/inventory_barcode_page.dart';
import 'package:my_web_app/pages/password_vault_page.dart';
import 'package:my_web_app/pages/podcast_manager_page.dart';
import 'package:my_web_app/pages/screen_recorder_page.dart';
import 'package:my_web_app/pages/sitemap_analytics_page.dart';
import 'package:my_web_app/pages/access_control_page.dart';
import 'package:my_web_app/pages/personal_dashboard_page.dart';
import 'package:my_web_app/pages/my_skills_page.dart';
import 'package:my_web_app/pages/bookmark_sync_page.dart';
import 'package:my_web_app/pages/jibun_api_page.dart';
import 'package:my_web_app/pages/ui_design_status_page.dart';
import 'package:my_web_app/pages/revenue_forecaster_page.dart';
import 'package:my_web_app/pages/weather_widget_page.dart';
import 'package:my_web_app/pages/team_chat_page.dart';
import 'package:my_web_app/pages/health_coach_page.dart';
import 'package:my_web_app/pages/thought_interrupt_diagnosis_page.dart';
import 'package:my_web_app/pages/mental_health_tracker_page.dart';
import 'package:my_web_app/pages/freelance_manager_page.dart';
import 'package:my_web_app/pages/ai_presentation_builder_page.dart';
import 'package:my_web_app/pages/tome_deck_studio_page.dart';
import 'package:my_web_app/pages/data_backup_page.dart';
import 'package:my_web_app/pages/content_calendar_page.dart';
import 'package:my_web_app/pages/home_budget_planner_page.dart';
import 'package:my_web_app/pages/brain_dump_page.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';
import 'package:my_web_app/pages/business_card_manager_page.dart';
import 'package:my_web_app/pages/family_calendar_page.dart';
import 'package:my_web_app/pages/app_hub_page.dart';
import 'package:my_web_app/pages/agent_hub_page.dart';
import 'package:my_web_app/pages/admin_notification_hub_page.dart';
import 'package:my_web_app/pages/competitor_feature_sync_page.dart';
import 'package:my_web_app/pages/daily_judgment_page.dart';
import 'package:my_web_app/pages/deployment_monitoring_setup_page.dart';
import 'package:my_web_app/pages/one_in_two_out_assist_page.dart';
import 'package:my_web_app/pages/ai_university_content_page.dart';
import 'package:my_web_app/pages/development_achievements_page.dart';
import 'package:my_web_app/pages/invoice_generator_page.dart';
import 'package:my_web_app/pages/poll_survey_page.dart';
import 'package:my_web_app/pages/notification_digest_page.dart';
import 'package:my_web_app/pages/ai_university_badges_page.dart';
import 'package:my_web_app/pages/ai_university_streaks_page.dart';
import 'package:my_web_app/pages/english_reading_curriculum_page.dart';
import 'package:my_web_app/pages/english_reading_practice_page.dart';
import 'package:my_web_app/pages/english_reading_dashboard_page.dart';
import 'package:my_web_app/ui/features/toeic/toeic_feature.dart';
import 'package:my_web_app/pages/ai_workflow_automation_page.dart';
import 'package:my_web_app/pages/ab_testing_manager_page.dart';
import 'package:my_web_app/pages/habit_tracker_page.dart';
import 'package:my_web_app/pages/agent_department_manager_page.dart';
import 'package:my_web_app/pages/agent_performance_monitor_page.dart';
import 'package:my_web_app/pages/ai_share_button_settings_page.dart';
import 'package:my_web_app/pages/cfo_cost_ledger_page.dart';
import 'package:my_web_app/pages/compatibility_result_page.dart';
import 'package:my_web_app/pages/leave_management_page.dart';
import 'package:my_web_app/pages/performance_review_page.dart';
import 'package:my_web_app/pages/health_check_page.dart';
import 'package:my_web_app/pages/horseracing_race_detail_page.dart';
import 'package:my_web_app/pages/monthly_kpi_dashboard_page.dart';
import 'package:my_web_app/pages/offline_secure_mode_settings_page.dart';
import 'package:my_web_app/pages/people_help_page.dart';
import 'package:my_web_app/dev/claude_design/importer_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_web_app/services/landing_signup_completion_service.dart';
import 'package:my_web_app/services/notification_service.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/widgets/global_header_clock_bar.dart';
import 'utils/app_logger.dart';
import 'utils/error_reporter.dart';

import 'services/supabase_client_provider.dart';
import 'services/supabase_runtime_config.dart';
import 'services/supabase_trace_context.dart';

export 'services/supabase_client_provider.dart';

final GrowthPresenceNavigatorObserver _growthPresenceObserver =
    GrowthPresenceNavigatorObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // アクセシビリティを起動時から常時 ON にする。Flutter Web は既定で
  // 「アクセシビリティを有効にする(Enable accessibility)」プレースホルダを
  // 押すまでセマンティクスツリーを出さないため、スクリーンリーダー利用者は
  // 最初から全要素を読める。返り値の SemanticsHandle は dispose しないので
  // アプリ生存期間 ON を維持する(docs/ACCESSIBILITY_QA_CHECKLIST.md)。
  WidgetsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;
  usePathUrlStrategy();

  final NotificationService notificationService = NotificationService();
  final supabaseConfig = SupabaseRuntimeConfig.fromCompileTimeEnvironment();

  await Supabase.initialize(
    url: supabaseConfig.url,
    publishableKey: supabaseConfig.publishableKey,
    // Keep trace IDs in Supabase logs even when the Sentry transaction is not
    // exported. The wrapper adds identifiers only; payloads are never copied.
    httpClient: SupabaseTracingHttpClient(),
  );

  // Flutter/Dart エラーを自動で Sentry + フィードバックEF に送信
  AppLogger.setErrorReporter(
    (message, {error, stackTrace}) => ErrorReporter.instance.report(
      message,
      error: error,
      stackTrace: stackTrace,
    ),
  );
  await ErrorReporter.instance.install(
    appRunner: () {
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeService()),
            ChangeNotifierProvider(create: (_) => GamificationService()),
            Provider<NotificationService>(create: (_) => notificationService),
          ],
          child: const MyApp(),
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_configureStartupNotifications(notificationService));
      });
    },
  );
}

Future<void> _configureStartupNotifications(
  NotificationService notificationService,
) async {
  try {
    await notificationService.init();
    final prefs = await SharedPreferences.getInstance();
    final saturdayReminderEnabled =
        prefs.getBool('stock_tasks_saturday_reminder_enabled') ?? true;
    if (saturdayReminderEnabled) {
      await notificationService.scheduleSaturdayReminder();
    } else {
      await notificationService.cancelSaturdayReminder();
    }
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'startup',
        context: ErrorDescription('while configuring notification reminders'),
      ),
    );
  }
}

class _AuthenticatedHomePage extends StatefulWidget {
  const _AuthenticatedHomePage({required this.signupCompletionService});

  final LandingSignupCompletionService signupCompletionService;

  @override
  State<_AuthenticatedHomePage> createState() => _AuthenticatedHomePageState();
}

class _AuthenticatedHomePageState extends State<_AuthenticatedHomePage> {
  late final Future<bool> _showOnboardingFuture = _shouldShowOnboarding();

  Future<bool> _shouldShowOnboarding() async {
    try {
      final user = supabase.auth.currentUser;
      final userId = user?.id;
      if (userId == null) return false;
      unawaited(
        widget.signupCompletionService.completeIfPending(
          signupUserId: userId,
          signupEmail: user?.email,
          accountCreatedAt: DateTime.tryParse(user?.createdAt ?? ''),
        ),
      );
      final response = await supabase
          .from('user_stats')
          .select('metadata')
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return true;
      final metadata = response['metadata'] as Map<String, dynamic>?;
      return metadata?['onboarding_completed'] != true;
    } catch (error) {
      debugPrint('Onboarding status check failed: $error');
      // A temporary read failure must not drop a newly registered user into
      // the full Home surface before they receive the first-value flow.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _showOnboardingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return (snapshot.data ?? false)
            ? const OnboardingPage()
            : const HomePage();
      },
    );
  }
}

String _initialRouteName() {
  final uri = Uri.base;
  if (uri.path.isNotEmpty && uri.path != '/') {
    final path = normalizeRoutePath(uri.path);
    return uri.hasQuery ? '$path?${uri.query}' : path;
  }
  if (uri.fragment.startsWith('/')) {
    return uri.fragment;
  }
  return Navigator.defaultRouteName;
}

/// アプリ全ての named route を生成する単一エントリポイント。
///
/// 出口は必ず [ensureRouteAnnouncesUrl] に通す (下の `onGenerateRoute` 参照)。
/// そのため各 case は `settings:` を書かなくてもブラウザ URL が更新される。
/// 例外は「表示する画面と違う URL を名乗りたい」case だけで、そこは明示的に
/// `settings:` を渡す (wrapper は名前付き route をそのまま尊重する)。
Route<dynamic> generateAppRoute(
  RouteSettings settings, {
  required LandingSignupCompletionService signupCompletionService,
}) {
  final uri = Uri.parse(settings.name ?? '/');
  final routePath = normalizeRoutePath(uri.path);
  // 全ての named route 遷移を利用履歴に記録する単一チョークポイント。
  // 主要導線の直叩き pushNamed が記録されず、最近使った / よく使われる
  // 機能が「サイト案内AI」しか並ばなかった機能不全 (#3279) を解消する。
  recordFeatureRouteNavigation(settings.name);

  switch (routePath) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => supabase.auth.currentSession != null
            ? _AuthenticatedHomePage(
                signupCompletionService: signupCompletionService,
              )
            : LandingPage(
                signupCompletionService: signupCompletionService,
              ),
      );
    case '/login':
      return MaterialPageRoute(
        builder: (_) => LandingPage(
          signupCompletionService: signupCompletionService,
        ),
      );
    case '/agi-fireworks':
      return MaterialPageRoute(
        builder: (_) => const AgiFireworksPage(),
        settings: settings,
      );
    case '/shop':
      return MaterialPageRoute(
        builder: (_) => const DigitalProductStorePage(),
        settings: settings,
      );
    case '/shop/product':
      return MaterialPageRoute(
        builder: (_) => DigitalProductPage(
          productId: uri.queryParameters['product_id'] ?? '',
          purchaseResult: uri.queryParameters['purchase'],
          funnel: ShopFunnelService(),
        ),
        settings: settings,
      );
    case '/shop/downloads':
      return MaterialPageRoute(
        builder: (_) => const ShopDownloadsPage(),
        settings: settings,
      );
    // 既存の共有URL・Stripe戻りURLを壊さない後方互換ルート。
    case '/shop/hexciv':
      return MaterialPageRoute(
        builder: (_) => HexcivShopPage(
          purchaseResult: uri.queryParameters['purchase'],
          // 計測 (2026-07-29 追加)。閲覧・購入ボタン押下・Checkout 到達を数える。
          // ここを渡し忘れると計測だけが黙って止まるので、route に直書きする。
          funnel: ShopFunnelService(),
        ),
        settings: settings,
      );
    case '/home':
      return MaterialPageRoute(builder: (_) => const HomePage());
    case '/agents':
      return MaterialPageRoute(builder: (_) => AgentOrgPage());
    // ホームカタログ (home_tool_catalog.dart) は `/autonomous-ops-console` で
    // 開くため、その URL でもリロード/共有が復元できるよう別名も登録する。
    case '/autonomous-ops':
    case '/autonomous-ops-console':
      return MaterialPageRoute(
        builder: (_) => const AutonomousOpsConsolePage(),
        settings: settings,
      );
    case '/agent-board':
      return MaterialPageRoute(
        builder: (_) => const AgentBoardPage(),
        settings: const RouteSettings(name: '/agent-board'),
      );
    case '/ai-company-builder':
      return MaterialPageRoute(
        builder: (_) => const AiCompanyBuilderPage(),
      );
    case '/my-ai-agent':
      return MaterialPageRoute(builder: (_) => const AiAgentPage());
    case '/ai-university-ranking':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityRankingPage(),
      );
    case '/ai-university-voice':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityVoicePage(),
      );
    case '/content-dubbing':
      return MaterialPageRoute(
        builder: (_) => const ContentDubbingPage(),
        settings: settings,
      );
    case '/ai-university-video':
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AiUniversityVideoPage(
          initialProvider: args?['provider'] as String?,
          initialCategory: args?['category'] as String?,
        ),
      );
    case '/ai-university-toeic':
      return MaterialPageRoute(
        builder: (_) => const ToeicFeature(),
        settings: settings,
      );
    case '/ai-university':
    case '/gemini-university':
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AiUniversityPage(
          initialProviderId: args?['provider'] as String?,
        ),
      );
    case '/danshari':
    case '/digital-danshari':
      return MaterialPageRoute(builder: (_) => const DanshariPage());
    case '/memory-drill':
      return MaterialPageRoute(builder: (_) => const MemoryDrillPage());
    case '/digest-queue':
    case '/wip-limit':
      return MaterialPageRoute(builder: (_) => const DigestQueuePage());
    case '/growth-mission':
      return MaterialPageRoute(
        builder: (_) => const GrowthMissionPage(),
        settings: const RouteSettings(name: '/growth-mission'),
      );
    case '/referral':
    case '/referral-program':
      return MaterialPageRoute(
        builder: (_) => const ReferralPage(),
        settings: RouteSettings(name: settings.name),
      );
    case '/import':
      return MaterialPageRoute(builder: (_) => const ImportPage());
    case '/public-memos':
      return MaterialPageRoute(
        builder: (_) => const PublicMemoDirectoryPage(),
      );
    case '/public-memo':
      final memoId = int.tryParse(uri.queryParameters['id'] ?? '');
      if (memoId == null) {
        return MaterialPageRoute(
          builder: (_) => const PublicMemoDirectoryPage(),
        );
      }
      return MaterialPageRoute(
        builder: (_) => PublicMemoDetailPage(memoId: memoId),
        settings: RouteSettings(name: settings.name),
      );
    case '/manual':
    case '/user-manual':
      return MaterialPageRoute(
        builder: (_) => const UserManualPage(),
        settings: settings,
      );
    case '/site-guide-ai':
      final argumentQuestion =
          settings.arguments is String ? settings.arguments as String : null;
      final queryQuestion = uri.queryParameters['q'];
      final initialQuestion = argumentQuestion ?? queryQuestion;
      final sectionNamesById = <String, String>{
        for (final section in homeToolSections) section.id: section.title,
        'ai': 'AI',
      };
      final toolCatalog = buildHomeToolCatalog().map((entry) {
        return SiteGuideActionEntry(
          item: SiteGuideCatalogItem(
            id: entry.id,
            sectionId: entry.sectionId,
            sectionTitle: sectionNamesById[entry.sectionId] ?? entry.sectionId,
            title: entry.title,
            subtitle: entry.subtitle,
            keywords: entry.keywords,
          ),
          onOpen: entry.onOpen,
        );
      }).toList();
      return MaterialPageRoute(
        builder: (_) => SiteGuideChatPage(
          initialQuestion: initialQuestion,
          toolCatalog: toolCatalog,
        ),
        settings: RouteSettings(
          name: settings.name,
          arguments: initialQuestion,
        ),
      );
    case '/edge-llm-playground':
      return MaterialPageRoute(
        builder: (_) => const EdgeLlmPlaygroundPage(),
        settings: settings,
      );
    case '/philosophy':
      final initialStep = uri.queryParameters['step'] == 'quick-inventory'
          ? PhilosophyInitialStep.quickInventory
          : PhilosophyInitialStep.overview;
      return MaterialPageRoute(
        builder: (_) => PhilosophyPage(initialStep: initialStep),
        settings: settings,
      );
    case '/privacy':
      return MaterialPageRoute(
        builder: (_) => const PrivacyPolicyPage(),
        settings: const RouteSettings(name: '/privacy'),
      );
    case '/tokusho':
      return MaterialPageRoute(
        builder: (_) => const LegalDocumentPage(
          assetPath: 'assets/legal/tokushoho.md',
          appBarTitle: '特定商取引法に基づく表記',
          heading: 'Commercial Transaction Act',
        ),
        settings: const RouteSettings(name: '/tokusho'),
      );
    case '/terms':
      return MaterialPageRoute(
        builder: (_) => const LegalDocumentPage(
          assetPath: 'assets/legal/terms.md',
          appBarTitle: '利用規約',
          heading: 'Terms of Service',
        ),
        settings: const RouteSettings(name: '/terms'),
      );
    case '/ai-dev-principles':
      return MaterialPageRoute(
        builder: (_) => const AiDevPrinciplesPage(),
        settings: settings,
      );
    case '/behavior-review':
      return MaterialPageRoute(builder: (_) => BehaviorReviewPage());
    case '/reality-check':
      return MaterialPageRoute(builder: (_) => const RealityCheckPage());
    case '/thought-anchor':
      return MaterialPageRoute(builder: (_) => const ThoughtAnchorPage());
    case '/morning-briefing':
      return MaterialPageRoute(
        builder: (_) => const MorningBriefingPage(),
      );
    case '/note-editor':
      return MaterialPageRoute(builder: (_) => const NoteEditorPage());
    case '/blog':
      return MaterialPageRoute(builder: (_) => const BlogPage());
    case '/blog/compose':
      return MaterialPageRoute(
        builder: (_) => const BlogComposePage(),
        settings: settings,
      );
    case '/blog/post':
      return MaterialPageRoute(
        builder: (_) => const PublicBlogPostPage(),
        settings: settings,
      );
    case '/tech-blog-tracker':
      return MaterialPageRoute(
        builder: (_) => const TechBlogTrackerPage(),
      );
    case '/ai-search':
      return MaterialPageRoute(builder: (_) => const AiSearchPage());
    case '/election-dashboard':
      return MaterialPageRoute(
        builder: (_) => const ElectionManagementDashboard(),
        settings: const RouteSettings(name: '/election-dashboard'),
      );
    case '/local-election-700':
    case '/local-election-schedule':
      return MaterialPageRoute(
        builder: (_) => ElectionVictoryPage(
          publicView: supabase.auth.currentSession == null,
        ),
        settings: RouteSettings(name: settings.name),
      );
    case '/public/local-election-700':
      return MaterialPageRoute(
        builder: (_) => const ElectionVictoryPage(publicView: true),
        settings: const RouteSettings(name: '/public/local-election-700'),
      );
    case '/home-insights':
      return MaterialPageRoute(
        builder: (_) => const HomeInsightsPage(),
        settings: const RouteSettings(name: '/home-insights'),
      );
    case '/work-menu':
      return MaterialPageRoute(
        builder: (_) => const WorkMenuPage(),
        settings: const RouteSettings(name: '/work-menu'),
      );
    case '/email-cleanup':
      return MaterialPageRoute(builder: (_) => const EmailCleanupPage());
    case '/local-smart-cleanup':
      return MaterialPageRoute(
        builder: (_) => const LocalSmartCleanupPage(),
      );
    case '/windows-app':
      return MaterialPageRoute(
        builder: (_) => const WindowsAppInstallPage(),
      );
    case '/payment-reminders':
      return MaterialPageRoute(
        builder: (_) => const PaymentReminderPage(),
      );
    case '/shopping-list':
      return MaterialPageRoute(builder: (_) => const ShoppingListPage());
    case '/daily-habits':
      return MaterialPageRoute(builder: (_) => const HabitCenterPage());
    case '/self-touch-tracker':
      return MaterialPageRoute(
        builder: (_) => SelfTouchTrackerPage(
          quickLogOnOpen: uri.queryParameters['action'] == 'quick_log',
        ),
        settings: RouteSettings(name: settings.name),
      );
    case '/abstinence-guard':
      return MaterialPageRoute(
        builder: (_) => const AbstinenceGuardPage(),
      );
    case '/my-struggle':
      return MaterialPageRoute(builder: (_) => const MyStrugglePage());
    case '/prison-mode':
      return MaterialPageRoute(builder: (_) => const PrisonModePage());
    case '/bookmark-folders':
      return MaterialPageRoute(
        builder: (_) => const BookmarkFoldersPage(),
      );
    case '/behavior-log':
      return MaterialPageRoute(builder: (_) => const BehaviorLogPage());
    case '/feature-requests':
      return MaterialPageRoute(
        builder: (_) => const FeatureRequestsPage(),
      );
    case '/profile-settings':
      return MaterialPageRoute(
        builder: (_) => const ProfileSettingsPage(),
      );
    case '/account-deletion':
      return MaterialPageRoute(
        builder: (_) => const AccountDeletionPage(),
        settings: const RouteSettings(name: '/account-deletion'),
      );
    case '/u':
      final userId = uri.queryParameters['id'] ?? '';
      if (userId.isEmpty) {
        return MaterialPageRoute(
          builder: (_) => LandingPage(
            signupCompletionService: signupCompletionService,
          ),
        );
      }
      return MaterialPageRoute(
        builder: (_) => PublicProfilePage(userId: userId),
        settings: RouteSettings(name: settings.name),
      );
    case '/vs-notion':
    case '/vs-evernote':
    case '/vs-moneyforward':
    case '/vs-slack':
    case '/vs-chatwork':
    case '/vs-x':
    case '/vs-animaworks':
    case '/vs-claude-code':
    case '/vs-codex':
    case '/vs-netkeiba':
    case '/vs-openclaw':
    case '/vs-claude-cowork':
    case '/vs-jobcan':
    case '/vs-amazon':
    case '/vs-google':
    case '/vs-discord':
    case '/vs-microsoft':
    case '/vs-line':
    case '/vs-facebook':
    case '/vs-liven':
    case '/vs-github':
      return MaterialPageRoute(
        builder: (_) => ComparisonPage(
          competitorKey: uri.path.replaceFirst('/vs-', ''),
        ),
      );
    case '/competitors':
      return MaterialPageRoute(
        builder: (_) => const CompetitorBrowsePage(),
        settings: const RouteSettings(name: '/competitors'),
      );
    case '/activity-feed':
      return MaterialPageRoute(builder: (_) => const ActivityFeedPage());
    case '/rewards':
    case '/stats':
      return MaterialPageRoute(builder: (_) => const RewardsPage());
    case '/life-goals':
      return MaterialPageRoute(builder: (_) => const GoalCenterPage());
    case '/thought-capture':
      return MaterialPageRoute(
        builder: (_) => const ThoughtCapturePage(),
      );
    case '/decision-check':
      return MaterialPageRoute(builder: (_) => const DecisionCheckPage());
    case '/eval-approval':
      return MaterialPageRoute(builder: (_) => const EvalApprovalPage());
    case '/purchase-log':
      return MaterialPageRoute(builder: (_) => const PurchaseLogPage());
    case '/price-tracker':
      return MaterialPageRoute(builder: (_) => const PriceTrackerPage());
    case '/process-quality-dashboard':
      return MaterialPageRoute(
        builder: (_) => const ProcessQualityDashboardPage(),
      );
    case '/ai-observability':
      return MaterialPageRoute(
        builder: (_) => const AiObservabilityPage(),
      );
    case '/ai-router-cost-dashboard':
      return MaterialPageRoute(
        builder: (_) => const AiRouterCostDashboardPage(),
      );
    case '/task-budget-assistant':
      return MaterialPageRoute(
        builder: (_) => const TaskBudgetAssistantPage(),
      );
    case '/agent-gpa-dashboard':
      return MaterialPageRoute(
        builder: (_) => const AgentGpaDashboardPage(),
      );
    case '/conveni-store':
      return MaterialPageRoute(builder: (_) => const ConveniStorePage());
    case '/edge-functions':
      return MaterialPageRoute(
        builder: (_) => const EdgeFunctionStatusPage(),
      );
    case '/admin':
    case '/admin/analytics':
      return MaterialPageRoute(
        builder: (_) => const AdminAnalyticsPage(),
        settings: settings,
      );
    case '/admin/artifact-publishing':
      return MaterialPageRoute(
        builder: (_) => const AdminArtifactPublishingPage(),
        settings: settings,
      );
    case '/templates':
      return MaterialPageRoute(
        builder: (_) => const TemplateMarketplacePage(),
      );
    case '/kanban':
      return MaterialPageRoute(builder: (_) => const KanbanBoardPage());
    case '/table-data':
      return MaterialPageRoute(builder: (_) => const TableDataPage());
    case '/ai-suggest-tags':
      return MaterialPageRoute(builder: (_) => const AiSuggestTagsPage());
    case '/analyze-reality':
      return MaterialPageRoute(
        builder: (_) => const AnalyzeRealityPage(),
      );
    case '/support-tickets':
      return MaterialPageRoute(
        builder: (_) => const SupportTicketsPage(),
      );
    case '/growth-achievement-summary':
      return MaterialPageRoute(
        builder: (_) => const GrowthAchievementSummaryPage(),
      );
    case '/growth-acquisition':
      return MaterialPageRoute(
        builder: (_) => const GrowthAcquisitionPage(),
      );
    case '/growth-acquisition-report':
      return MaterialPageRoute(
        builder: (_) => const GrowthAcquisitionReportPage(),
      );
    case '/growth-command-center':
      return MaterialPageRoute(
        builder: (_) => const GrowthCommandCenterPage(),
      );
    case '/growth-share-signal':
      return MaterialPageRoute(
        builder: (_) => const GrowthShareSignalPage(),
      );
    case '/growth-weekly-digest':
      return MaterialPageRoute(
        builder: (_) => const GrowthWeeklyDigestPage(),
      );
    case '/memo-reactions':
      return MaterialPageRoute(builder: (_) => const MemoReactionsPage());
    case '/note-comments':
      return MaterialPageRoute(builder: (_) => const NoteCommentsPage());
    case '/growth-acquisition-signal':
      return MaterialPageRoute(
        builder: (_) => const GrowthAcquisitionSignalPage(),
      );
    case '/compatibility':
      final myType = settings.arguments as String? ?? '';
      return MaterialPageRoute(
        builder: (_) => CompatibilityCheckPage(myType: myType),
      );
    case '/personality-test':
      final testId = settings.arguments as int? ?? 1;
      return MaterialPageRoute(
        builder: (_) => PersonalityTestQuestionsPage(testId: testId),
      );
    case '/personality-test-result':
      final resultTestId = settings.arguments as int? ?? 1;
      return MaterialPageRoute(
        builder: (_) => PersonalityTestResultPage(testId: resultTestId),
      );
    case '/iq-test':
      return MaterialPageRoute(builder: (_) => const IqTestPage());
    // 出題中のテストは testId と seed が無いと復元できない (再開もできない)。
    // 直接 URL で開かれた場合はハブへ落とす。
    case '/iq-test-questions':
      final iqQuestionsArgs = settings.arguments as IqTestSessionArgs?;
      if (iqQuestionsArgs == null) {
        return MaterialPageRoute(builder: (_) => const IqTestPage());
      }
      return MaterialPageRoute(
        builder: (_) => IqTestQuestionsPage(
          testId: iqQuestionsArgs.testId,
          questionSeed: iqQuestionsArgs.questionSeed,
        ),
      );
    case '/iq-test-result':
      final iqTestId = settings.arguments as int?;
      if (iqTestId == null) {
        return MaterialPageRoute(builder: (_) => const IqTestPage());
      }
      return MaterialPageRoute(
        builder: (_) => IqTestResultPage(testId: iqTestId),
      );
    case '/iq-training':
      return MaterialPageRoute(builder: (_) => const IqTrainingPage());
    // ドリルは対象領域とレベルが引数。無ければプラン画面へ落とす。
    case '/iq-training-drill':
      final iqDrillArgs = settings.arguments as IqTrainingDrillArgs?;
      if (iqDrillArgs == null) {
        return MaterialPageRoute(builder: (_) => const IqTrainingPage());
      }
      return MaterialPageRoute(
        builder: (_) => IqTrainingDrillPage(
          planId: iqDrillArgs.planId,
          category: iqDrillArgs.category,
          level: iqDrillArgs.level,
        ),
      );
    case '/enterprise':
      return MaterialPageRoute(builder: (_) => const EnterprisePage());
    case '/corporate-bank-account-cost':
      return MaterialPageRoute(
        builder: (_) => const CorporateBankAccountSimulatorPage(),
      );
    case '/corporate-site-readiness':
      return MaterialPageRoute(
        builder: (_) => const CorporateSiteReadinessPage(),
      );
    case '/ai-secretary':
      return MaterialPageRoute(builder: (_) => const AISecretaryPage());
    case '/team-workspace':
      return MaterialPageRoute(builder: (_) => const TeamWorkspacePage());
    case '/embedding-lab':
      return MaterialPageRoute(builder: (_) => const EmbeddingLabPage());
    case '/settings':
      return MaterialPageRoute(builder: (_) => const SettingsPage());
    case '/settings/ai-form-assistant':
      return MaterialPageRoute(
        builder: (_) => supabase.auth.currentSession == null
            ? LandingPage(
                signupCompletionService: signupCompletionService,
              )
            : const AiFormAssistantPage(),
      );
    case '/settings/theme':
      return MaterialPageRoute(builder: (_) => const ThemeSelectorPage());
    case '/health':
      return MaterialPageRoute(builder: (_) => const HealthPage());
    case '/mental-check':
      return MaterialPageRoute(builder: (_) => const MentalCheckPage());
    case '/feedback':
      return MaterialPageRoute(builder: (_) => const FeedbackPage());
    case '/admin-feedback':
      return MaterialPageRoute(builder: (_) => const FeedbackListPage());
    case '/quota-dashboard':
      return MaterialPageRoute(
        builder: (_) => const QuotaDashboardPage(),
      );
    case '/admin/maintenance':
      return MaterialPageRoute(
        builder: (_) => const MaintenanceManagementPage(),
      );
    case '/maintenance':
      return MaterialPageRoute(
        builder: (_) => const MaintenanceModePage(),
      );
    case '/blog-management':
      return MaterialPageRoute(
        builder: (_) => const BlogManagementPage(),
      );
    case '/admin/blog/new':
      return MaterialPageRoute(
        builder: (_) => const BlogDraftEditorPage(),
      );
    case '/admin/blog/edit':
      final postId = settings.arguments as String?;
      return MaterialPageRoute(
        builder: (_) => BlogDraftEditorPage(postId: postId),
      );
    case '/ai-assistant-chat':
      final arguments = settings.arguments is Map
          ? Map<String, dynamic>.from(settings.arguments! as Map)
          : const <String, dynamic>{};
      final contextIds = (arguments['context_file_ids'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[];
      final contextTitles = (arguments['context_titles'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[];
      return MaterialPageRoute(
        builder: (_) => AiAssistantChatPage(
          initialContextIds: contextIds,
          initialContextTitles: contextTitles,
        ),
      );
    case '/categories':
      return MaterialPageRoute(builder: (_) => const CategoriesPage());
    case '/medical-notes':
      return MaterialPageRoute(builder: (_) => const MedicalNotesPage());
    case '/api-playground':
      return MaterialPageRoute(builder: (_) => const ApiPlaygroundPage());
    case '/financial-report':
      return MaterialPageRoute(
        builder: (_) => const FinancialReportPage(),
      );
    case '/payment-channel-ledger':
      return MaterialPageRoute(
        builder: (_) => const PaymentChannelLedgerPage(),
      );
    case '/emergency-meeting':
      return MaterialPageRoute(
        builder: (_) => const EmergencyMeetingPage(),
      );
    case '/ai-status':
      return MaterialPageRoute(builder: (_) => const AiStatusPage());
    case '/tiger-review-status':
      return MaterialPageRoute(
        builder: (_) => const TigerReviewHubPage(),
        settings: const RouteSettings(name: TigerReviewHubPage.routeName),
      );
    case '/tiger-reviewers':
      return MaterialPageRoute(
        builder: (_) => const TigerReviewLaneStatusPage(
          kind: TigerReviewLane.reviewers,
        ),
        settings: const RouteSettings(name: '/tiger-reviewers'),
      );
    case '/tiger-site-reviews':
      return MaterialPageRoute(
        builder: (_) => const TigerReviewLaneStatusPage(
          kind: TigerReviewLane.site,
        ),
        settings: const RouteSettings(name: '/tiger-site-reviews'),
      );
    case '/tiger-course-reviews':
      return MaterialPageRoute(
        builder: (_) => const TigerReviewLaneStatusPage(
          kind: TigerReviewLane.courses,
        ),
        settings: const RouteSettings(name: '/tiger-course-reviews'),
      );
    case '/tiger-feature-reviews':
      return MaterialPageRoute(
        builder: (_) => const TigerReviewLaneStatusPage(
          kind: TigerReviewLane.features,
        ),
        settings: const RouteSettings(name: '/tiger-feature-reviews'),
      );
    case '/ai-provider-status':
      return MaterialPageRoute(
        builder: (_) => const AiProviderStatusPage(),
      );
    case '/note-list':
    case '/notes':
      // Win版#110: feature_releases から「ノート」deep link
      return MaterialPageRoute(
        builder: (_) => const NoteListPage(),
        settings: settings,
      );
    case '/asset-management':
      return MaterialPageRoute(
        builder: (_) => const AssetManagementPage(),
      );
    case '/asset-chat-history':
      return MaterialPageRoute(
        builder: (_) => const AssetChatHistoryPage(),
      );
    case '/cfo-office':
      return MaterialPageRoute(builder: (_) => const CfoOfficePage());
    case '/cho-office':
      return MaterialPageRoute(builder: (_) => const ChoOfficePage());
    case '/chro-office':
      return MaterialPageRoute(builder: (_) => const ChroOfficePage());
    case '/cmo-office':
      return MaterialPageRoute(builder: (_) => const CmoOfficePage());
    case '/cmo':
      return MaterialPageRoute(builder: (_) => const CmoPage());
    case '/election-strategy':
      return MaterialPageRoute(
        builder: (_) => const ElectionStrategyPage(),
      );
    case '/mind-map':
      return MaterialPageRoute(builder: (_) => const MindMapPage());
    case '/mindless-task':
      return MaterialPageRoute(builder: (_) => const MindlessTaskPage());
    case '/real-world-danshari':
      return MaterialPageRoute(
        builder: (_) => RealWorldDanshariPage(supabaseClient: supabase),
      );
    case '/stock-tasks':
      return MaterialPageRoute(builder: (_) => const StockTasksPage());
    case '/wardrobe':
      return MaterialPageRoute(builder: (_) => const WardrobePage());
    case '/knowledge-base':
      return MaterialPageRoute(builder: (_) => const KnowledgeBasePage());
    case '/semantic-search':
      return MaterialPageRoute(
        builder: (_) => const SemanticSearchPage(),
      );
    case '/mcp-file-search':
      return MaterialPageRoute(builder: (_) => const McpFileSearchPage());
    case '/musubi':
    case '/social-feed':
      return MaterialPageRoute(builder: (_) => const SocialFeedPage());
    case '/sobriety-campaign':
      return MaterialPageRoute(
        builder: (_) => const SobrietyCampaignPage(),
      );
    case '/notifications':
      return MaterialPageRoute(builder: (_) => const NotificationsPage());
    case '/meeting-manager':
      return MaterialPageRoute(
        builder: (_) => const MeetingManagerPage(),
      );
    case '/news-rss':
      return MaterialPageRoute(
        builder: (_) => const NewsRssAggregatorPage(),
      );
    case '/market-intelligence':
      return MaterialPageRoute(
        builder: (_) => const MarketIntelligencePage(),
      );
    case '/smart-inbox':
      return MaterialPageRoute(
        builder: (_) => const SmartInboxTriagePage(),
      );
    case '/carbon-footprint':
      return MaterialPageRoute(
        builder: (_) => const CarbonFootprintTrackerPage(),
      );
    case '/donation':
      return MaterialPageRoute(
        builder: (_) => const DonationCrowdfundingPage(),
      );
    case '/emergency-contacts':
      return MaterialPageRoute(
        builder: (_) => const EmergencyContactsPage(),
      );
    case '/family-sharing':
      return MaterialPageRoute(
        builder: (_) => const FamilySharingManagerPage(),
      );
    case '/gift-registry':
      return MaterialPageRoute(builder: (_) => const GiftRegistryPage());
    case '/mindmap':
      return MaterialPageRoute(
        builder: (_) => const MindmapDiagramPage(),
      );
    case '/auction-marketplace':
      return MaterialPageRoute(
        builder: (_) => const AuctionMarketplacePage(),
      );
    case '/qr-code-generator':
      return MaterialPageRoute(
        builder: (_) => const QrCodeGeneratorPage(),
      );
    case '/parking-reservation':
      return MaterialPageRoute(
        builder: (_) => const ParkingReservationPage(),
      );
    case '/analytics-export':
      return MaterialPageRoute(
        builder: (_) => const AnalyticsExportPage(),
      );
    case '/workflow-templates':
      return MaterialPageRoute(
        builder: (_) => const WorkflowTemplatesPage(),
      );
    case '/customer-feedback':
      return MaterialPageRoute(
        builder: (_) => const CustomerFeedbackPage(),
      );
    case '/address-book':
      return MaterialPageRoute(builder: (_) => const AddressBookPage());
    case '/subscription-billing':
      return MaterialPageRoute(
        builder: (_) => SubscriptionBillingPage(initialUri: uri),
      );
    case '/billing':
      return MaterialPageRoute(
        builder: (_) => SubscriptionBillingPage(initialUri: uri),
      );
    case '/appointment-scheduler':
      return MaterialPageRoute(
        builder: (_) => const AppointmentSchedulerPage(),
      );
    case '/budget-financial-planner':
      return MaterialPageRoute(
        builder: (_) => const BudgetFinancialPlannerPage(),
      );
    case '/feature-flags':
      return MaterialPageRoute(builder: (_) => const FeatureFlagsPage());
    case '/workflow-automation':
      return MaterialPageRoute(
        builder: (_) => const WorkflowAutomationPage(),
      );
    case '/social-scheduler':
    case '/social-media-scheduler':
      return MaterialPageRoute(
        builder: (_) => const SocialMediaSchedulerPage(),
      );
    case '/video-meeting':
      return MaterialPageRoute(builder: (_) => const VideoMeetingPage());
    case '/krisp-audio-quality':
      return MaterialPageRoute(
        builder: (_) => const KrispAudioQualityPage(),
      );
    case '/gantt-timeline':
      return MaterialPageRoute(builder: (_) => const GanttTimelinePage());
    case '/ai-image-generator':
      return MaterialPageRoute(
        builder: (_) => const AiImageGeneratorPage(),
      );
    case '/viral-ad-campaign':
      return MaterialPageRoute(
        builder: (_) => const ViralAdCampaignPage(),
      );
    case '/virtual-pet':
      return MaterialPageRoute(builder: (_) => const VirtualPetPage());
    case '/affiliate-marketing':
      return MaterialPageRoute(
        builder: (_) => const AffiliateMarketingPage(),
      );
    case '/calendar-events':
      return MaterialPageRoute(
        builder: (_) => const CalendarEventsPage(),
      );
    case '/expense-tracker':
      return MaterialPageRoute(
        builder: (_) => const ExpenseTrackerPage(),
      );
    case '/reading-list':
      return MaterialPageRoute(builder: (_) => const ReadingListPage());
    case '/ar-navigation':
      return MaterialPageRoute(builder: (_) => const ArNavigationPage());
    case '/dns-domain-manager':
      return MaterialPageRoute(
        builder: (_) => const DnsDomainManagerPage(),
      );
    case '/focus-timer':
    case '/pomodoro-timer':
      return MaterialPageRoute(builder: (_) => const FocusTimerPage());
    case '/digital-wallet':
      return MaterialPageRoute(builder: (_) => const DigitalWalletPage());
    case '/loyalty-points':
      return MaterialPageRoute(builder: (_) => const LoyaltyPointsPage());
    case '/viral-ad-generator':
    case '/video-ad-generator':
    case '/viral-video-generator':
      return MaterialPageRoute(
        builder: (_) => const ViralAdGeneratorPage(),
      );
    case '/growth-automation':
      return MaterialPageRoute(
        builder: (_) => const GrowthAutomationControllerPage(),
      );
    case '/landing-ab-test':
      return MaterialPageRoute(builder: (_) => const LandingAbTestPage());
    case '/sound-bloom':
      return MaterialPageRoute(
        builder: (_) => const SoundBloomPage(),
        settings: settings,
      );
    case '/aero-lab':
      return MaterialPageRoute(
        builder: (_) => const AeroLabPage(),
        settings: settings,
      );
    case '/video-studio':
      return MaterialPageRoute(
        builder: (_) => VideoStudioFeature(initialUri: uri),
        settings: RouteSettings(name: settings.name),
      );
    case '/notion-migration':
      return MaterialPageRoute(
        builder: (_) => const NotionMigrationFeature(),
        settings: RouteSettings(name: settings.name),
      );
    case '/youtube-stats':
      return MaterialPageRoute(builder: (_) => const YoutubeStatsPage());
    case '/audio-effects-processor':
      return MaterialPageRoute(
        builder: (_) => const AudioEffectsProcessorPage(),
      );
    case '/guitar-recording-studio':
      return MaterialPageRoute(
        builder: (_) => const GuitarRecordingStudioPage(),
      );
    case '/beatles-guitar-tabs':
      return MaterialPageRoute(
        builder: (_) => const BeatlesGuitarTabsFeature(),
      );
    case '/public-guitar-gallery':
      return MaterialPageRoute(
        builder: (_) => const PublicGuitarGalleryPage(),
      );
    case '/music-collaboration':
      return MaterialPageRoute(
        builder: (_) => const MusicCollaborationPage(),
      );
    case '/form-builder':
      return MaterialPageRoute(builder: (_) => const FormBuilderPage());
    case '/event-ticketing':
      return MaterialPageRoute(
        builder: (_) => const EventTicketingPage(),
      );
    case '/music-playlist-manager':
      return MaterialPageRoute(
        builder: (_) => const MusicPlaylistManagerPage(),
      );
    case '/fitness-health-tracker':
      return MaterialPageRoute(
        builder: (_) => const FitnessHealthTrackerPage(),
      );
    case '/virtual-organization':
      return MaterialPageRoute(
        builder: (_) => const VirtualOrganizationPage(),
      );
    case '/ai-writing-assistant':
      return MaterialPageRoute(
        builder: (_) => const WritingCenterPage(),
      );
    case '/wiki-database':
      return MaterialPageRoute(builder: (_) => const WikiDatabasePage());
    case '/time-tracker':
      return MaterialPageRoute(builder: (_) => const TimeTrackerPage());
    case '/voice-memo':
      return MaterialPageRoute(
        builder: (_) => const VoiceMemoTranscriberPage(),
      );
    case '/crm-pipeline':
      return MaterialPageRoute(
        builder: (_) => const CrmSalesPipelinePage(),
      );
    case '/horse-racing':
    case '/horse-racing/today':
    case '/horse-racing/predictions':
      return MaterialPageRoute(
        builder: (_) => const HorseRacingPredictorPage(),
        settings: RouteSettings(name: settings.name),
      );
    case '/horse-racing/history':
    case '/horse-racing/prediction-history':
      return MaterialPageRoute(
        builder: (_) => const HorseRacingPredictorPage(initialTabIndex: 1),
        settings: RouteSettings(name: settings.name),
      );
    case '/horse-racing/analysis':
    case '/horse-racing/accuracy':
    case '/horse-racing-analysis':
    case '/horse-racing-analytics':
      return MaterialPageRoute(
        builder: (_) => const HorseRacingPredictorPage(initialTabIndex: 2),
        settings: RouteSettings(name: settings.name),
      );
    case '/horse-racing/bets':
    case '/horse-racing/tickets':
    case '/horse-racing-bets':
      return MaterialPageRoute(
        builder: (_) => const HorseRacingPredictorPage(initialTabIndex: 3),
        settings: RouteSettings(name: settings.name),
      );
    case '/horse-provider-leaderboard':
      return MaterialPageRoute(
        builder: (_) => const HorseProviderLeaderboardPage(),
      );
    case '/travel-itinerary':
    case '/travel-planner':
      return MaterialPageRoute(
        builder: (_) => const TravelItineraryPage(),
      );
    case '/art-museums':
      return MaterialPageRoute(
        builder: (_) => const ArtMuseumDirectoryPage(),
        settings: settings,
      );
    case '/virtual-whiteboard':
      return MaterialPageRoute(
        builder: (_) => const VirtualWhiteboardPage(),
      );
    case '/meal-log':
      return MaterialPageRoute(builder: (_) => const MealLogPage());
    case '/life-goals-kpi':
      return MaterialPageRoute(builder: (_) => const LifeGoalsKpiPage());
    case '/recipe-meal-planner':
      return MaterialPageRoute(
        builder: (_) => const RecipeMealPlannerPage(),
      );
    case '/language-learning':
      return MaterialPageRoute(
        builder: (_) => const LanguageLearningPage(),
      );
    case '/spreadsheet-database':
      return MaterialPageRoute(
        builder: (_) => const SpreadsheetDatabasePage(),
      );
    case '/changelog':
      return MaterialPageRoute(
        builder: (_) => const ChangelogManagerPage(),
      );
    case '/release-notes':
      return MaterialPageRoute(builder: (_) => const ReleaseNotesPage());
    case '/pet-care':
      return MaterialPageRoute(
        builder: (_) => const PetCareManagerPage(),
      );
    case '/photo-gallery':
      return MaterialPageRoute(
        builder: (_) => const PhotoGalleryManagerPage(),
      );
    case '/elearning':
      return MaterialPageRoute(
        builder: (_) => const ElearningCourseManagerPage(),
      );
    case '/document-esignature':
      return MaterialPageRoute(
        builder: (_) => const DocumentEsignaturePage(),
      );
    case '/vehicle-fleet':
      return MaterialPageRoute(
        builder: (_) => const VehicleFleetManagerPage(),
      );
    case '/recruitment':
      return MaterialPageRoute(
        builder: (_) => const RecruitmentJobBoardPage(),
      );
    case '/habit-gamification':
      return MaterialPageRoute(
        builder: (_) => const HabitCenterPage(
          initialSection: HabitCenterSection.rewards,
        ),
      );
    case '/focus-capture':
      return MaterialPageRoute(
        builder: (_) => const FocusCaptureGamePage(),
      );
    case '/code-playground':
      return MaterialPageRoute(
        builder: (_) => const CodePlaygroundPage(),
      );
    case '/real-estate':
      return MaterialPageRoute(
        builder: (_) => const RealEstateTrackerPage(),
      );
    case '/local-business-map':
      return MaterialPageRoute(
        builder: (_) => const LocalBusinessMapFeature(),
      );
    case '/home-iot':
      return MaterialPageRoute(
        builder: (_) => const HomeIotManagerPage(),
      );
    case '/legal-compliance':
      return MaterialPageRoute(
        builder: (_) => const LegalComplianceManagerPage(),
      );
    case '/email-templates':
      return MaterialPageRoute(
        builder: (_) => const EmailTemplateBuilderPage(),
      );
    case '/two-factor-auth':
      return MaterialPageRoute(builder: (_) => const TwoFactorAuthPage());
    case '/inventory-barcode':
      return MaterialPageRoute(
        builder: (_) => const InventoryBarcodePage(),
      );
    case '/password-vault':
      return MaterialPageRoute(builder: (_) => const PasswordVaultPage());
    case '/podcast-manager':
      return MaterialPageRoute(
        builder: (_) => const PodcastManagerPage(),
      );
    case '/screen-recorder':
      return MaterialPageRoute(
        builder: (_) => const ScreenRecorderPage(),
      );
    case '/sitemap-analytics':
      return MaterialPageRoute(
        builder: (_) => const SitemapAnalyticsPage(),
      );
    case '/access-control':
      return MaterialPageRoute(builder: (_) => const AccessControlPage());
    case '/personal-dashboard':
      return MaterialPageRoute(
        builder: (_) => const PersonalDashboardPage(),
      );
    case '/procrastination-reset':
      return MaterialPageRoute(
        builder: (_) => const ProcrastinationResetFeature(),
        settings: const RouteSettings(
          name: ProcrastinationResetFeature.routeName,
        ),
      );
    case '/proactive-form-check':
      return MaterialPageRoute(
        builder: (_) => const ProactiveFormCheckFeature(),
        settings: const RouteSettings(
          name: ProactiveFormCheckFeature.routeName,
        ),
      );
    case '/my-skills':
      return MaterialPageRoute(builder: (_) => const MySkillsPage());
    case '/goal-tracker':
      return MaterialPageRoute(
        builder: (_) => const GoalCenterPage(
          initialSection: GoalCenterSection.legacyGoals,
        ),
      );
    case '/career-monthly-kpi':
      return MaterialPageRoute(
        builder: (_) => const CareerMonthlyKpiPage(),
      );
    case '/bookmark-sync':
      return MaterialPageRoute(builder: (_) => const BookmarkSyncPage());
    case '/integration-registry':
      return MaterialPageRoute(
        builder: (_) => const IntegrationRegistryPage(),
        settings: const RouteSettings(name: '/integration-registry'),
      );
    case '/jibun-api':
      return MaterialPageRoute(
        builder: (_) => const JibunApiPage(),
        settings: RouteSettings(name: settings.name),
      );
    case '/ui-design-status':
      return MaterialPageRoute(
        builder: (_) => const UiDesignStatusPage(),
        settings: const RouteSettings(name: '/ui-design-status'),
      );
    case '/ai-summarizer':
      return MaterialPageRoute(
        builder: (_) => const WritingCenterPage(
          initialSection: WritingCenterSection.summaries,
        ),
        settings: const RouteSettings(name: '/ai-summarizer'),
      );
    case '/revenue-forecaster':
      return MaterialPageRoute(
        builder: (_) => const RevenueForecasterPage(),
        settings: const RouteSettings(name: '/revenue-forecaster'),
      );
    case '/weather-widget':
      return MaterialPageRoute(
        builder: (_) => const WeatherWidgetPage(),
        settings: const RouteSettings(name: '/weather-widget'),
      );
    case '/google-calendar-sync':
      return MaterialPageRoute(
        builder: (_) => const GoogleCalendarSyncPage(),
      );
    case '/money-forward':
      return MaterialPageRoute(builder: (_) => const MoneyForwardPage());
    case '/weekly-slip-report':
      return MaterialPageRoute(
        builder: (_) => const WeeklySlipReportPage(),
      );
    case '/discord-notifications':
      return MaterialPageRoute(
        builder: (_) => const DiscordNotificationPage(),
      );
    case '/line-notifications':
      return MaterialPageRoute(
        builder: (_) => const LineNotificationPage(),
      );
    case '/github-pr':
      return MaterialPageRoute(builder: (_) => const GithubPrPage());
    case '/slack-notifications':
      return MaterialPageRoute(
        builder: (_) => const SlackNotificationPage(),
      );
    case '/team-chat':
      return MaterialPageRoute(builder: (_) => const TeamChatPage());
    case '/health-coach':
      return MaterialPageRoute(builder: (_) => const HealthCoachPage());
    case '/thought-interrupt-diagnosis':
      return MaterialPageRoute(
        builder: (_) => const ThoughtInterruptDiagnosisPage(),
      );
    case '/mental-health-tracker':
      return MaterialPageRoute(
        builder: (_) => const MentalHealthTrackerPage(),
      );
    case '/freelance-manager':
      return MaterialPageRoute(
        builder: (_) => const FreelanceManagerPage(),
      );
    case '/ai-presentation-builder':
      return MaterialPageRoute(
        builder: (_) => const AiPresentationBuilderPage(),
      );
    case '/tome-deck-studio':
      return MaterialPageRoute(
        builder: (_) => const TomeDeckStudioPage(),
      );
    case '/data-backup':
      return MaterialPageRoute(builder: (_) => const DataBackupPage());
    case '/content-calendar':
      return MaterialPageRoute(
        builder: (_) => const ContentCalendarPage(),
      );
    case '/home-budget-planner':
      return MaterialPageRoute(
        builder: (_) => const HomeBudgetPlannerPage(),
      );
    case '/brain-dump':
      return MaterialPageRoute(builder: (_) => const BrainDumpPage());
    case '/custom-task-list':
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/custom-task-list'),
        builder: (_) => const CustomTaskListPage(),
      );
    case '/project-gantt':
      return MaterialPageRoute(builder: (_) => const ProjectGanttPage());
    case '/user-tasks':
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/user-tasks'),
        builder: (_) => const UserTasksPage(),
      );
    case '/wbs-user-tasks':
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/wbs-user-tasks'),
        builder: (_) => const UserTasksPage(),
      );
    case '/business-card-manager':
      return MaterialPageRoute(
        builder: (_) => const BusinessCardManagerPage(),
      );
    case '/family-calendar':
      return MaterialPageRoute(
        builder: (_) => const FamilyCalendarPage(),
      );
    case '/app-hub':
      return MaterialPageRoute(builder: (_) => const AppHubPage());
    case '/agent-hub':
      return MaterialPageRoute(builder: (_) => const AgentHubPage());
    case '/admin-notifications':
      return MaterialPageRoute(
        builder: (_) => const AdminNotificationHubPage(),
      );
    case '/competitor-feature-sync':
      return MaterialPageRoute(
        builder: (_) => const CompetitorFeatureSyncPage(),
      );
    case '/daily-judgment':
      return MaterialPageRoute(builder: (_) => const DailyJudgmentPage());
    case '/ai-university-content':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityContentPage(),
      );
    case '/ai-university-faculty':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityFacultySelectPage(),
      );
    case '/ai-university-department':
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AiUniversityDepartmentSelectPage(
          facultyCode: args?['faculty_code'] as String? ?? '',
          facultyName: args?['faculty_name'] as String? ?? '',
          facultyEmoji: args?['faculty_emoji'] as String? ?? '🎓',
        ),
      );
    case '/development-achievements':
      return MaterialPageRoute(
        builder: (_) => const DevelopmentAchievementsPage(),
      );
    case '/invoice-generator':
      return MaterialPageRoute(
        builder: (_) => const InvoiceGeneratorPage(),
      );
    case '/poll-survey':
      return MaterialPageRoute(builder: (_) => const PollSurveyPage());
    case '/notification-digest':
      return MaterialPageRoute(
        builder: (_) => const NotificationDigestPage(),
      );
    case '/ai-university-badges':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityBadgesPage(),
      );
    case '/ai-university-streaks':
      return MaterialPageRoute(
        builder: (_) => const AiUniversityStreaksPage(),
      );
    case '/english-reading-curriculum':
      return MaterialPageRoute(
        builder: (_) => const EnglishReadingCurriculumPage(),
      );
    case '/english-reading-practice':
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => EnglishReadingPracticePage(
          lessonCode: args?['lesson_code'] as String?,
          mode: args?['mode'] as String? ?? 'measure',
        ),
      );
    case '/english-reading-dashboard':
      return MaterialPageRoute(
        builder: (_) => const EnglishReadingDashboardPage(),
      );
    case '/ai-workflow-automation':
      return MaterialPageRoute(
        builder: (_) => const AiWorkflowAutomationPage(),
      );
    case '/ab-testing-manager':
      return MaterialPageRoute(
        builder: (_) => const AbTestingManagerPage(),
      );
    case '/habit-tracker':
      return MaterialPageRoute(builder: (_) => const HabitTrackerPage());
    case '/agent-department-manager':
      return MaterialPageRoute(
        builder: (_) => const AgentDepartmentManagerPage(),
      );
    case '/agent-performance-monitor':
      return MaterialPageRoute(
        builder: (_) => const AgentPerformanceMonitorPage(),
      );
    case '/app-analytics-dashboard':
      return MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => supabase.auth.currentSession != null
            ? _AuthenticatedHomePage(
                signupCompletionService: signupCompletionService,
              )
            : LandingPage(
                signupCompletionService: signupCompletionService,
              ),
      );
    case '/deployment-monitoring':
      return MaterialPageRoute(
        builder: (_) => const DeploymentMonitoringSetupPage(),
      );
    case '/one-in-two-out':
    case '/one-in-two-out-assist':
      return MaterialPageRoute(
        builder: (_) => const OneInTwoOutAssistPage(),
        settings: RouteSettings(name: settings.name),
      );
    case '/dev/claude-design-importer':
      return MaterialPageRoute(
        builder: (_) => const ClaudeDesignImporterPage(),
      );
    case '/leave-management':
      return MaterialPageRoute(
        builder: (_) => const LeaveManagementPage(),
      );
    case '/performance-review':
      return MaterialPageRoute(
        builder: (_) => const PerformanceReviewPage(),
      );
    case '/health-check':
      return MaterialPageRoute(builder: (_) => const HealthCheckPage());
    case '/memory-search':
      return MaterialPageRoute(
        builder: (_) => const MemorySearchHubPage(),
      );
    case '/knowledge-graph':
      return MaterialPageRoute(
        builder: (_) => const KnowledgeGraphPage(),
        settings: const RouteSettings(name: '/knowledge-graph'),
      );
    case '/my-knowledge-graph':
      return MaterialPageRoute(
        builder: (_) => const UserKnowledgeGraphPage(),
        settings: const RouteSettings(name: '/my-knowledge-graph'),
      );
    case '/settings/ai-share-button':
      return MaterialPageRoute(
        builder: (_) => const AiShareButtonSettingsPage(),
      );
    case '/offline-secure-mode':
      return MaterialPageRoute(
        builder: (_) => const OfflineSecureModeSettingsPage(),
      );
    case '/cfo-cost-ledger':
      return MaterialPageRoute(
        builder: (_) => const CfoCostLedgerPage(),
      );
    case '/monthly-kpi-dashboard':
      return MaterialPageRoute(
        builder: (_) => const MonthlyKpiDashboardPage(),
      );
    case '/people-help':
      return MaterialPageRoute(
        builder: (_) => const PeopleHelpPage(),
      );
    case compatibilityResultRoutePath:
      // 診断結果は 2 つの型だけで再現できるので query に載せ、リロードや
      // 共有リンクからでも同じ画面に復元する。型が欠けていれば結果を描け
      // ないため診断入口へ落とし、URL もそちらに合わせる。
      final myType = uri.queryParameters[compatibilityResultMyTypeParam] ?? '';
      final partnerType =
          uri.queryParameters[compatibilityResultPartnerTypeParam] ?? '';
      if (myType.isEmpty || partnerType.isEmpty) {
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/compatibility'),
          builder: (_) => CompatibilityCheckPage(myType: myType),
        );
      }
      return MaterialPageRoute(
        builder: (_) => CompatibilityResultPage(
          myType: myType,
          partnerType: partnerType,
        ),
      );
    case '/horse-racing/race':
      // 出走表は race マップ全体が必要で URL だけでは復元できない。直リンク/
      // リロード時は復元元の予想一覧へ落とし、URL もそちらに合わせる。
      final race = settings.arguments as Map<String, dynamic>?;
      if (race == null) {
        return MaterialPageRoute(
          settings: const RouteSettings(name: '/horse-racing/predictions'),
          builder: (_) => const HorseRacingPredictorPage(),
        );
      }
      return MaterialPageRoute(
        builder: (_) => HorseracingRaceDetailPage(race: race),
      );
    default:
      if (routePath.startsWith('/vs-')) {
        return MaterialPageRoute(
          builder: (_) => ComparisonPage(
            competitorKey: routePath.replaceFirst('/vs-', ''),
          ),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (_) => LandingPage(
          signupCompletionService: signupCompletionService,
        ),
      );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.signupCompletionService = const LandingSignupCompletionService(),
  });

  final LandingSignupCompletionService signupCompletionService;

  static final SentryNavigatorObserver? _sentryNavigatorObserver =
      ErrorReporter.instance.sentryEnabled ? SentryNavigatorObserver() : null;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _versionCheckService = VersionCheckService();
  bool _showUpdateBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _versionCheckService.startPolling(() {
      if (mounted) setState(() => _showUpdateBanner = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 背面のタブに復帰した時に再確認 (バックグラウンド中にデプロイされた場合を検知)。
    if (state == AppLifecycleState.resumed) {
      unawaited(_versionCheckService.checkNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _versionCheckService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return ValueListenableBuilder(
      valueListenable: universalAiShareRouteObserver.currentPage,
      builder: (context, currentPage, _) => MaterialApp(
        title: documentTitleForRoute(currentPage.routePath),
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        navigatorKey: _navigatorKey,
        initialRoute: _initialRouteName(),
        theme: themeService.overrideTheme ?? themeService.getLightTheme(),
        darkTheme: themeService.overrideTheme ?? themeService.getDarkTheme(),
        themeMode: themeService.overrideTheme != null
            ? ThemeMode.light
            : themeService.getFlutterThemeMode(),
        builder: (context, child) {
          return GlobalHeaderClockShell(
            navigatorKey: _navigatorKey,
            // 時計とビルド番号はログイン後の業務用クロームに限定する。
            // 公開LPに内部ステータス風の帯を出すと、未完成・デバッグ中に
            // 見えるうえ、狭幅ではラベルが切れて信頼を損なう。
            showClockBar: supabase.auth.currentSession != null,
            child: UniversalAiShareShell(
              navigatorKey: _navigatorKey,
              child: MaintenanceShell(
                routeListenable: universalAiShareRouteObserver.currentPage,
                child: Column(
                  children: [
                    if (_showUpdateBanner)
                      UpdateBanner(
                        onDismiss: () =>
                            setState(() => _showUpdateBanner = false),
                      ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ja'), Locale('en')],
        locale: const Locale('ja'),
        navigatorObservers: <NavigatorObserver>[
          _growthPresenceObserver,
          universalAiShareRouteObserver,
          // deep link 直開き時に下へ積まれた HomePage / LandingPage の fetch・
          // LP View 計測を可視化まで遅延させる (可視化ゲート)。
          deepLinkVisibilityRouteObserver,
          if (MyApp._sentryNavigatorObserver != null)
            MyApp._sentryNavigatorObserver!,
        ],
        onGenerateRoute: (settings) => ensureRouteAnnouncesUrl(
          generateAppRoute(
            settings,
            signupCompletionService: widget.signupCompletionService,
          ),
          settings,
        ),
      ),
    );
  }
}
