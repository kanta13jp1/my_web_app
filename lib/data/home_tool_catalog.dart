import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/abstinence_guard_page.dart';
import '../pages/admin_analytics_page.dart';
import '../pages/agent_org_page.dart';
import '../pages/ai_secretary_page.dart';
import '../pages/ai_search_page.dart';
import '../pages/ai_status_page.dart';
import '../pages/behavior_log_page.dart';
import '../pages/behavior_review_page.dart';
import '../pages/bookmark_folders_page.dart';
import '../pages/cfo_office_page.dart';
import '../pages/cho_office_page.dart';
import '../pages/chro_office_page.dart';
import '../pages/cmo_office_page.dart';
import '../pages/conveni_store_page.dart';
import '../pages/daily_habits_page.dart';
import '../pages/danshari_page.dart';
import '../pages/decision_check_page.dart';
import '../pages/digest_queue_page.dart';
import '../pages/edge_function_status_page.dart';
import '../pages/election_strategy_page.dart';
import '../pages/election_victory_page.dart';
import '../pages/email_cleanup_page.dart';
import '../pages/gemini_university_v2_page.dart';
import '../pages/growth_mission_page.dart';
import '../pages/home_insights_page.dart';
import '../pages/import_page.dart';
import '../pages/kanban_board_page.dart';
import '../pages/life_goals_page.dart';
import '../pages/memory_drill_page.dart';
import '../pages/mind_map_page.dart';
import '../pages/mindless_task_page.dart';
import '../pages/morning_briefing_page.dart';
import '../pages/my_struggle_page.dart';
import '../pages/note_editor_page.dart';
import '../pages/note_list_page.dart';
import '../pages/payment_reminder_page.dart';
import '../pages/prison_mode_page.dart';
import '../pages/public_memo_directory_page.dart';
import '../pages/public_profile_page.dart';
import '../pages/purchase_log_page.dart';
import '../pages/reality_check_page.dart';
import '../pages/real_world_danshari_page.dart';
import '../pages/referral_page.dart';
import '../pages/shopping_list_page.dart';
import '../pages/stock_tasks_page.dart';
import '../pages/table_data_page.dart';
import '../pages/tech_blog_tracker_page.dart';
import '../pages/template_marketplace_page.dart';
import '../pages/thought_anchor_page.dart';
import '../pages/thought_capture_page.dart';
import '../pages/wardrobe_page.dart';
import '../pages/personality_test_questions_page.dart';
import '../pages/wip_limit_page.dart';
import '../pages/ai_suggest_tags_page.dart';
import '../pages/analyze_reality_page.dart';
import '../pages/support_tickets_page.dart';
import '../pages/growth_achievement_summary_page.dart';
import '../pages/growth_acquisition_report_page.dart';
import '../pages/growth_command_center_page.dart';
import '../pages/growth_share_signal_page.dart';
import '../pages/growth_weekly_digest_page.dart';
import '../pages/memo_reactions_page.dart';
import '../pages/note_comments_page.dart';
import '../pages/growth_acquisition_signal_page.dart';
import '../pages/api_playground_page.dart';
import '../pages/categories_page.dart';
import '../pages/emergency_meeting_page.dart';
import '../pages/embedding_lab_page.dart';
import '../pages/financial_report_page.dart';
import '../pages/payment_channel_ledger_page.dart';
import '../pages/feedback_page.dart';
import '../pages/notifications_page.dart';
import '../pages/health_page.dart';
import '../pages/medical_notes_page.dart';
import '../pages/mental_check_page.dart';
import '../pages/settings_page.dart';
import '../pages/stats_page.dart';
import '../pages/asset_management_page.dart';
import '../pages/cmo_page.dart';
import '../pages/team_workspace_page.dart';
import '../pages/workflow_automation_page.dart';
import '../pages/social_media_scheduler_page.dart';
import '../pages/video_meeting_page.dart';
import '../pages/focus_timer_page.dart';
import '../pages/ai_writing_assistant_page.dart';

typedef HomeToolOpenCallback = Future<void> Function(BuildContext context);

class HomeToolSection {
  const HomeToolSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class HomeToolEntry {
  HomeToolEntry({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.onOpen,
    this.requiresClearDeck = false,
  });

  final String id;
  final String sectionId;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  final HomeToolOpenCallback onOpen;
  final bool requiresClearDeck;
}

const List<HomeToolSection> homeToolSections = <HomeToolSection>[
  HomeToolSection(
    id: 'today',
    title: '今日の運用',
    description: '日次の必須導線と生活オペレーション',
    icon: Icons.wb_sunny_outlined,
    color: Colors.redAccent,
  ),
  HomeToolSection(
    id: 'special',
    title: '特別案件',
    description: '選挙など期限付きの重要プロジェクト',
    icon: Icons.campaign_outlined,
    color: Colors.indigo,
  ),
  HomeToolSection(
    id: 'personal',
    title: '生活・整理',
    description: '断捨離、買い物、自己管理の実務',
    icon: Icons.inventory_2_outlined,
    color: Colors.orange,
  ),
  HomeToolSection(
    id: 'office',
    title: '財務・健康・人事',
    description: 'CFO / CHO / CHRO の定常運用',
    icon: Icons.account_balance_outlined,
    color: Colors.teal,
  ),
  HomeToolSection(
    id: 'knowledge',
    title: '知識・意思決定',
    description: 'CMO / CKO 領域の思考整理と執筆',
    icon: Icons.psychology_alt_outlined,
    color: Colors.blue,
  ),
  HomeToolSection(
    id: 'growth',
    title: '成長・発信',
    description: '集客、公開、分析、運営管理',
    icon: Icons.rocket_launch_outlined,
    color: Colors.green,
  ),
];

Future<void> _pushPage(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => page));
}

List<HomeToolEntry> buildHomeToolCatalog({
  HomeToolOpenCallback? openMorningBriefing,
  HomeToolOpenCallback? openCfoOffice,
  HomeToolOpenCallback? openAbstinenceGuard,
}) {
  final supabaseClient = Supabase.instance.client;

  return <HomeToolEntry>[
    HomeToolEntry(
      id: 'morning-briefing',
      sectionId: 'today',
      title: '朝会ブリーフィング',
      subtitle: '今日の優先順位を固定する',
      icon: Icons.wb_sunny_outlined,
      color: Colors.redAccent,
      keywords: const <String>['朝会', 'ブリーフィング', '優先順位'],
      onOpen: openMorningBriefing ??
          (context) => _pushPage(context, const MorningBriefingPage()),
    ),
    HomeToolEntry(
      id: 'daily-habits',
      sectionId: 'today',
      title: '毎日の習慣',
      subtitle: 'マネフォ更新や体重記録をまとめて確認',
      icon: Icons.repeat,
      color: const Color(0xFF4338CA),
      keywords: const <String>['習慣', 'ルーティン', 'daily'],
      onOpen: (context) => _pushPage(context, const DailyHabitsPage()),
    ),
    HomeToolEntry(
      id: 'abstinence-guard',
      sectionId: 'today',
      title: '禁欲ガード',
      subtitle: '脱線を防ぎ、今日の規律を保つ',
      icon: Icons.shield_moon,
      color: Colors.redAccent,
      keywords: const <String>['禁欲', 'ガード', '規律'],
      onOpen: openAbstinenceGuard ??
          (context) => _pushPage(context, const AbstinenceGuardPage()),
    ),
    HomeToolEntry(
      id: 'cfo-office',
      sectionId: 'today',
      title: '財務管理 (CFO)',
      subtitle: '口座・資産・月次収支を確認する',
      icon: Icons.account_balance_wallet,
      color: Colors.green,
      keywords: const <String>['財務', '資産', '収支', 'cfo'],
      onOpen: openCfoOffice ??
          (context) => _pushPage(context, const CfoOfficePage()),
    ),
    HomeToolEntry(
      id: 'mindless-task',
      sectionId: 'today',
      title: '思考停止ログ',
      subtitle: '必須タスクと読書ループを処理する',
      icon: Icons.access_time_filled,
      color: Colors.indigo,
      keywords: const <String>['思考停止', '必須', '読書ループ'],
      onOpen: (context) => _pushPage(context, const MindlessTaskPage()),
    ),
    HomeToolEntry(
      id: 'stock-tasks',
      sectionId: 'today',
      title: '週末ストック / 思考ネタ',
      subtitle: '土曜の積み残しとアイデアを整頓する',
      icon: Icons.check_circle_outline,
      color: Colors.teal,
      keywords: const <String>['週末', 'ストック', 'ネタ'],
      onOpen: (context) => _pushPage(context, const StockTasksPage()),
    ),
    HomeToolEntry(
      id: 'election-strategy',
      sectionId: 'special',
      title: '2026 衆院選 勝利戦略室',
      subtitle: 'AI参謀と地域特性を踏まえた選挙戦略を立案する',
      icon: Icons.campaign,
      color: Colors.indigo,
      keywords: const <String>['選挙', '衆院選', '戦略'],
      onOpen: (context) => _pushPage(context, const ElectionStrategyPage()),
    ),
    HomeToolEntry(
      id: 'local-election-700',
      sectionId: 'special',
      title: '2027 統一地方選 700必達管理室',
      subtitle: '県連別のKPIと最新実データを工程管理する',
      icon: Icons.how_to_vote,
      color: Colors.green,
      keywords: const <String>['統一地方選', '700', '地方議員'],
      onOpen: (context) => _pushPage(context, const ElectionVictoryPage()),
    ),
    HomeToolEntry(
      id: 'local-election-schedule',
      sectionId: 'special',
      title: 'Local Election Schedule Room',
      subtitle: 'Review AI-fetched schedules and candidate alert colors',
      icon: Icons.event_note,
      color: Colors.orange,
      keywords: const <String>[
        'local election',
        'schedule',
        'candidate',
        'alert',
      ],
      onOpen: (context) =>
          _pushPage(context, const ElectionVictoryPage()),
    ),
    HomeToolEntry(
      id: 'emergency-meeting',
      sectionId: 'special',
      title: '緊急取締役会',
      subtitle: 'AI役員が即席の経営会議を開催・PDCA判断を下す',
      icon: Icons.groups_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['緊急', '取締役会', 'AI', '会議', 'PDCA', '経営'],
      onOpen: (context) => _pushPage(context, const EmergencyMeetingPage()),
    ),
    HomeToolEntry(
      id: 'settings',
      sectionId: 'personal',
      title: '設定',
      subtitle: 'テーマ・プロフィール・資産・フィードバックを管理する',
      icon: Icons.settings_outlined,
      color: Colors.grey,
      keywords: const <String>['設定', 'settings', 'テーマ', 'プロフィール', 'フィードバック'],
      onOpen: (context) => _pushPage(context, const SettingsPage()),
    ),
    HomeToolEntry(
      id: 'stats',
      sectionId: 'personal',
      title: '統計 & 実績',
      subtitle: 'ゲーミフィケーション進捗とバッジを確認する',
      icon: Icons.emoji_events_outlined,
      color: Colors.amber,
      keywords: const <String>['統計', '実績', 'バッジ', 'ゲーミフィケーション', 'レベル'],
      onOpen: (context) => _pushPage(context, const StatsPage()),
    ),
    HomeToolEntry(
      id: 'my-struggle',
      sectionId: 'personal',
      title: '我が闘争',
      subtitle: '日々の奮闘を AI コラムとして残す',
      icon: Icons.auto_stories_outlined,
      color: Colors.brown,
      keywords: const <String>['我が闘争', 'コラム', '記録'],
      onOpen: (context) => _pushPage(context, const MyStrugglePage()),
    ),
    HomeToolEntry(
      id: 'prison-mode',
      sectionId: 'personal',
      title: '刑務所モード',
      subtitle: '借金完済まで生活規律を引き締める',
      icon: Icons.lock_clock_outlined,
      color: Colors.blueGrey,
      keywords: const <String>['刑務所', '借金', '規律'],
      onOpen: (context) => _pushPage(context, const PrisonModePage()),
    ),
    HomeToolEntry(
      id: 'conveni-store',
      sectionId: 'personal',
      title: 'コンビニ経営シミュレーション',
      subtitle: '経営感覚をゲーム形式で鍛える',
      icon: Icons.storefront_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['コンビニ', '経営', 'ゲーム'],
      onOpen: (context) => _pushPage(context, const ConveniStorePage()),
    ),
    HomeToolEntry(
      id: 'bookmark-folders',
      sectionId: 'personal',
      title: 'ブックマーク整理',
      subtitle: 'X やブラウザの保存物をまとめて片付ける',
      icon: Icons.bookmark_border,
      color: Colors.blue,
      keywords: const <String>['ブックマーク', '整理', '保存'],
      onOpen: (context) => _pushPage(context, const BookmarkFoldersPage()),
    ),
    HomeToolEntry(
      id: 'behavior-log',
      sectionId: 'personal',
      title: '行動・発言の振り返り',
      subtitle: '日々の行動ログを AI とレビューする',
      icon: Icons.history_edu,
      color: Colors.blueGrey,
      keywords: const <String>['行動', '発言', '振り返り'],
      onOpen: (context) => _pushPage(context, const BehaviorLogPage()),
    ),
    HomeToolEntry(
      id: 'wip-limit',
      sectionId: 'personal',
      title: '消化してから次を食え',
      subtitle: 'WIP 制限で詰め込みすぎを防ぐ',
      icon: Icons.restaurant_menu,
      color: Colors.brown,
      keywords: const <String>['WIP', '制限', '消化'],
      onOpen: (context) => _pushPage(context, const WipLimitPage()),
    ),
    HomeToolEntry(
      id: 'digital-danshari',
      sectionId: 'personal',
      title: '断捨離 (デジタル)',
      subtitle: 'デジタル資産の棚卸しを進める',
      icon: Icons.cleaning_services,
      color: Colors.orange,
      keywords: const <String>['断捨離', 'デジタル', '整理'],
      onOpen: (context) => _pushPage(context, const DanshariPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'email-cleanup',
      sectionId: 'personal',
      title: 'メール整理',
      subtitle: '受信箱を掃除し、不要メールを処理する',
      icon: Icons.mark_email_read,
      color: Colors.blue,
      keywords: const <String>['メール', '整理', '受信箱'],
      onOpen: (context) => _pushPage(context, const EmailCleanupPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'shopping-list',
      sectionId: 'personal',
      title: '買い物リスト',
      subtitle: '生活必需品の抜け漏れを防ぐ',
      icon: Icons.shopping_cart_outlined,
      color: Colors.brown,
      keywords: const <String>['買い物', 'リスト', 'shopping'],
      onOpen: (context) => _pushPage(context, const ShoppingListPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'real-world-danshari',
      sectionId: 'personal',
      title: '断捨離 (リアル)',
      subtitle: '現実の持ち物を写真付きで整理する',
      icon: Icons.camera_alt_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['断捨離', 'リアル', '持ち物'],
      onOpen: (context) => _pushPage(
        context,
        RealWorldDanshariPage(supabaseClient: supabaseClient),
      ),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'ai-status',
      sectionId: 'personal',
      title: 'AI稼働モニター',
      subtitle: 'AI モデルの状態や疎通を確認する',
      icon: Icons.monitor_heart_outlined,
      color: Colors.orange,
      keywords: const <String>['AI', '稼働', 'モニター'],
      onOpen: (context) => _pushPage(context, const AiStatusPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'wardrobe',
      sectionId: 'personal',
      title: 'ワードローブ整理',
      subtitle: '服の棚卸しと状態確認を行う',
      icon: Icons.checkroom,
      color: Colors.brown,
      keywords: const <String>['ワードローブ', '服', '整理'],
      onOpen: (context) => _pushPage(context, const WardrobePage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'memory-drill',
      sectionId: 'personal',
      title: '暗記ドリル',
      subtitle: '日課としての暗記トレーニング',
      icon: Icons.memory_rounded,
      color: Colors.indigo,
      keywords: const <String>['暗記', 'ドリル', '学習'],
      onOpen: (context) => _pushPage(context, const MemoryDrillPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'digest-queue',
      sectionId: 'personal',
      title: '消化してから次へ',
      subtitle: '積読や未消化の思考材料を処理する',
      icon: Icons.playlist_add_check_circle_outlined,
      color: Colors.cyan,
      keywords: const <String>['消化', '積読', 'キュー'],
      onOpen: (context) => _pushPage(context, const DigestQueuePage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'thought-anchor',
      sectionId: 'personal',
      title: '思考アンカー',
      subtitle: '迷走した思考を短時間で立て直す',
      icon: Icons.center_focus_strong,
      color: Colors.indigo,
      keywords: const <String>['思考', 'アンカー', 'focus'],
      onOpen: (context) => _pushPage(context, const ThoughtAnchorPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'payment-reminders',
      sectionId: 'office',
      title: '支払いリマインダー',
      subtitle: '固定費や支払い期日を一覧で追う',
      icon: Icons.payments_outlined,
      color: Colors.deepPurple,
      keywords: const <String>['支払い', '請求', 'リマインダー'],
      onOpen: (context) => _pushPage(context, const PaymentReminderPage()),
    ),
    HomeToolEntry(
      id: 'purchase-log',
      sectionId: 'office',
      title: '買い物ログ',
      subtitle: '購入履歴と支出傾向を記録する',
      icon: Icons.receipt_long_outlined,
      color: Colors.orange,
      keywords: const <String>['買い物', '支出', 'ログ'],
      onOpen: (context) => _pushPage(context, const PurchaseLogPage()),
    ),
    HomeToolEntry(
      id: 'cho-office',
      sectionId: 'office',
      title: '健康管理 (CHO)',
      subtitle: '健康指標と習慣を一元管理する',
      icon: Icons.medical_services_outlined,
      color: Colors.teal,
      keywords: const <String>['健康', 'CHO', '体調'],
      onOpen: (context) => _pushPage(context, const ChoOfficePage()),
    ),
    HomeToolEntry(
      id: 'chro-office',
      sectionId: 'office',
      title: '人事厚生 (CHRO)',
      subtitle: '福利厚生や生活支援を管理する',
      icon: Icons.diversity_3_outlined,
      color: Colors.indigo,
      keywords: const <String>['人事', '福利厚生', 'CHRO'],
      onOpen: (context) => _pushPage(context, const ChroOfficePage()),
    ),
    HomeToolEntry(
      id: 'health',
      sectionId: 'office',
      title: '健康ログ',
      subtitle: '体調・睡眠・運動の記録を蓄積する',
      icon: Icons.monitor_heart_outlined,
      color: Colors.teal,
      keywords: const <String>['健康', '体調', '睡眠', '運動', 'ログ'],
      onOpen: (context) => _pushPage(context, const HealthPage()),
    ),
    HomeToolEntry(
      id: 'mental-check',
      sectionId: 'office',
      title: 'メンタルチェック',
      subtitle: 'ストレス・気分・モチベーションを定期記録',
      icon: Icons.self_improvement_outlined,
      color: Colors.purple,
      keywords: const <String>['メンタル', 'ストレス', '気分', 'セルフケア'],
      onOpen: (context) => _pushPage(context, const MentalCheckPage()),
    ),
    HomeToolEntry(
      id: 'medical-notes',
      sectionId: 'office',
      title: '医療メモ',
      subtitle: '服薬・通院・症状の記録を管理する',
      icon: Icons.medication_outlined,
      color: Colors.red,
      keywords: const <String>['医療', '通院', '服薬', '症状', '病院'],
      onOpen: (context) => _pushPage(context, const MedicalNotesPage()),
    ),
    HomeToolEntry(
      id: 'financial-report',
      sectionId: 'office',
      title: '財務レポート',
      subtitle: '収支・残高・予算達成率をグラフで確認する',
      icon: Icons.bar_chart_outlined,
      color: Colors.teal,
      keywords: const <String>['財務', '収支', 'レポート', '予算', 'グラフ'],
      onOpen: (context) => _pushPage(context, const FinancialReportPage()),
    ),
    HomeToolEntry(
      id: 'payment-channel-ledger',
      sectionId: 'office',
      title: '支払いチャネル台帳',
      subtitle: '支払い手段ごとの残高・履歴を一覧管理',
      icon: Icons.account_balance_wallet_outlined,
      color: Colors.indigo,
      keywords: const <String>['支払い', 'チャネル', '残高', '台帳', 'ledger'],
      onOpen: (context) =>
          _pushPage(context, const PaymentChannelLedgerPage()),
    ),
    HomeToolEntry(
      id: 'cmo-office',
      sectionId: 'knowledge',
      title: '市場分析 (CMO)',
      subtitle: '市場、競合、集客指標を俯瞰する',
      icon: Icons.trending_up,
      color: Colors.pink,
      keywords: const <String>['市場', '分析', 'CMO'],
      onOpen: (context) => _pushPage(context, const CmoOfficePage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'agent-org',
      sectionId: 'knowledge',
      title: 'AI組織OS',
      subtitle: '仮想組織の状態と連携を確認する',
      icon: Icons.account_tree_outlined,
      color: Colors.deepPurple,
      keywords: const <String>['AI組織', 'エージェント', 'OS'],
      onOpen: (context) => _pushPage(context, AgentOrgPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'ai-secretary',
      sectionId: 'knowledge',
      title: 'AI秘書',
      subtitle: '戦略提案・事業計画・全部署に横断指示',
      icon: Icons.support_agent,
      color: Colors.indigo,
      keywords: const <String>['AI秘書', '戦略', '提案', 'secretary'],
      onOpen: (context) => _pushPage(context, const AISecretaryPage()),
      requiresClearDeck: false,
    ),
    HomeToolEntry(
      id: 'note-list',
      sectionId: 'knowledge',
      title: 'メモ一覧',
      subtitle: '知識ベースを横断して確認する',
      icon: Icons.list_alt,
      color: Colors.blue,
      keywords: const <String>['メモ', 'ノート', '一覧'],
      onOpen: (context) => _pushPage(context, const NoteListPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'note-editor',
      sectionId: 'knowledge',
      title: '新規事業起案',
      subtitle: '企画や思考を書き出して整える',
      icon: Icons.edit_note,
      color: Colors.blue,
      keywords: const <String>['起案', '編集', 'メモ'],
      onOpen: (context) => _pushPage(context, const NoteEditorPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'gemini-university',
      sectionId: 'knowledge',
      title: 'Gemini大学',
      subtitle: '講義形式で AI 学習を進める',
      icon: Icons.menu_book_outlined,
      color: Colors.blue,
      keywords: const <String>['Gemini', '大学', '学習'],
      onOpen: (context) => _pushPage(context, const GeminiUniversityV2Page()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'mind-map',
      sectionId: 'knowledge',
      title: 'マインドマップ',
      subtitle: '思考構造を視覚的に整理する',
      icon: Icons.hub_outlined,
      color: Colors.blue,
      keywords: const <String>['マインドマップ', '思考整理', 'map'],
      onOpen: (context) => _pushPage(context, const MindMapPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'behavior-review',
      sectionId: 'knowledge',
      title: '行動・発言レビュー',
      subtitle: 'ログから行動パターンを再評価する',
      icon: Icons.rate_review_outlined,
      color: Colors.blueGrey,
      keywords: const <String>['レビュー', '行動', '発言'],
      onOpen: (context) => _pushPage(context, BehaviorReviewPage()),
    ),
    HomeToolEntry(
      id: 'reality-check',
      sectionId: 'knowledge',
      title: '現実直視ノート',
      subtitle: '都合の悪い事実も整理して意思決定する',
      icon: Icons.fact_check_outlined,
      color: Colors.redAccent,
      keywords: const <String>['現実直視', 'ノート', '意思決定'],
      onOpen: (context) => _pushPage(context, const RealityCheckPage()),
      requiresClearDeck: true,
    ),
    HomeToolEntry(
      id: 'kanban',
      sectionId: 'knowledge',
      title: 'カンバンボード',
      subtitle: 'タスクを To Do / 進行中 / 完了で管理する',
      icon: Icons.view_kanban_outlined,
      color: Colors.teal,
      keywords: const <String>['カンバン', 'タスク', 'board'],
      onOpen: (context) => _pushPage(context, const KanbanBoardPage()),
    ),
    HomeToolEntry(
      id: 'categories',
      sectionId: 'knowledge',
      title: 'カテゴリ管理',
      subtitle: 'メモ・タスクのカテゴリを整理・編集する',
      icon: Icons.category_outlined,
      color: Colors.blueGrey,
      keywords: const <String>['カテゴリ', 'タグ', '分類', '整理'],
      onOpen: (context) => _pushPage(context, const CategoriesPage()),
    ),
    HomeToolEntry(
      id: 'personality-test',
      sectionId: 'knowledge',
      title: '性格診断 (16タイプ)',
      subtitle: 'MBTIベースの自己分析でメモ術を最適化',
      icon: Icons.psychology_alt_outlined,
      color: Colors.purple,
      keywords: const <String>['性格診断', 'MBTI', '16タイプ', '自己分析'],
      onOpen: (context) =>
          _pushPage(context, const PersonalityTestQuestionsPage(testId: 1)),
    ),
    HomeToolEntry(
      id: 'templates',
      sectionId: 'knowledge',
      title: 'テンプレートマーケット',
      subtitle: '日報や会議メモなどの型を使い始める',
      icon: Icons.description_outlined,
      color: Colors.indigo,
      keywords: const <String>['テンプレート', 'Notion', '型'],
      onOpen: (context) => _pushPage(context, const TemplateMarketplacePage()),
    ),
    HomeToolEntry(
      id: 'table-data',
      sectionId: 'knowledge',
      title: 'データベース',
      subtitle: '表形式でデータを管理する',
      icon: Icons.table_chart_outlined,
      color: Colors.green,
      keywords: const <String>['データベース', 'テーブル', 'database'],
      onOpen: (context) => _pushPage(context, const TableDataPage()),
    ),
    HomeToolEntry(
      id: 'home-insights',
      sectionId: 'growth',
      title: '成長・支援ダッシュボード',
      subtitle: 'ホームから退避した補助カードをまとめて確認する',
      icon: Icons.space_dashboard_outlined,
      color: Colors.indigo,
      keywords: const <String>['成長', '支援', 'ダッシュボード', 'ホーム'],
      onOpen: (context) => _pushPage(context, const HomeInsightsPage()),
    ),
    HomeToolEntry(
      id: 'import',
      sectionId: 'growth',
      title: 'インポート',
      subtitle: '他サービスからデータを取り込む',
      icon: Icons.upload_file,
      color: Colors.teal,
      keywords: const <String>['インポート', '移行', 'import'],
      onOpen: (context) => _pushPage(context, const ImportPage()),
    ),
    HomeToolEntry(
      id: 'growth-mission',
      sectionId: 'growth',
      title: '成長ミッション',
      subtitle: '獲得導線と実績を毎日点検する',
      icon: Icons.flag_outlined,
      color: Colors.green,
      keywords: const <String>['成長', 'ミッション', 'growth'],
      onOpen: (context) => _pushPage(context, const GrowthMissionPage()),
    ),
    HomeToolEntry(
      id: 'life-goals',
      sectionId: 'growth',
      title: '人生目標管理',
      subtitle: '長期目標を可視化して追いかける',
      icon: Icons.flag_circle_outlined,
      color: Colors.deepPurple,
      keywords: const <String>['人生目標', 'goal', 'vision'],
      onOpen: (context) => _pushPage(context, const LifeGoalsPage()),
    ),
    HomeToolEntry(
      id: 'thought-capture',
      sectionId: 'growth',
      title: '思考キャプチャ',
      subtitle: '気づきを素早く回収して育てる',
      icon: Icons.bubble_chart_outlined,
      color: Colors.cyan,
      keywords: const <String>['思考', 'キャプチャ', 'idea'],
      onOpen: (context) => _pushPage(context, const ThoughtCapturePage()),
    ),
    HomeToolEntry(
      id: 'decision-check',
      sectionId: 'growth',
      title: '意思決定ガード',
      subtitle: '重要判断の抜け漏れを事前に防ぐ',
      icon: Icons.psychology_alt_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['意思決定', 'ガード', 'decision'],
      onOpen: (context) => _pushPage(context, const DecisionCheckPage()),
    ),
    HomeToolEntry(
      id: 'public-memos',
      sectionId: 'growth',
      title: '公開メモ一覧',
      subtitle: '公開済みの知見と SEO 導線を確認する',
      icon: Icons.public,
      color: Colors.blue,
      keywords: const <String>['公開メモ', 'SEO', 'public'],
      onOpen: (context) => _pushPage(context, const PublicMemoDirectoryPage()),
    ),
    HomeToolEntry(
      id: 'tech-blog-tracker',
      sectionId: 'growth',
      title: 'ブログ投稿管理',
      subtitle: '下書き、投稿、再配信の進行を追う',
      icon: Icons.edit_note_outlined,
      color: Colors.indigo,
      keywords: const <String>['ブログ', '投稿', 'blog'],
      onOpen: (context) => _pushPage(context, const TechBlogTrackerPage()),
    ),
    HomeToolEntry(
      id: 'public-profile',
      sectionId: 'growth',
      title: '公開プロフィール',
      subtitle: '自分の公開ページを確認する',
      icon: Icons.person_pin_outlined,
      color: Colors.purple,
      keywords: const <String>['プロフィール', '公開', 'profile'],
      onOpen: (context) async {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログイン後に公開プロフィールを開けます。')),
          );
          return;
        }
        await _pushPage(context, PublicProfilePage(userId: userId));
      },
    ),
    HomeToolEntry(
      id: 'admin-analytics',
      sectionId: 'growth',
      title: '管理者ダッシュボード',
      subtitle: 'ユーザー、KPI、監査状況を統合確認する',
      icon: Icons.admin_panel_settings_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['管理者', '分析', 'dashboard'],
      onOpen: (context) => _pushPage(context, const AdminAnalyticsPage()),
    ),
    HomeToolEntry(
      id: 'edge-function-status',
      sectionId: 'growth',
      title: 'Edge Functions 状況',
      subtitle: '各 Edge Function の UI 接続状況を確認する',
      icon: Icons.api_outlined,
      color: Colors.blueGrey,
      keywords: const <String>['Edge Function', 'API', 'status'],
      onOpen: (context) => _pushPage(context, const EdgeFunctionStatusPage()),
    ),
    HomeToolEntry(
      id: 'ai-search',
      sectionId: 'growth',
      title: 'AI ノート検索',
      subtitle: 'ノートや知見を自然文で横断検索する',
      icon: Icons.manage_search,
      color: Colors.deepPurple,
      keywords: const <String>['検索', 'AI', 'ノート'],
      onOpen: (context) => _pushPage(context, const AiSearchPage()),
    ),
    HomeToolEntry(
      id: 'referral',
      sectionId: 'growth',
      title: '友達招待',
      subtitle: '紹介導線と特典を管理する',
      icon: Icons.people_alt_outlined,
      color: Colors.pink,
      keywords: const <String>['招待', '紹介', 'referral'],
      onOpen: (context) => _pushPage(context, const ReferralPage()),
    ),
    HomeToolEntry(
      id: 'ai-suggest-tags',
      sectionId: 'knowledge',
      title: 'AI タグ提案',
      subtitle: 'テキストから関連タグを自動生成する',
      icon: Icons.auto_awesome,
      color: Colors.deepPurple,
      keywords: const <String>['タグ', 'AI', '提案', 'tag'],
      onOpen: (context) => _pushPage(context, const AiSuggestTagsPage()),
    ),
    HomeToolEntry(
      id: 'analyze-reality',
      sectionId: 'knowledge',
      title: '現実分析',
      subtitle: '状況を入力して AI に現実を分析させる',
      icon: Icons.analytics_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['現実', '分析', 'reality', 'AI'],
      onOpen: (context) => _pushPage(context, const AnalyzeRealityPage()),
    ),
    HomeToolEntry(
      id: 'support-tickets',
      sectionId: 'growth',
      title: 'サポートチケット',
      subtitle: '未返信チケットを一覧確認する (管理者)',
      icon: Icons.support_agent,
      color: Colors.teal,
      keywords: const <String>['サポート', 'CS', 'チケット', 'support'],
      onOpen: (context) => _pushPage(context, const SupportTicketsPage()),
    ),
    HomeToolEntry(
      id: 'growth-achievement-summary',
      sectionId: 'growth',
      title: '成長実績サマリー',
      subtitle: '期間別の新規ユーザー・獲得シグナルを確認',
      icon: Icons.emoji_events_outlined,
      color: Colors.green,
      keywords: const <String>['成長', '実績', 'ユーザー', 'growth'],
      onOpen: (context) =>
          _pushPage(context, const GrowthAchievementSummaryPage()),
    ),
    HomeToolEntry(
      id: 'growth-acquisition-report',
      sectionId: 'growth',
      title: '獲得レポート',
      subtitle: 'タッチポイント別の流入・CVR を確認する',
      icon: Icons.bar_chart,
      color: Colors.blue,
      keywords: const <String>['獲得', 'CVR', '流入', 'acquisition'],
      onOpen: (context) =>
          _pushPage(context, const GrowthAcquisitionReportPage()),
    ),
    HomeToolEntry(
      id: 'growth-command-center',
      sectionId: 'growth',
      title: 'グロース司令部',
      subtitle: 'KPI を元に AI が戦略ブリーフを生成する',
      icon: Icons.rocket_launch_outlined,
      color: Colors.indigo,
      keywords: const <String>['司令部', 'KPI', '戦略', 'command'],
      onOpen: (context) =>
          _pushPage(context, const GrowthCommandCenterPage()),
    ),
    HomeToolEntry(
      id: 'growth-share-signal',
      sectionId: 'growth',
      title: '共有シグナル',
      subtitle: '公開メモのシェア・コピー数を確認する',
      icon: Icons.share_outlined,
      color: Colors.pink,
      keywords: const <String>['共有', 'シェア', 'share', 'signal'],
      onOpen: (context) =>
          _pushPage(context, const GrowthShareSignalPage()),
    ),
    HomeToolEntry(
      id: 'growth-weekly-digest',
      sectionId: 'growth',
      title: '週次ダイジェスト',
      subtitle: 'チャネル別の週次グロース指標を確認する',
      icon: Icons.calendar_view_week,
      color: Colors.teal,
      keywords: const <String>['週次', 'ダイジェスト', 'weekly', 'digest'],
      onOpen: (context) =>
          _pushPage(context, const GrowthWeeklyDigestPage()),
    ),
    HomeToolEntry(
      id: 'memo-reactions',
      sectionId: 'growth',
      title: 'メモリアクション',
      subtitle: '公開メモへの絵文字リアクションを確認・投票する',
      icon: Icons.emoji_emotions_outlined,
      color: Colors.amber,
      keywords: const <String>['リアクション', '絵文字', 'メモ', 'reaction'],
      onOpen: (context) => _pushPage(context, const MemoReactionsPage()),
    ),
    HomeToolEntry(
      id: 'note-comments',
      sectionId: 'knowledge',
      title: 'ノートコメント',
      subtitle: 'ノートへのコメントを閲覧・追加・削除する',
      icon: Icons.comment_outlined,
      color: Colors.teal,
      keywords: const <String>['コメント', 'ノート', 'comment', 'note'],
      onOpen: (context) => _pushPage(context, const NoteCommentsPage()),
    ),
    HomeToolEntry(
      id: 'embedding-lab',
      sectionId: 'knowledge',
      title: 'Embedding ラボ',
      subtitle: 'Gemini Embedding API でテキスト類似度を実験する',
      icon: Icons.science_outlined,
      color: Colors.deepPurple,
      keywords: const <String>['embedding', '埋め込み', 'Gemini', '類似度', 'ベクトル'],
      onOpen: (context) => _pushPage(context, const EmbeddingLabPage()),
    ),
    HomeToolEntry(
      id: 'api-playground',
      sectionId: 'knowledge',
      title: 'API プレイグラウンド',
      subtitle: 'Gemini API を直接呼び出してモデルを試す',
      icon: Icons.terminal_outlined,
      color: Colors.deepOrange,
      keywords: const <String>['API', 'Gemini', 'プレイグラウンド', 'テスト', 'モデル'],
      onOpen: (context) => _pushPage(context, const ApiPlaygroundPage()),
    ),
    HomeToolEntry(
      id: 'growth-acquisition-signal',
      sectionId: 'growth',
      title: '集客シグナル記録',
      subtitle: 'チャネルごとの集客シグナルを手動記録する',
      icon: Icons.track_changes,
      color: Colors.green,
      keywords: const <String>['集客', 'シグナル', 'acquisition', 'signal'],
      onOpen: (context) =>
          _pushPage(context, const GrowthAcquisitionSignalPage()),
    ),
    HomeToolEntry(
      id: 'team-workspace',
      sectionId: 'growth',
      title: 'チームワークスペース',
      subtitle: 'チームを作成して招待コードでメンバーを招く',
      icon: Icons.group_outlined,
      color: Colors.indigo,
      keywords: const <String>['チーム', 'team', 'ワークスペース', '招待', '共有', 'コラボ'],
      onOpen: (context) => _pushPage(context, const TeamWorkspacePage()),
    ),
    HomeToolEntry(
      id: 'notifications',
      sectionId: 'growth',
      title: '通知センター',
      subtitle: '新機能・実績・CS返信などの通知を確認',
      icon: Icons.notifications_outlined,
      color: Colors.indigo,
      keywords: const <String>['通知', 'お知らせ', '既読', '未読', '新機能'],
      onOpen: (context) => _pushPage(context, const NotificationsPage()),
    ),
    HomeToolEntry(
      id: 'feedback',
      sectionId: 'growth',
      title: 'フィードバック送信',
      subtitle: '機能アイデア・バグ報告・改善要望を送る',
      icon: Icons.feedback_outlined,
      color: Colors.blue,
      keywords: const <String>['フィードバック', 'バグ報告', '機能要望', '改善'],
      onOpen: (context) => _pushPage(context, const FeedbackPage()),
    ),
    HomeToolEntry(
      id: 'cmo',
      sectionId: 'growth',
      title: 'プレスリリース生成 (CMO)',
      subtitle: 'SNS・Zenn・note 向けの広報文をAIが生成',
      icon: Icons.campaign_outlined,
      color: Colors.purple,
      keywords: const <String>['プレスリリース', '広報', 'SNS', 'CMO', '発信'],
      onOpen: (context) => _pushPage(context, const CmoPage()),
    ),
    HomeToolEntry(
      id: 'asset-management',
      sectionId: 'office',
      title: '資産管理',
      subtitle: '投資・貯蓄・資産ポートフォリオを一元管理',
      icon: Icons.pie_chart_outline,
      color: Colors.teal,
      keywords: const <String>['資産', '投資', '貯蓄', 'ポートフォリオ', '資産管理'],
      onOpen: (context) => _pushPage(context, const AssetManagementPage()),
    ),
    HomeToolEntry(
      id: 'workflow-automation',
      sectionId: 'growth',
      title: 'AIワークフロー自動化',
      subtitle: 'Zapier/Power Automate競合。AIでタスクを自動化',
      icon: Icons.account_tree_outlined,
      color: const Color(0xFF6366F1),
      keywords: const <String>[
        'ワークフロー', '自動化', 'Zapier', 'AI', 'トリガー', 'アクション',
      ],
      onOpen: (context) => _pushPage(context, const WorkflowAutomationPage()),
    ),
    HomeToolEntry(
      id: 'social-scheduler',
      sectionId: 'growth',
      title: 'SNS投稿スケジューラー',
      subtitle: 'X・LinkedIn・Instagram・Facebookへの投稿を一元管理',
      icon: Icons.schedule_send,
      color: const Color(0xFF1DA1F2),
      keywords: const <String>[
        'SNS', 'X', 'Twitter', 'Instagram', '投稿', 'スケジュール', 'ソーシャル',
      ],
      onOpen: (context) => _pushPage(context, const SocialMediaSchedulerPage()),
    ),
    HomeToolEntry(
      id: 'video-meeting',
      sectionId: 'office',
      title: 'ビデオ会議',
      subtitle: 'Zoom/Google Meet競合。AI議事録・アクションアイテム自動抽出',
      icon: Icons.videocam_outlined,
      color: const Color(0xFF2D8CFF),
      keywords: const <String>[
        'ビデオ', '会議', 'Zoom', 'Meet', '議事録', 'オンライン会議', 'ミーティング',
      ],
      onOpen: (context) => _pushPage(context, const VideoMeetingPage()),
    ),
    HomeToolEntry(
      id: 'focus-timer',
      sectionId: 'growth',
      title: '集中タイマー',
      subtitle: 'Forest/Focusmate競合。ポモドーロ+ストリーク管理で集中力を鍛える',
      icon: Icons.timer_outlined,
      color: const Color(0xFF10B981),
      keywords: const <String>[
        '集中', 'タイマー', 'ポモドーロ', 'Forest', 'フォーカス', '作業', 'ストリーク',
      ],
      onOpen: (context) => _pushPage(context, const FocusTimerPage()),
    ),
    HomeToolEntry(
      id: 'ai-writing-assistant',
      sectionId: 'growth',
      title: 'AI文章アシスタント',
      subtitle: 'Grammarly/Notion AI競合。文章改善・要約・翻訳・タイトル提案',
      icon: Icons.auto_fix_high_outlined,
      color: const Color(0xFF8B5CF6),
      keywords: const <String>[
        'AI', '文章', 'Grammarly', '校正', '要約', '翻訳', 'ライティング', 'Notion AI',
      ],
      onOpen: (context) =>
          _pushPage(context, const AiWritingAssistantPage()),
    ),
  ];
}
