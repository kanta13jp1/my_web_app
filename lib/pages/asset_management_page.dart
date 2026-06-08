// ignore_for_file: require_trailing_commas

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop'
    // ignore: uri_does_not_exist
    if (dart.library.io) 'package:my_web_app/utils/js_interop_vm_stub.dart';
import 'dart:math'; // ← ★この1行を追加してください！

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_management_ai_analysis_history.dart';
import 'package:my_web_app/models/asset_liability_sync_audit_log.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/debt_repayment_plan.dart';
import 'package:my_web_app/models/kgi_csf_kpi.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/services/asset_liability_annual_rate_evidence_service.dart';
import 'package:my_web_app/services/asset_liability_card_statement_import_service.dart';
import 'package:my_web_app/services/asset_liability_csv_restore_service.dart';
import 'package:my_web_app/services/asset_liability_history_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_report_service.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repayment_simulation_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_ai_analysis_history_service.dart';
import 'package:my_web_app/services/asset_management_ai_summary_service.dart';
import 'package:my_web_app/services/asset_management_insight_service.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:my_web_app/services/debt_lockdown_service.dart';
import 'package:my_web_app/services/debt_repayment_planner_service.dart';
import 'package:my_web_app/services/disposable_balance_asset_liability_adapter.dart';
import 'package:my_web_app/services/disposable_balance_service.dart';
import 'package:my_web_app/services/profile_service.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';
import 'package:my_web_app/services/smbc_csv_import_service.dart';
import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:my_web_app/utils/note_image_clipboard.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:my_web_app/widgets/kgi_csf_kpi_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;
