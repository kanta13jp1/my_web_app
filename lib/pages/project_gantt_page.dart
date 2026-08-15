import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/web_image_downloader.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

const String _kGithubRepoUrl = 'https://github.com/kanta13jp1/my_web_app';
const String _kAdditionalRequestText = '\u8ffd\u52a0\u8981\u671b';
const String _kUserRequestCategoryText = '\u30e6\u30fc\u30b6\u30fc\u8981\u671b';
final RegExp _kIssueNumberRegex = RegExp(
  r'github\.com\/[^\/\s]+\/[^\/\s]+\/issues\/(\d+)|(?:^|[\s\[(])(?:github\s+)?issue\s*#\s*(\d+)\]?',
  caseSensitive: false,
);

class _GanttDragScrollBehavior extends MaterialScrollBehavior {
  const _GanttDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}

int? _extractIssueNumber(String title) {
  final match = _kIssueNumberRegex.firstMatch(title);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? match.group(2) ?? '');
}

int? _parseIssueNumberValue(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  return _extractIssueNumber(value?.toString() ?? '');
}

bool _isDuplicateWbsMirrorNote(String value) {
  final text = value.trim().toLowerCase();
  return text.startsWith('duplicate of wbs task') ||
      text.startsWith('duplicate github-origin wbs title') ||
      text.startsWith('duplicate wbs title') ||
      text.contains('duplicate_wbs_row') ||
      text.contains('duplicate_title') ||
      text.contains('duplicate_title_generic');
}

Future<void> _openGithubIssue(int issueNumber) async {
  final uri = Uri.parse('$_kGithubRepoUrl/issues/$issueNumber');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _normalizeWbsTitleDuplicateKey(String value) => value
    .replaceFirst(RegExp(r'^\s*\[Issue #\d+\]\s*', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

// ── データモデル ──────────────────────────────────────────────────────────────

class WbsMilestone {
  final String code;
  final String name;
  final DateTime targetDate;
  final int goalUsers;
  final String description;
  final Color color;
  final DateTime? achievedAt;

  const WbsMilestone({
    required this.code,
    required this.name,
    required this.targetDate,
    required this.goalUsers,
    required this.description,
    required this.color,
    this.achievedAt,
  });

  factory WbsMilestone.fromMap(Map<String, dynamic> m) => WbsMilestone(
        code: m['code'] as String,
        name: m['name'] as String,
        targetDate: DateTime.parse(m['target_date'] as String),
        goalUsers: (m['goal_users'] as int?) ?? 0,
        description: m['description'] as String? ?? '',
        color: _hexColor(m['color'] as String? ?? '#FF6B35'),
        achievedAt: m['achieved_at'] != null
            ? DateTime.tryParse(m['achieved_at'] as String)
            : null,
      );

  bool get achieved => achievedAt != null;
  int daysLeft(DateTime now) => targetDate.difference(now).inDays;
}

class WbsTask {
  final String id;
  final String category;
  final String categoryIcon;
  final int categoryOrder;
  final String title;
  final String description;
  final String instance;
  final String status;
  final int progress;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final String? milestoneCode;
  final String priority;
  final String ownerInstance;
  // Win版#131 part 10: 遅延リカバリー対応
  final String recoveryPlan;
  final int rescheduledCount;
  // Win版#131 part 20: 残作業 + 依存関係
  final String remainingWork;
  final List<String> dependsOnTitles;
  final int? githubIssueNumber;
  final String githubIssueUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Win版#132 part 156: GitHub Issue 同期遅延時の補完 filter 用
  // status field は sync EF が遅延すると 'completed' へ変わらない場合がある.
  // github_issue_state == 'CLOSED' を併用すれば close 反映を即時取得可.
  final String githubIssueState;

  const WbsTask({
    required this.id,
    required this.category,
    required this.categoryIcon,
    required this.categoryOrder,
    required this.title,
    required this.description,
    required this.instance,
    required this.status,
    required this.progress,
    this.startDate,
    this.endDate,
    this.plannedStartDate,
    this.plannedEndDate,
    this.milestoneCode,
    required this.priority,
    this.ownerInstance = '',
    this.recoveryPlan = '',
    this.rescheduledCount = 0,
    this.remainingWork = '',
    this.dependsOnTitles = const [],
    this.githubIssueNumber,
    this.githubIssueUrl = '',
    this.createdAt,
    this.updatedAt,
    this.githubIssueState = '',
  });

  bool get isEffectivelyCompleted =>
      status == 'completed' ||
      githubIssueState == 'CLOSED' ||
      isDuplicateGithubIssueMirror;

  int? get linkedGithubIssueNumber =>
      githubIssueNumber ??
      _extractIssueNumber(title) ??
      _extractIssueNumber(githubIssueUrl) ??
      _extractIssueNumber(description);

  bool get isDuplicateGithubIssueMirror =>
      _isDuplicateWbsMirrorNote(remainingWork) ||
      _isDuplicateWbsMirrorNote(recoveryPlan);

  String? get linkedDuplicateTitleKey {
    final titleKey = _normalizeWbsTitleDuplicateKey(title);
    return titleKey.isEmpty ? null : titleKey;
  }

  factory WbsTask.fromMap(Map<String, dynamic> m) => WbsTask(
        id: m['id'] as String,
        category: m['category'] as String,
        categoryIcon: m['category_icon'] as String? ?? '📋',
        categoryOrder: (m['category_order'] as int?) ?? 0,
        title: m['title'] as String,
        description: m['description'] as String? ?? '',
        instance: m['instance'] as String? ?? 'codex',
        status: m['status'] as String? ?? 'pending',
        progress: (m['progress'] as int?) ?? 0,
        startDate: m['start_date'] != null
            ? DateTime.tryParse(m['start_date'] as String)
            : null,
        endDate: m['end_date'] != null
            ? DateTime.tryParse(m['end_date'] as String)
            : null,
        plannedStartDate: m['planned_start_date'] != null
            ? DateTime.tryParse(m['planned_start_date'] as String)
            : null,
        plannedEndDate: m['planned_end_date'] != null
            ? DateTime.tryParse(m['planned_end_date'] as String)
            : null,
        milestoneCode: m['milestone_code'] as String?,
        priority: m['priority'] as String? ?? 'medium',
        ownerInstance: m['owner_instance'] as String? ??
            (m['instance'] as String? ?? 'codex'),
        recoveryPlan: (m['recovery_plan'] as String?) ?? '',
        rescheduledCount: (m['rescheduled_count'] as int?) ?? 0,
        remainingWork: (m['remaining_work'] as String?) ?? '',
        dependsOnTitles:
            (m['depends_on_titles'] as List?)?.cast<String>() ?? const [],
        githubIssueNumber: _parseIssueNumberValue(m['github_issue_number']),
        githubIssueUrl: (m['github_issue_url'] as String?) ?? '',
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
        updatedAt: m['updated_at'] != null
            ? DateTime.tryParse(m['updated_at'] as String)
            : null,
        githubIssueState: (m['github_issue_state'] as String?) ?? '',
      );

  DateTime? get rawScheduleStartDate => plannedStartDate ?? startDate;
  DateTime? get rawScheduleEndDate => plannedEndDate ?? endDate;

  /// Display dates are normalized so the Gantt never shows start > finish.
  DateTime? get scheduleStartDate {
    final start = rawScheduleStartDate;
    final end = rawScheduleEndDate;
    if (start != null && end != null && start.isAfter(end)) return end;
    return start;
  }

  DateTime? get scheduleEndDate {
    final start = rawScheduleStartDate;
    final end = rawScheduleEndDate;
    if (start != null && end != null && start.isAfter(end)) return start;
    return end;
  }

  bool get hasInvertedSchedule {
    final start = rawScheduleStartDate;
    final end = rawScheduleEndDate;
    return start != null && end != null && start.isAfter(end);
  }

  int get delayDays {
    final scheduleEnd = scheduleEndDate;
    if (status == 'completed' || scheduleEnd == null) return 0;
    final now = DateTime.now();
    final end = scheduleEnd;
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    final diff = today.difference(endDay).inDays;
    return diff > 0 ? diff : 0;
  }

  /// 遅延中かつ recovery_plan 未記入 = 警告対象
  bool get isDelayedNoPlan => delayDays > 0 && recoveryPlan.trim().isEmpty;

  Color get statusColor => switch (status) {
        'completed' => const Color(0xFF4CAF50),
        'in_progress' => const Color(0xFFFF6B35),
        'blocked' => const Color(0xFFE53935),
        _ => const Color(0xFF707070),
      };

  String get statusLabel => switch (status) {
        'completed' => '完了',
        'in_progress' => '進行中',
        'blocked' => 'ブロック',
        _ => '未着手',
      };

  String get instanceLabel => switch (instance) {
        'claude' => 'Claude Code',
        'codex' => 'Codex',
        'automation' => 'Automation',
        'gemini' => 'Gemini',
        'co-pilot' => 'Co-pilot',
        'copilot' => 'Co-pilot',
        'user' => 'User',
        'vscode' => 'VSCode版',
        'win' => 'Win版',
        'windows' => 'Win版',
        'ps1' => 'PS版#1',
        'ps2' => 'PS版#2',
        'ps3' => 'PS版#3',
        'ps4' => 'PS版#4',
        'ps5' => 'PS版#5',
        'ps6' => 'PS版#6',
        'ps' => 'PS版',
        'web' => 'WEB版',
        'mobile' => '📱スマホ版',
        // Win版#131 part 13
        'schedule' => '⏰ Schedule',
        'gha' => '🔧 GHA',
        _ => '未割当',
      };

  Color get instanceColor => switch (instance) {
        'claude' => const Color(0xFF2563EB),
        'codex' => const Color(0xFF10B981),
        'automation' => const Color(0xFFEAB308),
        'gemini' => const Color(0xFF4285F4),
        'co-pilot' => const Color(0xFF111827),
        'copilot' => const Color(0xFF111827),
        'user' => const Color(0xFFEF4444),
        'vscode' => const Color(0xFF007ACC),
        'win' => const Color(0xFF00BCF2),
        'windows' => const Color(0xFF00BCF2),
        'ps1' => const Color(0xFF4B0082),
        'ps2' => const Color(0xFF6A0DAD),
        'ps3' => const Color(0xFF8B5CF6),
        'ps4' => const Color(0xFFA855F7),
        'ps5' => const Color(0xFFC084FC),
        'ps6' => const Color(0xFFDAB6FC),
        'ps' => const Color(0xFF4B0082),
        'web' => const Color(0xFF22C55E),
        'mobile' => const Color(0xFFF97316),
        // Win版#131 part 13
        'schedule' => const Color(0xFFEAB308),
        'gha' => const Color(0xFF6B7280),
        _ => const Color(0xFF64748B),
      };

  String get ownerLabel => switch (ownerInstance) {
        'claude' => 'Claude Code',
        'codex' => 'Codex',
        'automation' => 'Automation',
        'gemini' => 'Gemini',
        'co-pilot' => 'Co-pilot',
        'copilot' => 'Co-pilot',
        'user' => 'User',
        'vscode' => 'VSCode版',
        'win' => 'Win版',
        'windows' => 'Win版',
        'ps1' => 'PS版#1',
        'ps2' => 'PS版#2',
        'ps3' => 'PS版#3',
        'ps4' => 'PS版#4',
        'ps5' => 'PS版#5',
        'ps6' => 'PS版#6',
        'ps' => 'PS版',
        'web' => 'WEB版',
        'mobile' => '📱スマホ版',
        'schedule' => '⏰ Schedule',
        'gha' => '🔧 GHA',
        _ => '未割当',
      };

  Color get ownerColor => switch (ownerInstance) {
        'claude' => const Color(0xFF2563EB),
        'codex' => const Color(0xFF10B981),
        'automation' => const Color(0xFFEAB308),
        'gemini' => const Color(0xFF4285F4),
        'co-pilot' => const Color(0xFF111827),
        'copilot' => const Color(0xFF111827),
        'user' => const Color(0xFFEF4444),
        'vscode' => const Color(0xFF007ACC),
        'win' => const Color(0xFF00BCF2),
        'windows' => const Color(0xFF00BCF2),
        'ps1' => const Color(0xFF4B0082),
        'ps2' => const Color(0xFF6A0DAD),
        'ps3' => const Color(0xFF8B5CF6),
        'ps4' => const Color(0xFFA855F7),
        'ps5' => const Color(0xFFC084FC),
        'ps6' => const Color(0xFFDAB6FC),
        'ps' => const Color(0xFF4B0082),
        'web' => const Color(0xFF22C55E),
        'mobile' => const Color(0xFFF97316),
        'schedule' => const Color(0xFFEAB308),
        'gha' => const Color(0xFF6B7280),
        _ => const Color(0xFF707070),
      };

  String get activeInstanceKey => _activeWbsInstanceKey(instance);
  String get activeOwnerKey =>
      _activeWbsInstanceKey(ownerInstance.isEmpty ? instance : ownerInstance);
  String get activeInstanceLabel => _activeWbsInstanceLabel(activeInstanceKey);
  String get activeOwnerLabel => _activeWbsInstanceLabel(activeOwnerKey);
  Color get activeInstanceColor => _activeWbsInstanceColor(activeInstanceKey);
  Color get activeOwnerColor => _activeWbsInstanceColor(activeOwnerKey);

  bool matchesActiveInstanceFilter(String key) =>
      activeInstanceKey == key || activeOwnerKey == key;

  bool get isFeatureRequestTask =>
      category == _kUserRequestCategoryText ||
      category.contains(_kAdditionalRequestText) ||
      title.contains(_kAdditionalRequestText);

  bool get isGithubIssueLinkedTask => linkedGithubIssueNumber != null;

  int get priorityRank => switch (priority) {
        'high' => 3,
        'medium' => 2,
        'low' => 1,
        _ => 0,
      };
}

int _wbsTaskSortBucket(WbsTask task) {
  if (task.status == 'completed') return 5;
  if (task.isFeatureRequestTask) return 0;
  if (task.isGithubIssueLinkedTask) return 1;
  return switch (task.status) {
    'in_progress' => 2,
    'pending' => 3,
    'blocked' => 4,
    _ => 4,
  };
}

int _compareOptionalDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _compareWbsTasks(WbsTask a, WbsTask b) {
  final bucketCmp = _wbsTaskSortBucket(a).compareTo(_wbsTaskSortBucket(b));
  if (bucketCmp != 0) return bucketCmp;

  final priorityCmp = b.priorityRank.compareTo(a.priorityRank);
  if (priorityCmp != 0) return priorityCmp;

  final categoryCmp = a.categoryOrder.compareTo(b.categoryOrder);
  if (categoryCmp != 0) return categoryCmp;

  final endDateCmp = _compareOptionalDate(a.scheduleEndDate, b.scheduleEndDate);
  if (endDateCmp != 0) return endDateCmp;

  final startDateCmp = _compareOptionalDate(
    a.scheduleStartDate,
    b.scheduleStartDate,
  );
  if (startDateCmp != 0) return startDateCmp;

  return a.title.compareTo(b.title);
}

int _compareWbsTaskDisplayKeeper(WbsTask a, WbsTask b) {
  final duplicateCmp = (a.isDuplicateGithubIssueMirror ? 1 : 0).compareTo(
    b.isDuplicateGithubIssueMirror ? 1 : 0,
  );
  if (duplicateCmp != 0) return duplicateCmp;

  final explicitIssueCmp = (a.githubIssueNumber == null ? 1 : 0).compareTo(
    b.githubIssueNumber == null ? 1 : 0,
  );
  if (explicitIssueCmp != 0) return explicitIssueCmp;

  final completedCmp = (a.isEffectivelyCompleted ? 1 : 0).compareTo(
    b.isEffectivelyCompleted ? 1 : 0,
  );
  if (completedCmp != 0) return completedCmp;

  final progressCmp = b.progress.compareTo(a.progress);
  if (progressCmp != 0) return progressCmp;

  final updatedCmp = _compareOptionalDate(b.updatedAt, a.updatedAt);
  if (updatedCmp != 0) return updatedCmp;

  final createdCmp = _compareOptionalDate(a.createdAt, b.createdAt);
  if (createdCmp != 0) return createdCmp;

  return a.id.compareTo(b.id);
}

@visibleForTesting

/// PostgREST の既定 max-rows (1000) を超える表を全件取得するための汎用ページャ。
///
/// `.select()` に range を付けないと PostgREST は先頭 1000 行で打ち切る。WBS の
/// `wbs_tasks` は 3695 行あり、打ち切られた結果ページ側の「未完了 N 件」は
/// 全体ではなく先頭 1000 行だけの集計になっていた (= タスクを完了させても
/// 窓の外の未完了行が滑り込むため件数がほぼ動かない)。
///
/// [fetchPage] は `[from, to]` (両端含む) の 1 ページを返す。返却件数が
/// [pageSize] 未満になったら最終ページとみなして停止する。[maxRows] は
/// 想定外の増殖・無限ループに対する安全弁 (超過分は取得しない)。
///
/// 注意: 呼び出し側は **一意なタイエブレーカを含む安定した order** を指定すること。
/// 非一意なキーだけで並べるとページ境界で行の重複・欠落が起こりうる。
Future<List<Map<String, dynamic>>> fetchAllPagedRows({
  required Future<List<Map<String, dynamic>>> Function(int from, int to)
      fetchPage,
  int pageSize = 1000,
  int maxRows = 20000,
}) async {
  assert(pageSize > 0, 'pageSize must be positive');
  final rows = <Map<String, dynamic>>[];
  var from = 0;
  while (from < maxRows) {
    final remaining = maxRows - from;
    final take = remaining < pageSize ? remaining : pageSize;
    final page = await fetchPage(from, from + take - 1);
    rows.addAll(page);
    // 返却件数が要求未満なら最終ページ (空ページ含む)。
    if (page.length < take) {
      break;
    }
    from += page.length;
  }
  return rows;
}

List<WbsTask> dedupeWbsTasksForDisplay(Iterable<WbsTask> tasks) {
  final ordered = <WbsTask>[];
  final indexByKey = <String, int>{};

  for (final task in tasks) {
    // 正規化タイトルを第一キーにする。`_normalizeWbsTitleDuplicateKey` は
    // `[Issue #N] ` プレフィックスを除去するため、同じ要望が
    //   - `[Issue #3367] <タイトル>` (Issue 起票後のミラー行 / completed)
    //   - `<タイトル>`             (起票前の WBS 素の行 / pending)
    // の 2 行に分かれていても同一キーになり collapse できる。
    //
    // 以前は issue 番号があれば `issue:N` を優先していたため、この 2 行が
    // `issue:3367` と `title:...` に割れて **完了済みの作業が未完了として
    // 二重計上**されていた (実測 3695 行中 68 件が幽霊)。
    // 別 Issue でもタイトルが異なればキーが異なるので分離は保たれる。
    final titleKey = task.linkedDuplicateTitleKey;
    String? displayKey;
    if (titleKey != null) {
      displayKey = 'title:$titleKey';
    } else {
      final issueNumber = task.linkedGithubIssueNumber;
      if (issueNumber != null) displayKey = 'issue:$issueNumber';
    }
    if (displayKey == null) {
      ordered.add(task);
      continue;
    }

    final existingIndex = indexByKey[displayKey];
    if (existingIndex == null) {
      indexByKey[displayKey] = ordered.length;
      ordered.add(task);
      continue;
    }

    final existing = ordered[existingIndex];
    if (_compareWbsTaskDisplayKeeper(task, existing) < 0) {
      ordered[existingIndex] = task;
    }
  }

  return ordered;
}

Color _hexColor(String hex) {
  final s = hex.replaceAll('#', '');
  return Color(int.parse('FF$s', radix: 16));
}

typedef _WbsInstanceFilter = ({String label, String? value, Color color});

const List<_WbsInstanceFilter> _activeWbsInstanceFilters = [
  (label: '全て', value: null, color: Color(0xFFFF6B35)),
  (label: 'Claude Code', value: 'claude', color: Color(0xFF2563EB)),
  (label: 'Codex', value: 'codex', color: Color(0xFF10B981)),
  (label: 'User', value: 'user', color: Color(0xFFEF4444)),
  (label: 'Automation', value: 'automation', color: Color(0xFFEAB308)),
];

String _activeWbsInstanceKey(String raw) {
  final key = raw.trim().toLowerCase().replaceAll('_', '-');
  if (key.isEmpty) return 'claude';
  if (key == 'codex' ||
      key == 'codex1' ||
      key == 'codex-1' ||
      key == 'codex2' ||
      key == 'codex-2' ||
      key == 'ps2' ||
      key == 'ps-2' ||
      key == 'ps5' ||
      key == 'ps-5' ||
      key == 'ps6' ||
      key == 'ps-6') {
    return 'codex';
  }
  if (key == 'user' || key == 'human') return 'user';
  if (key == 'schedule' ||
      key == 'gha' ||
      key == 'github-actions' ||
      key == 'gemini' ||
      key == 'co-pilot' ||
      key == 'copilot' ||
      key == 'github-copilot' ||
      key == 'automation' ||
      key == 'auto') {
    return 'automation';
  }
  return 'claude';
}

String _activeWbsInstanceLabel(String key) => switch (key) {
      'codex' => 'Codex',
      'user' => 'User',
      'automation' => 'Automation',
      _ => 'Claude Code',
    };

String _activeWbsShortInstance(String key) => switch (key) {
      'codex' => 'CX',
      'user' => 'USR',
      'automation' => 'AUTO',
      _ => 'CC',
    };

Color _activeWbsInstanceColor(String key) => switch (key) {
      'codex' => const Color(0xFF10B981),
      'user' => const Color(0xFFEF4444),
      'automation' => const Color(0xFFEAB308),
      _ => const Color(0xFF2563EB),
    };

// ── ページ本体 ────────────────────────────────────────────────────────────────

class ProjectGanttPage extends StatefulWidget {
  const ProjectGanttPage({super.key});

  @override
  State<ProjectGanttPage> createState() => _ProjectGanttPageState();
}

class _ProjectGanttPageState extends State<ProjectGanttPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['wbs', 'timeline', 'projects', 'hygiene'];

  @override
  TabController get tabUrlController => _tabs;

  final _supabase = Supabase.instance.client;
  late final TabController _tabs;

  // WBS data
  List<WbsMilestone> _milestones = [];
  // Win版#131 part 13: マイルストーン risk
  List<Map<String, dynamic>> _milestoneRisks = [];
  List<WbsTask> _tasks = [];
  bool _loadingWbs = true;

  // Filter
  String? _filterInstance;
  String? _filterMilestone;
  // Win版#131 part 12: 未完了タスクのみフィルタ
  bool _hideCompleted = false;

  // My projects (tab 2)
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _newStatus = '進行中';
  bool _saving = false;

  static const _statuses = ['計画中', '進行中', '完了', '保留'];
  static const _statusColors = {
    '計画中': Color(0xFF3D5AFE),
    '進行中': Color(0xFFFF6B35),
    '完了': Color(0xFF4CAF50),
    '保留': Color(0xFFFFC107),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadWbs();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWbs() async {
    setState(() => _loadingWbs = true);
    try {
      final mData =
          await _supabase.from('wbs_milestones').select().order('target_date');
      // wbs_tasks は PostgREST の既定 max-rows (1000) を超えるため全ページ取得する。
      // order には一意な id をタイエブレーカとして必ず含める (非一意キーのみだと
      // ページ境界で行の重複・欠落が起こる)。
      final tData = await fetchAllPagedRows(
        fetchPage: (from, to) async {
          final page = await _supabase
              .from('wbs_tasks')
              .select()
              .order('category_order')
              .order('status')
              .order('id')
              .range(from, to);
          return (page as List).cast<Map<String, dynamic>>();
        },
      );
      if (mounted) {
        setState(() {
          _milestones = (mData as List)
              .map((e) => WbsMilestone.fromMap(e as Map<String, dynamic>))
              .toList();
          _tasks = dedupeWbsTasksForDisplay(
            tData.map(WbsTask.fromMap),
          )..sort(_compareWbsTasks);
        });
      }
      // Win版#131 part 13: マイルストーン risk view (failures は silent)
      try {
        final rData = await _supabase.from('wbs_milestone_risk_view').select();
        if (mounted) {
          setState(() {
            _milestoneRisks = (rData as List).cast<Map<String, dynamic>>();
          });
        }
      } catch (_) {
        // view 未作成時は無視
      }
    } catch (_) {
      // テーブル未作成時はフォールバック表示
    } finally {
      if (mounted) setState(() => _loadingWbs = false);
    }
  }

  Future<void> _loadProjects() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loadingProjects = true);
    try {
      final data = await _supabase
          .from('projects')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(
          () => _projects = List<Map<String, dynamic>>.from(data as List),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _saveProject() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('projects').insert({
        'user_id': user.id,
        'name': name,
        'description': _descCtrl.text.trim(),
        'status': _newStatus,
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      await _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateProjectStatus(String id, String s) async {
    await _supabase.from('projects').update({'status': s}).eq('id', id);
    await _loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          '開発ロードマップ & WBS',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'ユーザータスク',
            onPressed: () => Navigator.of(context).pushNamed('/user-tasks'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              _loadWbs();
              _loadProjects();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFF6B35),
          labelColor: const Color(0xFFFF6B35),
          unselectedLabelColor: const Color(0xFF707070),
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_outlined), text: '開発WBS'),
            Tab(icon: Icon(Icons.timeline), text: 'タイムライン'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'マイプロジェクト'),
            Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'セッション衛生'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WbsTab(
            milestones: _milestones,
            tasks: _tasks,
            loading: _loadingWbs,
            filterInstance: _filterInstance,
            filterMilestone: _filterMilestone,
            hideCompleted: _hideCompleted,
            onFilterInstance: (v) => setState(() => _filterInstance = v),
            onFilterMilestone: (v) => setState(() => _filterMilestone = v),
            onToggleHideCompleted: (v) =>
                setState(() => _hideCompleted = v ?? false),
          ),
          _GanttTimelineTab(
            milestones: _milestones,
            tasks: _tasks,
            loading: _loadingWbs,
            hideCompleted: _hideCompleted,
            onToggleHideCompleted: (v) =>
                setState(() => _hideCompleted = v ?? false),
            filterInstance: _filterInstance,
            onFilterInstance: (v) => setState(() => _filterInstance = v),
            milestoneRisks: _milestoneRisks,
            onRefreshWbs: _loadWbs,
          ),
          _MyProjectsTab(
            projects: _projects,
            loading: _loadingProjects,
            nameCtrl: _nameCtrl,
            descCtrl: _descCtrl,
            status: _newStatus,
            saving: _saving,
            statuses: _statuses,
            statusColors: _statusColors,
            onStatusChanged: (v) => setState(() => _newStatus = v),
            onSave: _saveProject,
            onUpdateStatus: _updateProjectStatus,
          ),
          const _SessionHygieneTab(),
        ],
      ),
    );
  }
}

// ── セッション衛生 タブ (= #2508 J3 skeleton / part 224) ───────────────────
//
// データソース実装待ち: session_hygiene_log table + ef ai_hub.session_hygiene_kpi
// 実 KPI 追加までは empty state のみ表示 ([REAL-DATA] 適合).

class _SessionHygieneTab extends StatelessWidget {
  const _SessionHygieneTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _HygieneKpiPlaceholder(
          icon: Icons.memory,
          title: 'RAM peak / min / avg per session',
          subtitle: 'v24 SS hard exit 14+ 例 / 90% breach 監視',
        ),
        SizedBox(height: 12),
        _HygieneKpiPlaceholder(
          icon: Icons.sd_storage_outlined,
          title: 'C: free drift trend',
          subtitle: '25 GB threshold + 12.7 GB/h idle drift 観測',
        ),
        SizedBox(height: 12),
        _HygieneKpiPlaceholder(
          icon: Icons.timer_outlined,
          title: 'lefthook hang count',
          subtitle: '部 217-b 集積教訓 / push skip 検出',
        ),
        SizedBox(height: 12),
        _HygieneKpiPlaceholder(
          icon: Icons.history,
          title: 'v24 SS / v26 YY hit history',
          subtitle: 'cron-based mandatory compression layer 履歴',
        ),
        SizedBox(height: 24),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'データソース実装待ち: session_hygiene_log table + ef ai_hub.session_hygiene_kpi',
              style: TextStyle(color: Color(0xFF707070)),
            ),
          ),
        ),
      ],
    );
  }
}

class _HygieneKpiPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HygieneKpiPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFF6B35)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Text(
          'TBD',
          style: TextStyle(color: Color(0xFF707070), fontSize: 12),
        ),
      ),
    );
  }
}

// ── WBS タブ ─────────────────────────────────────────────────────────────────

class _WbsTab extends StatelessWidget {
  final List<WbsMilestone> milestones;
  final List<WbsTask> tasks;
  final bool loading;
  final String? filterInstance;
  final String? filterMilestone;
  final bool hideCompleted;
  final ValueChanged<String?> onFilterInstance;
  final ValueChanged<String?> onFilterMilestone;
  final ValueChanged<bool?> onToggleHideCompleted;

  const _WbsTab({
    required this.milestones,
    required this.tasks,
    required this.loading,
    required this.filterInstance,
    required this.filterMilestone,
    required this.hideCompleted,
    required this.onFilterInstance,
    required this.onFilterMilestone,
    required this.onToggleHideCompleted,
  });

  List<WbsTask> get _filtered => tasks.where((t) {
        if (filterInstance != null &&
            !t.matchesActiveInstanceFilter(filterInstance!)) {
          return false;
        }
        if (filterMilestone != null && t.milestoneCode != filterMilestone) {
          return false;
        }
        if (hideCompleted && t.isEffectivelyCompleted) {
          return false;
        }
        return true;
      }).toList();

  Map<String, List<WbsTask>> get _grouped {
    final result = <String, List<WbsTask>>{};
    for (final t in _filtered) {
      (result[t.category] ??= []).add(t);
    }
    return result;
  }

  double _overallProgress(List<WbsTask> taskList) {
    if (taskList.isEmpty) return 0;
    return taskList.map((t) => t.progress).reduce((a, b) => a + b) /
        taskList.length;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }

    final now = DateTime.now();
    final grouped = _grouped;
    // part 156: hideCompleted ON 時は filter 後タスクで進捗 + 件数算出
    // (= GitHub Issue close 反映が visible になる)
    final progressBase = hideCompleted ? _filtered : tasks;
    final overallProgress = _overallProgress(progressBase);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 全体進捗 ──────────────────────────────────────────────────────
        _OverallProgressCard(
          progress: overallProgress,
          taskCount: progressBase.length,
          totalCount: tasks.length,
          showFilteredBadge: hideCompleted,
        ),
        const SizedBox(height: 16),

        // ── マイルストーン ─────────────────────────────────────────────────
        const _SectionHeader(label: 'リリースマイルストーン', icon: Icons.flag_outlined),
        const SizedBox(height: 8),
        if (milestones.isEmpty)
          const _EmptyCard(
            message: 'マイルストーンデータを読み込み中...\n(DBマイグレーション適用後に表示されます)',
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _MilestoneCard(
                milestone: milestones[i],
                now: now,
                tasks: tasks,
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── フィルター ────────────────────────────────────────────────────
        const _SectionHeader(
          label: 'WBSタスク',
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 8),
        _FilterRow(
          filterInstance: filterInstance,
          filterMilestone: filterMilestone,
          milestones: milestones,
          hideCompleted: hideCompleted,
          onFilterInstance: onFilterInstance,
          onFilterMilestone: onFilterMilestone,
          onToggleHideCompleted: onToggleHideCompleted,
        ),
        const SizedBox(height: 8),
        // Win版#131 part 12 / PS#2 S17 VSCode handoff: WBS タブにも未完了 filter
        Row(
          children: [
            Checkbox(
              value: hideCompleted,
              onChanged: onToggleHideCompleted,
              side: const BorderSide(color: Color(0xFF707070)),
              activeColor: const Color(0xFFFF6B35),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(
              '未完了のみ',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 16),
            Text(
              '表示: ${_filtered.length} / ${tasks.length} 件',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: const Color(0xFF707070)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── カテゴリ別タスク ───────────────────────────────────────────────
        if (grouped.isEmpty)
          const _EmptyCard(message: 'WBSデータを読み込み中...\n(DBマイグレーション適用後に表示されます)')
        else
          ...grouped.entries.map(
            (entry) => _CategorySection(
              category: entry.key,
              tasks: entry.value,
              categoryIcon: entry.value.isNotEmpty
                  ? entry.value.first.categoryIcon
                  : '📋',
            ),
          ),
      ],
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final double progress;
  final int taskCount;
  final int totalCount;
  final bool showFilteredBadge;

  const _OverallProgressCard({
    required this.progress,
    required this.taskCount,
    this.totalCount = 0,
    this.showFilteredBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 24, height: 1.5)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自分株式会社 開発WBS',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    Text(
                      showFilteredBadge && totalCount > taskCount
                          ? '$taskCount 件 未完了 / $totalCount 件 全体'
                          : '$taskCount タスク',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF707070),
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF6B35),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Flutter Web + Supabase + 3インスタンス並行開発',
            style: TextStyle(
              color: Color(0xFF707070),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final WbsMilestone milestone;
  final DateTime now;
  final List<WbsTask> tasks;

  const _MilestoneCard({
    required this.milestone,
    required this.now,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final days = milestone.daysLeft(now);
    final milestoneTasks =
        tasks.where((t) => t.milestoneCode == milestone.code).toList();
    final completedCount =
        milestoneTasks.where((t) => t.status == 'completed').length;
    final totalCount = milestoneTasks.length;
    final taskProgress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: milestone.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                milestone.achieved ? Icons.check_circle : Icons.flag_outlined,
                color: milestone.color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  milestone.name,
                  style: TextStyle(
                    color: milestone.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            milestone.achieved
                ? '🎉 達成済み'
                : days > 0
                    ? 'あと $days 日'
                    : '⚠️ 期限超過',
            style: TextStyle(
              color: milestone.achieved
                  ? const Color(0xFF4CAF50)
                  : days < 14
                      ? const Color(0xFFE53935)
                      : const Color(0xFFB0B0B0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '目標: ${milestone.goalUsers}ユーザー',
            style: const TextStyle(
              color: Color(0xFF707070),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: taskProgress,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation<Color>(milestone.color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completedCount / $totalCount タスク完了',
            style: const TextStyle(
              color: Color(0xFF707070),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? filterInstance;
  final String? filterMilestone;
  final List<WbsMilestone> milestones;
  final bool hideCompleted;
  final ValueChanged<String?> onFilterInstance;
  final ValueChanged<String?> onFilterMilestone;
  final ValueChanged<bool?> onToggleHideCompleted;

  const _FilterRow({
    required this.filterInstance,
    required this.filterMilestone,
    required this.milestones,
    required this.hideCompleted,
    required this.onFilterInstance,
    required this.onFilterMilestone,
    required this.onToggleHideCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            '全て',
            null,
            filterInstance,
            onFilterInstance,
            const Color(0xFFFF6B35),
          ),
          const SizedBox(width: 6),
          _chip(
            'Claude Code',
            'claude',
            filterInstance,
            onFilterInstance,
            const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          _chip(
            'Automation',
            'automation',
            filterInstance,
            onFilterInstance,
            const Color(0xFFEAB308),
          ),
          const SizedBox(width: 6),
          _chip(
            'Codex',
            'codex',
            filterInstance,
            onFilterInstance,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 6),
          _chip(
            'Gemini',
            'gemini',
            filterInstance,
            onFilterInstance,
            const Color(0xFF4285F4),
          ),
          const SizedBox(width: 6),
          _chip(
            'Co-pilot',
            'co-pilot',
            filterInstance,
            onFilterInstance,
            const Color(0xFF111827),
          ),
          const SizedBox(width: 6),
          _chip(
            'User',
            'user',
            filterInstance,
            onFilterInstance,
            const Color(0xFFEF4444),
          ),
          const SizedBox(width: 6),
          _chip(
            'VSCode',
            'vscode',
            filterInstance,
            onFilterInstance,
            const Color(0xFF007ACC),
          ),
          const SizedBox(width: 6),
          _chip(
            'Win',
            'win',
            filterInstance,
            onFilterInstance,
            const Color(0xFF00BCF2),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#1',
            'ps1',
            filterInstance,
            onFilterInstance,
            const Color(0xFF4B0082),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#2',
            'ps2',
            filterInstance,
            onFilterInstance,
            const Color(0xFF6A0DAD),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#3',
            'ps3',
            filterInstance,
            onFilterInstance,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#4',
            'ps4',
            filterInstance,
            onFilterInstance,
            const Color(0xFFA855F7),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#5',
            'ps5',
            filterInstance,
            onFilterInstance,
            const Color(0xFFC084FC),
          ),
          const SizedBox(width: 6),
          _chip(
            'PS#6',
            'ps6',
            filterInstance,
            onFilterInstance,
            const Color(0xFFDAB6FC),
          ),
          const SizedBox(width: 6),
          _chip(
            'WEB',
            'web',
            filterInstance,
            onFilterInstance,
            const Color(0xFF22C55E),
          ),
          const SizedBox(width: 6),
          _chip(
            '📱',
            'mobile',
            filterInstance,
            onFilterInstance,
            const Color(0xFFF97316),
          ),
          const SizedBox(width: 6),
          _chip(
            '⏰Schedule',
            'schedule',
            filterInstance,
            onFilterInstance,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 6),
          _chip(
            '🤖GHA',
            'gha',
            filterInstance,
            onFilterInstance,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          // 未完了のみフィルタ
          GestureDetector(
            onTap: () => onToggleHideCompleted(!hideCompleted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hideCompleted
                    ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                    : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hideCompleted
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF333333),
                ),
              ),
              child: Text(
                hideCompleted ? '☑ 未完了のみ' : '☐ 未完了のみ',
                style: TextStyle(
                  color: hideCompleted
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF707070),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '│',
            style: TextStyle(color: Color(0xFF333333), height: 1.5),
          ),
          const SizedBox(width: 12),
          _chip(
            '全版',
            null,
            filterMilestone,
            onFilterMilestone,
            const Color(0xFF707070),
          ),
          ...milestones.map((m) {
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(
                m.name,
                m.code,
                filterMilestone,
                onFilterMilestone,
                m.color,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    String? value,
    String? current,
    ValueChanged<String?> onTap,
    Color color,
  ) {
    final isInstanceFilter = identical(onTap, onFilterInstance);
    final isVisibleInstanceChip = value == null ||
        _activeWbsInstanceFilters.any((filter) => filter.value == value);
    if (isInstanceFilter && !isVisibleInstanceChip) {
      return const SizedBox.shrink();
    }
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : const Color(0xFF333333)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : const Color(0xFF707070),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final String categoryIcon;
  final List<WbsTask> tasks;

  const _CategorySection({
    required this.category,
    required this.categoryIcon,
    required this.tasks,
  });

  double get _avgProgress {
    if (tasks.isEmpty) return 0;
    return tasks.map((t) => t.progress).reduce((a, b) => a + b) / tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avgProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                categoryIcon,
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: avg / 100,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF6B35),
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${avg.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _TaskRow(task: t)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final WbsTask task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6, left: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    color: task.status == 'completed'
                        ? const Color(0xFF707070)
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: task.status == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                    height: 1.5,
                  ),
                ),
              ),
              if (_extractIssueNumber(task.title) != null) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message:
                      'GitHub Issue #${_extractIssueNumber(task.title)} を開く',
                  child: InkWell(
                    onTap: () =>
                        _openGithubIssue(_extractIssueNumber(task.title)!),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.activeInstanceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.activeInstanceLabel,
                  style: TextStyle(
                    color: task.activeInstanceColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              if (task.ownerInstance != task.instance) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: task.activeOwnerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '担当 ${task.activeOwnerLabel}',
                    style: TextStyle(
                      color: task.activeOwnerColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: task.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.statusLabel,
                  style: TextStyle(
                    color: task.statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (task.progress > 0 && task.progress < 100) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress / 100,
                      backgroundColor: const Color(0xFF2A2A2A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        task.statusColor,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${task.progress}%',
                  style: TextStyle(
                    color: task.statusColor,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
          if (task.scheduleStartDate != null ||
              task.scheduleEndDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 10,
                  color: Color(0xFF505050),
                ),
                const SizedBox(width: 4),
                Text(
                  [
                    if (task.scheduleStartDate != null)
                      '開始予定: ${task.scheduleStartDate!.year}/${task.scheduleStartDate!.month.toString().padLeft(2, '0')}/${task.scheduleStartDate!.day.toString().padLeft(2, '0')}',
                    if (task.scheduleEndDate != null)
                      '完了予定: ${task.scheduleEndDate!.year}/${task.scheduleEndDate!.month.toString().padLeft(2, '0')}/${task.scheduleEndDate!.day.toString().padLeft(2, '0')}',
                  ].join('  '),
                  style: TextStyle(
                    color: task.delayDays > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF505050),
                    fontSize: 10,
                    fontWeight:
                        task.delayDays > 0 ? FontWeight.w700 : FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                if (task.delayDays > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${task.delayDays}日遅延${task.recoveryPlan.trim().isEmpty ? " · 案未記入" : ""})',
                    style: TextStyle(
                      color: task.recoveryPlan.trim().isEmpty
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF97316),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── マイプロジェクト タブ ─────────────────────────────────────────────────────

class _MyProjectsTab extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final bool loading;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String status;
  final bool saving;
  final List<String> statuses;
  final Map<String, Color> statusColors;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onSave;
  final Future<void> Function(String, String) onUpdateStatus;

  const _MyProjectsTab({
    required this.projects,
    required this.loading,
    required this.nameCtrl,
    required this.descCtrl,
    required this.status,
    required this.saving,
    required this.statuses,
    required this.statusColors,
    required this.onStatusChanged,
    required this.onSave,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新規プロジェクト',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                    decoration: _inputDec('プロジェクト名'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white, height: 1.5),
                    decoration: _inputDec('説明 (任意)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF333333)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: status,
                            dropdownColor: const Color(0xFF1E1E1E),
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
                            underline: const SizedBox.shrink(),
                            isExpanded: true,
                            items: statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => onStatusChanged(v!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: saving ? null : onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('作成'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  )
                : projects.isEmpty
                    ? const Center(
                        child: Text(
                          'プロジェクトはまだありません',
                          style: TextStyle(color: Colors.white38, height: 1.5),
                        ),
                      )
                    : ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (_, i) {
                          final p = projects[i];
                          final s = p['status'] as String? ?? '進行中';
                          final c = statusColors[s] ?? const Color(0xFFFF6B35);
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: c.withValues(alpha: 0.2),
                                child: Icon(
                                  Icons.folder_outlined,
                                  color: c,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                p['name'] as String? ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                              subtitle: Text(
                                p['description'] as String? ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                color: const Color(0xFF1E1E1E),
                                icon: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      color: c,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                itemBuilder: (_) => statuses
                                    .map(
                                      (st) => PopupMenuItem(
                                        value: st,
                                        child: Text(
                                          st,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onSelected: (st) =>
                                    onUpdateStatus(p['id'].toString(), st),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, height: 1.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      );
}

// ── MS Project 風ガントチャートタイムライン ─────────────────────────────────

class _GanttTimelineTab extends StatefulWidget {
  final List<WbsMilestone> milestones;
  final List<WbsTask> tasks;
  final bool loading;
  // Win版#131 part 12: 未完了 only filter + instance filter (Gantt タブ)
  final bool hideCompleted;
  final ValueChanged<bool?> onToggleHideCompleted;
  final String? filterInstance;
  final ValueChanged<String?> onFilterInstance;
  // Win版#131 part 13: マイルストーン risk
  final List<Map<String, dynamic>> milestoneRisks;
  final Future<void> Function()? onRefreshWbs;

  const _GanttTimelineTab({
    required this.milestones,
    required this.tasks,
    required this.loading,
    required this.hideCompleted,
    required this.onToggleHideCompleted,
    required this.filterInstance,
    required this.onFilterInstance,
    required this.milestoneRisks,
    this.onRefreshWbs,
  });

  @override
  State<_GanttTimelineTab> createState() => _GanttTimelineTabState();
}

class _GanttTimelineTabState extends State<_GanttTimelineTab> {
  // Win版#131 part 12: 開始/完了/リカバリー列追加で 340 → 700 に拡張
  // Win版#131 part 22: 列表示制御 (左パネル幅は表示列の合計から動的算出)
  // Win版#132 part 83: Notion 風 column resize 化 — static const → final + min/max + persistence
  // 列幅 (state / drag で変更可能 + shared_preferences で永続化)
  final Map<String, double> _colWidths = {
    '#': 32,
    'task': 200,
    'startDate': 104,
    'endDate': 104,
    'instance': 70,
    'progress': 50,
    'remaining': 160,
    'depends': 120,
    'recovery': 160,
    'flags': 64, // Win#131 part 22: 注意 flag column
  };

  // 列幅 min/max constraints (= drag 時の clamp 値)
  static const Map<String, double> _colMinWidths = {
    '#': 32,
    'task': 120,
    'startDate': 92,
    'endDate': 92,
    'instance': 50,
    'progress': 40,
    'remaining': 120,
    'depends': 100,
    'recovery': 120,
    'flags': 64,
  };
  static const Map<String, double> _colMaxWidths = {
    '#': 80,
    'task': 800,
    'startDate': 200,
    'endDate': 200,
    'instance': 200,
    'progress': 200,
    'remaining': 600,
    'depends': 400,
    'recovery': 600,
    'flags': 64, // = 固定 (resize 不要)
  };
  // resizable=false の列 (= drag handle 非表示)
  static const Set<String> _colNonResizable = {'#', 'flags'};
  static const String _colWidthPrefsPrefix = 'gantt_col_';

  // 列表示状態 (state)
  final Map<String, bool> _colVisible = {
    '#': true,
    'task': true,
    'startDate': true,
    'endDate': true,
    'instance': true,
    'progress': true,
    'remaining': true,
    'depends': false, // default 非表示で右タイムライン拡張
    'recovery': true,
    'flags': true,
  };

  // 📱 narrow viewport では左パネルが 944px に膨らんで
  // 右タイムライン (Expanded) が 0px になり Gantt が完全に見えなくなる。
  // didChangeDependencies で 1 度だけ narrow 判定して列を最小構成に落とす。
  bool _responsiveDefaultsApplied = false;

  double get _leftPanelWidth =>
      _colVisible.entries
          .where((e) => e.value)
          .fold<double>(0, (sum, e) => sum + (_colWidths[e.key] ?? 0)) +
      16; // padding
  static const _rowHeight = 32.0;
  static const _headerHeight = 72.0;
  static const _dayWidth = 7.0;
  static const _bgColor = Color(0xFF0F0F14);
  static const _panelColor = Color(0xFF1A1A24);
  static const _gridLine = Color(0xFF2A2A36);
  static const _todayColor = Color(0xFFFF6B35);

  final _leftScroll = ScrollController();
  final _rightScroll = ScrollController();
  final _timelineHScroll = ScrollController();
  final _overallHScroll = ScrollController();
  bool _aiReportLoading = false;
  bool _repairLoading = false;

  // Win版#132 part 83: column resize — drag 中の hover key (= handle 強調表示用)
  String? _hoveredResizeColKey;
  String _sortColumnKey = '#';
  bool _sortAscending = true;

  // Win版#132 part 83: shared_preferences から保存済み列幅を load
  Future<void> _loadColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool changed = false;
      for (final key in _colWidths.keys) {
        if (_colNonResizable.contains(key)) continue;
        final saved = prefs.getDouble('$_colWidthPrefsPrefix$key');
        if (saved != null) {
          final min = _colMinWidths[key] ?? 40;
          final max = _colMaxWidths[key] ?? 600;
          _colWidths[key] = saved.clamp(min, max);
          changed = true;
        }
      }
      if (changed && mounted) setState(() {});
    } catch (_) {
      // shared_preferences 失敗時は default 値 fallback (= サイレント)
    }
  }

  // Win版#132 part 83: drag 終了で列幅永続化
  Future<void> _saveColumnWidth(String key, double width) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_colWidthPrefsPrefix$key', width);
    } catch (_) {
      // サイレント (= 保存失敗で UX を邪魔しない)
    }
  }

  // Win版#132 part 83: drag handle / 5px 幅 / cursor ↔ / clamp(min, max)
  Widget _buildResizeHandle(String key) {
    if (_colNonResizable.contains(key)) {
      return const SizedBox.shrink();
    }
    final isHovered = _hoveredResizeColKey == key;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hoveredResizeColKey = key),
      onExit: (_) => setState(() => _hoveredResizeColKey = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) {
          final current = _colWidths[key] ?? 80;
          final min = _colMinWidths[key] ?? 40;
          final max = _colMaxWidths[key] ?? 600;
          final next = (current + details.delta.dx).clamp(min, max);
          if (next != current) {
            setState(() => _colWidths[key] = next);
          }
        },
        onHorizontalDragEnd: (_) {
          final w = _colWidths[key];
          if (w != null) _saveColumnWidth(key, w);
        },
        child: Container(
          width: 5,
          height: double.infinity,
          color: isHovered
              ? _todayColor.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
    );
  }

  void _toggleSortColumn(String key) {
    setState(() {
      if (_sortColumnKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnKey = key;
        _sortAscending = true;
      }
    });
  }

  int _compareTasksForCurrentSort(WbsTask a, WbsTask b) {
    final result = switch (_sortColumnKey) {
      '#' => _compareWbsTasks(a, b),
      'task' => _compareText(a.title, b.title),
      'startDate' => _compareOptionalDate(
          a.scheduleStartDate,
          b.scheduleStartDate,
        ),
      'endDate' => _compareOptionalDate(a.scheduleEndDate, b.scheduleEndDate),
      'instance' => _compareText(
          _instanceBadgeLabel(a),
          _instanceBadgeLabel(b),
        ),
      'progress' => a.progress.compareTo(b.progress),
      'remaining' => _compareText(a.remainingWork, b.remainingWork),
      'depends' => _compareText(
          a.dependsOnTitles.join(' '),
          b.dependsOnTitles.join(' '),
        ),
      'recovery' => _compareText(a.recoveryPlan, b.recoveryPlan),
      'flags' => a.delayDays.compareTo(b.delayDays),
      _ => _compareWbsTasks(a, b),
    };
    final directed = _sortAscending ? result : -result;
    if (directed != 0) return directed;
    return _compareWbsTasks(a, b);
  }

  int _compareText(String a, String b) {
    final left = a.trim().toLowerCase();
    final right = b.trim().toLowerCase();
    if (left.isEmpty && right.isEmpty) return 0;
    if (left.isEmpty) return 1;
    if (right.isEmpty) return -1;
    return left.compareTo(right);
  }

  @override
  void initState() {
    super.initState();
    // Win版#132 part 83: 保存済み列幅を非同期 load
    _loadColumnWidths();
    // 左右の垂直スクロールを同期
    _leftScroll.addListener(() {
      if (_rightScroll.hasClients &&
          _rightScroll.offset != _leftScroll.offset) {
        _rightScroll.jumpTo(_leftScroll.offset);
      }
    });
    _rightScroll.addListener(() {
      if (_leftScroll.hasClients && _leftScroll.offset != _rightScroll.offset) {
        _leftScroll.jumpTo(_rightScroll.offset);
      }
    });
    // 初期表示で本日線を画面中央付近に配置 (todayX - viewportWidth / 3)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_timelineHScroll.hasClients) return;
      final todayX = _dateToX(DateTime.now());
      final viewport = _timelineHScroll.position.viewportDimension;
      final maxScroll = _timelineHScroll.position.maxScrollExtent;
      final target = (todayX - viewport / 3).clamp(0.0, maxScroll);
      _timelineHScroll.jumpTo(target);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_responsiveDefaultsApplied) return;
    final width = MediaQuery.of(context).size.width;
    if (width < 700) {
      // 📱 モバイル幅: 右タイムラインに最低 ~130px 残すため
      //   # (32) + task (200) + flags (36) + padding(16) = 284px 構成
      //   ユーザーは 列表示 トグルで後から追加可能。
      _colVisible['startDate'] = false;
      _colVisible['endDate'] = false;
      _colVisible['instance'] = false;
      _colVisible['progress'] = false;
      _colVisible['remaining'] = false;
      _colVisible['recovery'] = false;
    }
    _responsiveDefaultsApplied = true;
  }

  @override
  void dispose() {
    _leftScroll.dispose();
    _rightScroll.dispose();
    _timelineHScroll.dispose();
    _overallHScroll.dispose();
    super.dispose();
  }

  DateTime get _timelineStart {
    // 今日の 30日前を基準に、表示中タスクの最古日も必ず含める。
    final now = DateTime.now();
    final fallback = DateTime(
      now.year,
      now.month,
      1,
    ).subtract(const Duration(days: 30));
    final taskDates = widget.tasks
        .expand((t) => [t.scheduleStartDate, t.scheduleEndDate])
        .whereType<DateTime>();
    if (taskDates.isEmpty) return fallback;
    final earliest = taskDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final padded = earliest.subtract(const Duration(days: 14));
    return padded.isBefore(fallback) ? padded : fallback;
  }

  DateTime get _timelineEnd {
    final fallback = DateTime.now().add(const Duration(days: 210));
    final dates = [
      ...widget.milestones.map((m) => m.targetDate),
      ...widget.tasks
          .expand((t) => [t.scheduleStartDate, t.scheduleEndDate])
          .whereType<DateTime>(),
    ];
    if (dates.isEmpty) return fallback;
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    final padded = latest.add(const Duration(days: 30));
    return padded.isAfter(fallback) ? padded : fallback;
  }

  int get _totalDays => _timelineEnd.difference(_timelineStart).inDays;
  double get _timelineWidth => _totalDays * _dayWidth;

  /// 指定日付のタイムライン上の X 座標
  double _dateToX(DateTime date) {
    final days = date.difference(_timelineStart).inDays;
    return days * _dayWidth;
  }

  void _scrollWholeGridToGraph() {
    if (!_overallHScroll.hasClients) return;
    final target = (_leftPanelWidth - 56)
        .clamp(0.0, _overallHScroll.position.maxScrollExtent)
        .toDouble();
    _overallHScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  List<WbsTask> get _orderedTasks {
    var list = [...widget.tasks];
    // Win版#131 part 12: 未完了 only filter + instance filter
    // part 156: github_issue_state == 'CLOSED' も完了扱い (= sync 遅延補完)
    if (widget.hideCompleted) {
      list = list.where((t) => !t.isEffectivelyCompleted).toList();
    }
    if (widget.filterInstance != null) {
      list = list
          .where((t) => t.matchesActiveInstanceFilter(widget.filterInstance!))
          .toList();
    }
    list.sort(_compareTasksForCurrentSort);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }
    final tasks = _orderedTasks;
    if (tasks.isEmpty) {
      return const _EmptyCard(
        message: 'タスクデータがありません\n(WBS migration 適用後に表示されます)',
      );
    }

    return Container(
      color: _bgColor,
      child: Column(
        children: [
          _buildHeader(tasks.length, widget.tasks.length),
          // Win版#131 part 22: 列表示制御 + Gantt instance filter
          _buildColumnToggleBar(),
          // Win版#131 part 13: マイルストーン risk warning banner
          if (_riskWarnings.isNotEmpty) _buildRiskBanner(),
          Expanded(
            child: ScrollConfiguration(
              behavior: const _GanttDragScrollBehavior(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const minTimelineViewport = 560.0;
                  final wholeWidth = math.max(
                    constraints.maxWidth,
                    _leftPanelWidth + minTimelineViewport,
                  );
                  final timelineViewportWidth = math.max(
                    minTimelineViewport,
                    wholeWidth - _leftPanelWidth,
                  );
                  return Scrollbar(
                    controller: _overallHScroll,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    thickness: 8,
                    scrollbarOrientation: ScrollbarOrientation.top,
                    child: SingleChildScrollView(
                      controller: _overallHScroll,
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: SizedBox(
                        width: wholeWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 左パネル (# / タスク名 / 担当)
                            SizedBox(
                              width: _leftPanelWidth,
                              child: Column(
                                children: [
                                  _buildLeftColumnHeader(),
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _leftScroll,
                                      itemCount: tasks.length,
                                      itemExtent: _rowHeight,
                                      itemBuilder: (_, i) =>
                                          _buildLeftRow(i, tasks[i]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 右タイムライン (横スクロール)
                            SizedBox(
                              width: timelineViewportWidth,
                              child: Scrollbar(
                                controller: _timelineHScroll,
                                thumbVisibility: true,
                                trackVisibility: true,
                                interactive: true,
                                thickness: 8,
                                scrollbarOrientation:
                                    ScrollbarOrientation.bottom,
                                child: SingleChildScrollView(
                                  controller: _timelineHScroll,
                                  scrollDirection: Axis.horizontal,
                                  primary: false,
                                  child: SizedBox(
                                    width: _timelineWidth,
                                    child: Column(
                                      children: [
                                        _buildMonthHeader(),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              // グリッド + Today ライン
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter: _GanttGridPainter(
                                                    start: _timelineStart,
                                                    end: _timelineEnd,
                                                    dayWidth: _dayWidth,
                                                    todayX: _dateToX(
                                                      DateTime.now(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // タスクバー行
                                              ListView.builder(
                                                controller: _rightScroll,
                                                itemCount: tasks.length,
                                                itemExtent: _rowHeight,
                                                itemBuilder: (_, i) =>
                                                    _buildTimelineRow(
                                                  i,
                                                  tasks[i],
                                                ),
                                              ),
                                              // Win版#131 part 10: イナズマ線 (lightning line)
                                              // 今日時点での進捗実態を zigzag で可視化
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: AnimatedBuilder(
                                                    animation: _rightScroll,
                                                    builder: (context, _) =>
                                                        CustomPaint(
                                                      painter:
                                                          _LightningLinePainter(
                                                        tasks: tasks,
                                                        dayWidth: _dayWidth,
                                                        rowHeight: _rowHeight,
                                                        timelineStart:
                                                            _timelineStart,
                                                        today: DateTime.now(),
                                                        verticalOffset:
                                                            _rightScroll
                                                                    .hasClients
                                                                ? _rightScroll
                                                                    .offset
                                                                : 0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // マイルストーンの縦線 + 菱形
                                              ...widget.milestones.map(
                                                _buildMilestoneMark,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Win版#131 part 13: マイルストーン risk 集計
  List<Map<String, dynamic>> get _riskWarnings => widget.milestoneRisks
      .where(
        (r) =>
            r['risk_status'] == 'over_capacity' ||
            r['risk_status'] == 'critical_overdue' ||
            r['risk_status'] == 'tight',
      )
      .toList();

  Widget _buildRiskBanner() {
    return Container(
      color: const Color(0xFF1A0A0A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          const Text(
            'マイルストーン警告',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _riskWarnings.map(_riskChip).toList()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskChip(Map<String, dynamic> r) {
    final code = r['code'] as String? ?? '?';
    final status = r['risk_status'] as String? ?? '';
    final daysLeft = (r['days_left'] as num?)?.toInt() ?? 0;
    final remaining = (r['remaining_hours'] as num?)?.toDouble() ?? 0.0;
    final available = (r['available_hours'] as num?)?.toDouble() ?? 0.0;
    final overdue = (r['overdue_tasks'] as num?)?.toInt() ?? 0;
    final color = switch (status) {
      'critical_overdue' => const Color(0xFFEF4444),
      'over_capacity' => const Color(0xFFF97316),
      'tight' => const Color(0xFFEAB308),
      _ => const Color(0xFF6B7280),
    };
    final label = switch (status) {
      'critical_overdue' => '🚨 期限超過 ($overdue 件)',
      'over_capacity' =>
        '⚠ 工数超過 ${remaining.toInt()}h > 利用可能 ${available.toInt()}h',
      'tight' => '⏳ 残 $daysLeft 日 (タイト)',
      _ => 'OK',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          '$code: $label',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  String _buildLocalAiReport() {
    final tasks = _orderedTasks;
    final open = tasks.where((t) => !t.isEffectivelyCompleted).toList();
    final delayed = open.where((t) => t.delayDays > 0).toList();
    final noNext =
        open.where((t) => _cleanDisplayText(t.remainingWork) == null).length;
    final noAction =
        open.where((t) => _cleanDisplayText(t.recoveryPlan) == null).length;
    final blockers = open.where((t) => _visibleBlockers(t).isNotEmpty).length;
    final inverted = open.where((t) => t.hasInvertedSchedule).length;
    final avgProgress = tasks.isEmpty
        ? 0
        : (tasks.fold<int>(0, (sum, t) => sum + t.progress) / tasks.length)
            .round();
    final dueSoon = open.where((t) {
      final end = t.scheduleEndDate;
      if (end == null) return false;
      final days = end.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 7;
    }).toList();
    final byOwner = <String, int>{};
    for (final task in open) {
      final owner = _instanceBadgeLabel(task);
      byOwner[owner] = (byOwner[owner] ?? 0) + 1;
    }
    final ownerSummary = byOwner.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final urgent = [...open]..sort((a, b) {
        final delay = b.delayDays.compareTo(a.delayDays);
        if (delay != 0) return delay;
        return _compareOptionalDate(a.scheduleEndDate, b.scheduleEndDate);
      });

    final buf = StringBuffer()
      ..writeln('### 即時診断')
      ..writeln(
        '- 表示中: ${tasks.length}件 / 未完了: ${open.length}件 / 平均進捗: $avgProgress%',
      )
      ..writeln(
        '- 遅延: ${delayed.length}件 / 期限7日以内: ${dueSoon.length}件 / 日付補正: $inverted件',
      )
      ..writeln(
        '- 次にやること未記入: $noNext件 / 状態・対処未記入: $noAction件 / ブロック要因あり: $blockers件',
      );
    if (ownerSummary.isNotEmpty) {
      buf.writeln(
        '- 担当別未完了: ${ownerSummary.take(4).map((e) => '${e.key} ${e.value}件').join(' / ')}',
      );
    }
    buf.writeln('\n### 先に見るべきタスク');
    for (final task in urgent.take(5)) {
      buf.writeln(
        '- ${_compactText(task.title, max: 46)}: ${_statusActionLabel(task)}',
      );
    }
    buf.writeln('\n### 改善提案');
    if (noNext > 0) {
      buf.writeln('- 「次にやること」が未記入のタスクを、担当ごとに3件ずつ具体化する。');
    }
    if (delayed.isNotEmpty) {
      buf.writeln('- 遅延タスクは「状態 / 対処」を先に埋め、予定変更は依存修復後に行う。');
    }
    if (inverted > 0) {
      buf.writeln('- 日付補正タスクは元データの開始予定・完了予定を見直す。');
    }
    if (blockers > 0) {
      buf.writeln('- ブロック要因ありのタスクは依存先完了日を確認し、開始可能日を再計算する。');
    }
    return buf.toString();
  }

  // Win版#131 part 20: AI 概観 + 依存関係自動修復
  Future<void> _showAiReport() async {
    if (_aiReportLoading) return;
    setState(() => _aiReportLoading = true);
    final localReport = _buildLocalAiReport();
    final user = Supabase.instance.client.auth.currentUser;
    var loadingDialogShown = false;
    if (user != null) {
      loadingDialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          backgroundColor: Color(0xFF141414),
          title: Text(
            '🧠 AI 補足取得中...',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          content: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Color(0xFFA855F7),
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }
    String? remoteReport;
    try {
      if (user != null) {
        final resp = await Supabase.instance.client.functions.invoke(
          'tools-hub',
          body: {'action': 'wbs.ai_status_report'},
        );
        final data = resp.data as Map<String, dynamic>?;
        remoteReport = data?['report'] as String?;
      }
    } catch (e) {
      remoteReport = 'AI補足の取得に失敗しました: $e';
    }
    if (!mounted) return;
    if (loadingDialogShown) Navigator.of(context).pop();
    setState(() => _aiReportLoading = false);
    final report = [
      localReport,
      if (remoteReport != null && remoteReport.trim().isNotEmpty)
        '---\n### AI補足\n$remoteReport'
      else if (user == null)
        '---\n### AI補足\nログイン時のみサーバーAI補足を取得します。上記の即時診断は画面上のWBSから生成しています。',
    ].join('\n\n');
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Row(
          children: [
            Icon(Icons.psychology_alt, color: Color(0xFFA855F7)),
            SizedBox(width: 8),
            Text(
              'AI 概観（即時診断）',
              style: TextStyle(color: Colors.white, height: 1.5),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFA855F7).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              report,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '閉じる',
              style: TextStyle(color: Color(0xFFA855F7)),
            ),
          ),
        ],
      ),
    );
  }

  String _csvEscape(String s) {
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _isoDate(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _exportCsv() {
    final tasks = _orderedTasks;
    final buf = StringBuffer();
    const headers = [
      '#',
      'カテゴリ',
      'タスク名',
      '担当',
      '進捗',
      'ステータス',
      '優先度',
      '開始予定',
      '完了予定',
      '次にやること',
      '状態/対処',
      'マイルストーン',
      'GitHubIssue状態',
      'GitHubIssue#',
      'GitHubIssueURL',
      'タスクID',
    ];
    buf.writeln(headers.join(','));
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final issueNo = _extractIssueNumber(t.title);
      final fields = <String>[
        '${i + 1}',
        t.category,
        t.title,
        t.ownerInstance.isNotEmpty ? t.ownerInstance : t.instance,
        '${t.progress}',
        t.status,
        t.priority,
        _isoDate(t.scheduleStartDate),
        _isoDate(t.scheduleEndDate),
        _nextActionLabel(t),
        _statusActionLabel(t),
        t.milestoneCode ?? '',
        t.githubIssueState,
        issueNo?.toString() ?? '',
        issueNo != null ? '$_kGithubRepoUrl/issues/$issueNo' : '',
        t.id,
      ].map(_csvEscape).toList();
      buf.writeln(fields.join(','));
    }

    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final scope = widget.hideCompleted ? 'open' : 'all';
    downloadCsvFile(buf.toString(), 'wbs-timeline-$scope-$stamp.csv');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '📄 ${tasks.length} 件をCSVダウンロードしました (wbs-timeline-$scope-$stamp.csv)',
        ),
        backgroundColor: const Color(0xFF38BDF8),
      ),
    );
  }

  Future<void> _autoRepairDependencies() async {
    if (_repairLoading) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('依存修復にはログインが必要です')));
      return;
    }
    setState(() => _repairLoading = true);
    try {
      final blockerCount =
          _orderedTasks.where((t) => _visibleBlockers(t).isNotEmpty).length;
      final resp = await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {'action': 'wbs.auto_repair_dependencies'},
      );
      final data = resp.data as Map<String, dynamic>?;
      final repairs = (data?['repairs'] as List?) ?? [];
      final refreshWbs = widget.onRefreshWbs;
      if (refreshWbs != null) {
        await refreshWbs();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            repairs.isEmpty
                ? blockerCount == 0
                    ? '✅ ブロック要因はありません。修復不要です'
                    : '✅ 依存関係は整合済です (修復対象 0 件)'
                : '🔧 ${repairs.length}件を修復し、WBSを再読み込みしました',
          ),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('自動修復エラー: $e')));
    } finally {
      if (mounted) setState(() => _repairLoading = false);
    }
  }

  // Win版#131 part 22: 列表示制御 + Gantt instance filter chips
  Widget _buildColumnToggleBar() {
    final labels = {
      '#': '#',
      'task': 'タスク',
      'startDate': '開始',
      'endDate': '完了',
      'instance': '担当',
      'progress': '進捗',
      'remaining': '次作業',
      'depends': 'ブロック',
      'recovery': '状態/対処',
      'flags': '注意',
    };
    return Container(
      color: const Color(0xFF0F0F18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              '列表示:',
              style: TextStyle(
                color: Color(0xFFB0B0C0),
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            ...labels.entries.map((e) {
              final on = _colVisible[e.key] ?? true;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: Text(
                    e.value,
                    style: TextStyle(
                      color: on ? Colors.white : const Color(0xFF707080),
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  selected: on,
                  onSelected: (v) => setState(() => _colVisible[e.key] = v),
                  selectedColor: const Color(0xFF3D5AFE).withValues(alpha: 0.4),
                  backgroundColor: const Color(0xFF1A1A24),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }),
            const SizedBox(width: 12),
            const Text(
              '担当:',
              style: TextStyle(
                color: Color(0xFFB0B0C0),
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(width: 6),
            ..._activeWbsInstanceFilters.map((filter) {
              final on = widget.filterInstance == filter.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: Text(
                    filter.value == null ? '全て' : filter.label,
                    style: TextStyle(
                      color: on ? Colors.black : filter.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  selected: on,
                  onSelected: (_) =>
                      widget.onFilterInstance(on ? null : filter.value),
                  selectedColor: filter.color,
                  backgroundColor: filter.color.withValues(alpha: 0.08),
                  side: BorderSide(color: filter.color.withValues(alpha: 0.4)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }),
            ...[
              ('全', null, const Color(0xFFFF6B35)),
              ('VS', 'vscode', const Color(0xFF007ACC)),
              ('Codex', 'codex', const Color(0xFF10B981)),
              ('Gemini', 'gemini', const Color(0xFF4285F4)),
              ('Co-pilot', 'co-pilot', const Color(0xFF111827)),
              ('User', 'user', const Color(0xFFEF4444)),
              ('Win', 'win', const Color(0xFF00BCF2)),
              ('PS#1', 'ps1', const Color(0xFF4B0082)),
              ('PS#2', 'ps2', const Color(0xFF6A0DAD)),
              ('PS#3', 'ps3', const Color(0xFF8B5CF6)),
              ('PS#4', 'ps4', const Color(0xFFA855F7)),
              ('PS#5', 'ps5', const Color(0xFFC084FC)),
              ('PS#6', 'ps6', const Color(0xFFDAB6FC)),
              ('WEB', 'web', const Color(0xFF22C55E)),
              ('📱', 'mobile', const Color(0xFFF97316)),
              ('⏰', 'schedule', const Color(0xFFEAB308)),
              ('🔧', 'gha', const Color(0xFF6B7280)),
            ].where((_) => false).map((t) {
              if (t.$2 != null &&
                  !_activeWbsInstanceFilters.any(
                    (filter) => filter.value == t.$2,
                  )) {
                return const SizedBox.shrink();
              }
              final on = widget.filterInstance == t.$2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  label: Text(
                    t.$1,
                    style: TextStyle(
                      color: on ? Colors.black : t.$3,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  selected: on,
                  onSelected: (_) => widget.onFilterInstance(on ? null : t.$2),
                  selectedColor: t.$3,
                  backgroundColor: t.$3.withValues(alpha: 0.08),
                  side: BorderSide(color: t.$3.withValues(alpha: 0.4)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int taskCount, int totalCount) {
    final filtered = widget.hideCompleted && totalCount > taskCount;
    final countLabel =
        filtered ? '未完了 $taskCount / 全体 $totalCount 件' : '$taskCount タスク';
    final invertedCount =
        widget.tasks.where((t) => t.hasInvertedSchedule).length;
    return Container(
      color: _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.table_chart_outlined,
            color: Color(0xFFFF6B35),
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'プロジェクトタイムライン',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            countLabel,
            style: TextStyle(
              color:
                  filtered ? const Color(0xFFFF6B35) : const Color(0xFF808090),
              fontSize: 12,
              fontWeight: filtered ? FontWeight.w600 : FontWeight.normal,
              height: 1.5,
            ),
          ),
          if (invertedCount > 0) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: '開始予定が完了予定より後の元データを、画面では開始<=完了に補正表示しています。',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  '日付補正 $invertedCount件',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 16),
          // Win版#131 part 12: 未完了 only toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: widget.hideCompleted,
                onChanged: widget.onToggleHideCompleted,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: const Color(0xFFFF6B35),
                visualDensity: VisualDensity.compact,
              ),
              const Text(
                '未完了のみ',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Tooltip(
            message: '表が広くてグラフが隠れている場合、右側のガント領域へ移動します。',
            child: SizedBox(
              height: 28,
              child: OutlinedButton.icon(
                onPressed: _scrollWholeGridToGraph,
                icon: const Icon(Icons.timeline, size: 14),
                label: const Text(
                  'グラフへ',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF60A5FA),
                  side: const BorderSide(color: Color(0xFF60A5FA)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Win版#131 part 20: AI 概観 + 自動修復 button
          Tooltip(
            message: '表示中WBSをローカル診断し、可能ならAI補足も取得します。',
            child: SizedBox(
              height: 28,
              child: OutlinedButton.icon(
                onPressed: _aiReportLoading ? null : _showAiReport,
                icon: _aiReportLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_alt, size: 14),
                label: Text(
                  _aiReportLoading ? '分析中' : 'AI 概観',
                  style: const TextStyle(fontSize: 11, height: 1.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA855F7),
                  disabledForegroundColor: const Color(
                    0xFFA855F7,
                  ).withValues(alpha: 0.45),
                  side: const BorderSide(color: Color(0xFFA855F7)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: '依存関係由来の日程矛盾を検査し、修復後にWBSを再読み込みします。',
            child: SizedBox(
              height: 28,
              child: OutlinedButton.icon(
                onPressed: _repairLoading ? null : _autoRepairDependencies,
                icon: _repairLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 14),
                label: Text(
                  _repairLoading ? '修復中' : '依存修復',
                  style: const TextStyle(fontSize: 11, height: 1.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22C55E),
                  disabledForegroundColor: const Color(
                    0xFF22C55E,
                  ).withValues(alpha: 0.45),
                  side: const BorderSide(color: Color(0xFF22C55E)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 28,
            child: OutlinedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download, size: 14),
              label: const Text(
                'CSV',
                style: TextStyle(fontSize: 11, height: 1.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF38BDF8)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 10, height: 10, color: _todayColor),
          const SizedBox(width: 6),
          const Text(
            '今日',
            style: TextStyle(
              color: Color(0xFFB0B0C0),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 16),
          _legendSwatch(const Color(0xFF4CAF50), '完了'),
          const SizedBox(width: 8),
          _legendSwatch(const Color(0xFFFF6B35), '進行中'),
          const SizedBox(width: 8),
          _legendSwatch(const Color(0xFF707080), '未着手'),
        ],
      ),
    );
  }

  Widget _legendSwatch(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB0B0C0),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSortableHeaderLabel(
    String key,
    String label,
    TextStyle baseStyle, {
    TextAlign? align,
  }) {
    final active = _sortColumnKey == key;
    final directionIcon = _sortAscending
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final icon = active ? directionIcon : Icons.unfold_more_rounded;
    final color = active ? Colors.white : const Color(0xFFB0B0C0);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: align == TextAlign.center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: baseStyle.copyWith(color: color),
            textAlign: align ?? TextAlign.left,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          icon,
          size: active ? 13 : 12,
          color: active ? _todayColor : const Color(0xFF707080),
        ),
      ],
    );
    return Tooltip(
      message: active ? (_sortAscending ? '昇順でソート中' : '降順でソート中') : 'クリックしてソート',
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          hoverColor: _todayColor.withValues(alpha: 0.10),
          onTap: () => _toggleSortColumn(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            child: row,
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumnHeader() {
    // Win版#131 part 23: _colVisible に応じて列を条件レンダリング
    const labelStyle = TextStyle(
      color: Color(0xFFB0B0C0),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );
    // Win版#132 part 83: header に resize handle を併設.
    // task 列のみ Expanded (= 元動作維持) / handle なし (= flex 列は drag 不可).
    Widget header(
      String key,
      String label, {
      double? width,
      bool expanded = false,
      TextAlign? align,
    }) {
      if (!(_colVisible[key] ?? true)) return const SizedBox.shrink();
      final w = width ?? _colWidths[key] ?? 80;
      final t = _buildSortableHeaderLabel(key, label, labelStyle, align: align);
      // Win版#132 part 86: expanded 引数を ignore (= 全列 fixed-width 化 / タスク名列も resize 対応)
      // ignore: unused_local_variable_for_now (= expanded は API 互換性のため残置)
      // if (expanded) return Expanded(child: t);  // = 旧動作: タスク名列が flex で resize 不可だった
      // resize handle を右端に併設 (= _colNonResizable は SizedBox.shrink 返却)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: w,
            child: align == null ? t : Center(child: t),
          ),
          _buildResizeHandle(key),
        ],
      );
    }

    return Container(
      height: _headerHeight,
      color: _panelColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          header('#', '#', align: TextAlign.center),
          // task 名のみ Expanded
          header('task', 'タスク', expanded: true),
          header('startDate', '開始予定', align: TextAlign.center),
          header('endDate', '完了予定', align: TextAlign.center),
          header('instance', '担当', align: TextAlign.center),
          header('progress', '進捗', align: TextAlign.center),
          header('remaining', '次にやること'),
          header('depends', 'ブロック要因'),
          header('recovery', '状態 / 対処'),
          header('flags', '注意', align: TextAlign.center),
        ],
      ),
    );
  }

  String? _cleanDisplayText(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    const internalMarkers = [
      'github issue source of truth',
      'sync keeps wbs',
      'tbd',
      'pre-push backfill',
      'duplicate of wbs task',
      '遅延 detect',
      '延定 detect',
    ];
    if (internalMarkers.any((marker) => lower.contains(marker))) return null;
    return text;
  }

  String _compactText(String text, {int max = 54}) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max - 1)}…';
  }

  String _nextActionLabel(WbsTask task) {
    final text = _cleanDisplayText(task.remainingWork);
    if (text != null) return _compactText(text, max: 64);
    if (task.isEffectivelyCompleted) return '完了';
    if (task.isDelayedNoPlan) return '遅延対応を記入';
    if (task.delayDays > 0) return '遅延対応を確認';
    if (task.progress > 0) return '進行中: 次手順未記入';
    if (_extractIssueNumber(task.title) != null) return 'Issueを確認して着手';
    return '次手順未記入';
  }

  Color _nextActionColor(WbsTask task) {
    if (_cleanDisplayText(task.remainingWork) != null) {
      return const Color(0xFFE2E8F0);
    }
    if (task.isDelayedNoPlan || task.delayDays > 0) {
      return const Color(0xFFF97316);
    }
    return const Color(0xFF94A3B8);
  }

  List<String> _visibleBlockers(WbsTask task) => task.dependsOnTitles
      .map(_cleanDisplayText)
      .whereType<String>()
      .map((t) => _compactText(t, max: 44))
      .toList();

  String _blockerLabel(WbsTask task) {
    final blockers = _visibleBlockers(task);
    if (blockers.isEmpty) return 'なし';
    if (blockers.length == 1) return blockers.single;
    return '${blockers.length}件: ${blockers.first}';
  }

  String _statusActionLabel(WbsTask task) {
    if (task.isEffectivelyCompleted) return '完了';
    if (task.hasInvertedSchedule) return '日付補正済';
    final recovery = _cleanDisplayText(task.recoveryPlan);
    if (task.delayDays > 0) {
      if (recovery != null) {
        return '${task.delayDays}日遅延: ${_compactText(recovery, max: 42)}';
      }
      return '${task.delayDays}日遅延: 対処未記入';
    }
    if (recovery != null) return _compactText(recovery, max: 58);
    final end = task.scheduleEndDate;
    if (end != null) {
      final days = end.difference(DateTime.now()).inDays;
      if (days >= 0 && days <= 7) return '期限近い: 残$days日';
    }
    if (task.progress > 0) return '進行中';
    return '未着手';
  }

  Color _statusActionColor(WbsTask task) {
    if (task.isEffectivelyCompleted) return const Color(0xFF22C55E);
    if (task.hasInvertedSchedule) return const Color(0xFFFBBF24);
    if (task.isDelayedNoPlan) return const Color(0xFFEF4444);
    if (task.delayDays > 0) return const Color(0xFFF97316);
    if (_cleanDisplayText(task.recoveryPlan) != null) {
      return const Color(0xFFE2E8F0);
    }
    return const Color(0xFF94A3B8);
  }

  String _attentionLabel(WbsTask task) {
    if (task.isEffectivelyCompleted) return '完了';
    if (task.hasInvertedSchedule) return '日付';
    if (task.isDelayedNoPlan) return '要対処';
    if (task.delayDays > 0) return '遅延';
    if (_cleanDisplayText(task.remainingWork) == null) return '未記入';
    return 'OK';
  }

  Color _attentionColor(WbsTask task) {
    if (task.isEffectivelyCompleted) return const Color(0xFF22C55E);
    if (task.hasInvertedSchedule) return const Color(0xFFFBBF24);
    if (task.isDelayedNoPlan) return const Color(0xFFEF4444);
    if (task.delayDays > 0) return const Color(0xFFF97316);
    if (_cleanDisplayText(task.remainingWork) == null) {
      return const Color(0xFF94A3B8);
    }
    return const Color(0xFF38BDF8);
  }

  Widget _buildLeftRow(int index, WbsTask task) {
    final isEven = index % 2 == 0;
    final isDelayedNoPlan = task.isDelayedNoPlan;
    final isDelayed = task.delayDays > 0;
    // Win版#132 part 86: 行全体 Tooltip 削除 (= recovery 固定だったバグ) → 各セル個別 Tooltip 化
    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFF14141C) : const Color(0xFF1A1A24),
        border: Border(
          bottom: const BorderSide(color: _gridLine, width: 0.5),
          left: isDelayedNoPlan
              ? const BorderSide(color: Color(0xFFEF4444), width: 3)
              : isDelayed
                  ? const BorderSide(color: Color(0xFFF97316), width: 3)
                  : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // # 列
          if (_colVisible['#'] ?? true)
            Tooltip(
              message: '#${index + 1}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF808090),
                    fontSize: 11,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          // タスク名 (完了 checkbox + emoji + 名前 + inline delay flag)
          // Win版#132 part 86: spread → fixed-width SizedBox 化 (= タスク名列 resize 対応)
          // + 列別 Tooltip wrap (= タスク名 hover で task.title 表示)
          if (_colVisible['task'] ?? true)
            Tooltip(
              message: 'タスク名: ${task.title}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['task'] ?? 200,
                child: Row(
                  children: [
                    Icon(
                      task.status == 'completed'
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 14,
                      color: task.status == 'completed'
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF606070),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      task.categoryIcon,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_extractIssueNumber(task.title) != null) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message:
                                  'GitHub Issue #${_extractIssueNumber(task.title)} を開く',
                              child: InkWell(
                                onTap: () => _openGithubIssue(
                                  _extractIssueNumber(task.title)!,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.open_in_new,
                                    size: 12,
                                    color: Color(0xFF60A5FA),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (isDelayedNoPlan) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '⚠${task.delayDays}d',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ] else if (isDelayed) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${task.delayDays}d',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Win版#131 part 12: 開始/完了予定/担当/リカバリー (条件レンダリング)
          // Win版#132 part 83: width を _colWidths から動的取得 (= drag resize 反映)
          // Win版#132 part 86: 各 cell を Tooltip で wrap (= 列別 hover content 表示 / recovery 固定 bug 修正)
          if (_colVisible['startDate'] ?? true)
            Tooltip(
              message: task.hasInvertedSchedule
                  ? '開始予定: ${_formatDate(task.scheduleStartDate)}\n元データは開始 ${_formatDate(task.rawScheduleStartDate)} > 完了 ${_formatDate(task.rawScheduleEndDate)} のため補正表示'
                  : '開始予定: ${_formatDate(task.scheduleStartDate)}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['startDate'] ?? 80,
                child: Text(
                  _formatDate(task.scheduleStartDate),
                  style: TextStyle(
                    color: task.hasInvertedSchedule
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFB0B0C0),
                    fontSize: 11,
                    fontWeight: task.hasInvertedSchedule
                        ? FontWeight.w700
                        : FontWeight.normal,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_colVisible['endDate'] ?? true)
            Tooltip(
              message: task.hasInvertedSchedule
                  ? '完了予定: ${_formatDate(task.scheduleEndDate)}\n元データは開始 ${_formatDate(task.rawScheduleStartDate)} > 完了 ${_formatDate(task.rawScheduleEndDate)} のため補正表示'
                  : task.delayDays > 0
                      ? '完了予定: ${_formatDate(task.scheduleEndDate)} (${task.delayDays}日遅延)'
                      : '完了予定: ${_formatDate(task.scheduleEndDate)}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['endDate'] ?? 80,
                child: Text(
                  _formatDate(task.scheduleEndDate),
                  style: TextStyle(
                    color: task.hasInvertedSchedule
                        ? const Color(0xFFFBBF24)
                        : task.delayDays > 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFB0B0C0),
                    fontSize: 11,
                    fontWeight: task.hasInvertedSchedule || task.delayDays > 0
                        ? FontWeight.w700
                        : FontWeight.normal,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_colVisible['instance'] ?? true)
            Tooltip(
              message: '担当: ${task.activeOwnerLabel}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['instance'] ?? 70,
                child: _instanceBadge(task),
              ),
            ),
          if (_colVisible['progress'] ?? true)
            Tooltip(
              message: '進捗: ${task.progress}%',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['progress'] ?? 50,
                child: Text(
                  '${task.progress}%',
                  style: TextStyle(
                    color: task.progress >= 100
                        ? const Color(0xFF22C55E)
                        : task.progress >= 50
                            ? const Color(0xFFF97316)
                            : const Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_colVisible['remaining'] ?? true)
            Tooltip(
              message: _cleanDisplayText(task.remainingWork) != null
                  ? '次にやること: ${_cleanDisplayText(task.remainingWork)}'
                  : '次にやること: ${_nextActionLabel(task)}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['remaining'] ?? 200,
                child: _readableStatusCell(
                  label: _nextActionLabel(task),
                  color: _nextActionColor(task),
                  onTap: _cleanDisplayText(task.remainingWork) == null
                      ? () => _sendInstructionToInstance(task, 'remaining_work')
                      : null,
                ),
              ),
            ),
          if (_colVisible['depends'] ?? true)
            Tooltip(
              message: _visibleBlockers(task).isEmpty
                  ? 'ブロック要因: なし'
                  : 'ブロック要因: ${_visibleBlockers(task).join(" / ")}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['depends'] ?? 150,
                child: _readableStatusCell(
                  label: _blockerLabel(task),
                  color: _visibleBlockers(task).isEmpty
                      ? const Color(0xFF64748B)
                      : const Color(0xFFA855F7),
                ),
              ),
            ),
          if (_colVisible['recovery'] ?? true)
            Tooltip(
              message: '状態 / 対処: ${_statusActionLabel(task)}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['recovery'] ?? 180,
                child: _readableStatusCell(
                  label: _statusActionLabel(task),
                  color: _statusActionColor(task),
                  onTap: _cleanDisplayText(task.recoveryPlan) == null &&
                          !task.isEffectivelyCompleted
                      ? () => _sendInstructionToInstance(task, 'recovery_plan')
                      : null,
                ),
              ),
            ),
          // Win版#131 part 22: 注意 flag column (短い状態 badge)
          if (_colVisible['flags'] ?? true)
            Tooltip(
              message: '注意: ${_attentionLabel(task)}',
              waitDuration: const Duration(milliseconds: 350),
              child: SizedBox(
                width: _colWidths['flags'] ?? 36,
                child: _attentionBadge(task),
              ),
            ),
        ],
      ),
    ); // Win版#132 part 86: Tooltip 削除 — Container + Row 構造のみ (閉じ括弧 1 つ減)
  }

  Widget _readableStatusCell({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final text = Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w700,
          height: 1.5,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (onTap == null) return text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(left: 2, right: 4, top: 5, bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _attentionBadge(WbsTask task) {
    final label = _attentionLabel(task);
    final color = _attentionColor(task);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Win版#131 part 23: 担当 instance に直接指示送信 (cross-instance-pr 自動生成)
  Future<void> _sendInstructionToInstance(WbsTask task, String field) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    final fieldLabel = field == 'remaining_work' ? '次にやること' : '状態 / 対処';
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          '📨 ${task.instance.toUpperCase()} に「$fieldLabel」更新を依頼',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'タスク: ${task.title}',
                style: const TextStyle(
                  color: Color(0xFFB0B0C0),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: '例: 「次の 2 step は何か？」「ブロッカーは？」',
                  hintStyle: const TextStyle(color: Color(0xFF606070)),
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2A2A36)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Color(0xFF808090)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D5AFE),
            ),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('送信', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    if (!mounted) return;
    try {
      // tools-hub:wbs.add_task で「依頼タスク」として追加 (担当 = 該当 instance)
      await Supabase.instance.client.functions.invoke(
        'tools-hub',
        body: {
          'action': 'wbs.add_task',
          'category': '📨 依頼受領',
          'category_icon': '📨',
          'category_order': 1,
          'title': '[依頼] ${task.title} の $fieldLabel を更新してください',
          'description':
              '依頼内容: $result\n\n対象タスク ID: ${task.id}\n\nWBS UI から自動送信',
          'instance': task.activeInstanceKey,
          'owner_instance': task.activeOwnerKey,
          'priority': task.isDelayedNoPlan ? 'high' : 'medium',
          'status': 'pending',
          'progress': 0,
          'remaining_work': result,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${task.instance.toUpperCase()} に依頼を送信しました'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送信エラー: $e')));
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  Widget _instanceBadge(WbsTask task) {
    final label = _instanceBadgeLabel(task);
    final badgeColor = task.activeOwnerKey != task.activeInstanceKey
        ? task.activeOwnerColor
        : task.activeInstanceColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  String _instanceBadgeLabel(WbsTask task) {
    final lane = _shortInstance(task.activeInstanceKey);
    final owner = _shortInstance(task.activeOwnerKey);
    if (owner.isEmpty || owner == lane) return lane;
    return '$lane→$owner';
  }

  String _shortInstance(String i) =>
      _activeWbsShortInstance(_activeWbsInstanceKey(i));

  Widget _buildMonthHeader() {
    return Container(
      height: _headerHeight,
      color: _panelColor,
      child: CustomPaint(
        painter: _MonthHeaderPainter(
          start: _timelineStart,
          end: _timelineEnd,
          dayWidth: _dayWidth,
          today: DateTime.now(),
        ),
      ),
    );
  }

  Widget _buildTimelineRow(int index, WbsTask task) {
    final start = task.scheduleStartDate;
    final end = task.scheduleEndDate;
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }
    final x = _dateToX(start);
    final w = (_dateToX(end) - x).clamp(_dayWidth, double.infinity);
    final progressW = w * (task.progress / 100.0);

    return Container(
      decoration: BoxDecoration(
        color:
            index % 2 == 0 ? const Color(0xFF14141C) : const Color(0xFF1A1A24),
      ),
      child: Stack(
        children: [
          Positioned(
            left: x,
            top: 8,
            child: Container(
              width: w.toDouble(),
              height: _rowHeight - 16,
              decoration: BoxDecoration(
                color: task.statusColor.withValues(alpha: 0.25),
                border: Border.all(color: task.statusColor, width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Stack(
                children: [
                  // 進捗塗り
                  Container(
                    width: progressW.toDouble(),
                    decoration: BoxDecoration(
                      color: task.statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(2),
                        bottomLeft: Radius.circular(2),
                      ),
                    ),
                  ),
                  if (w > 40)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${task.progress}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneMark(WbsMilestone m) {
    final x = _dateToX(m.targetDate);
    return Positioned(
      left: x - 6,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 2),
                color: m.color,
              ),
            ),
            Expanded(
              child: Container(
                width: 1,
                color: m.color.withValues(alpha: 0.35),
                margin: const EdgeInsets.only(left: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GanttGridPainter extends CustomPainter {
  final DateTime start;
  final DateTime end;
  final double dayWidth;
  final double todayX;

  _GanttGridPainter({
    required this.start,
    required this.end,
    required this.dayWidth,
    required this.todayX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final weekend = Paint()..color = const Color(0xFF181822);
    final weekLine = Paint()..color = const Color(0xFF22222E);
    final monthLine = Paint()..color = const Color(0xFF3A3A48);

    var day = start;
    var x = 0.0;
    while (day.isBefore(end)) {
      // 週末ハイライト
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        canvas.drawRect(Rect.fromLTWH(x, 0, dayWidth, size.height), weekend);
      }
      // 月の切り替わりで太線
      if (day.day == 1) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), monthLine);
      } else if (day.weekday == DateTime.monday) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), weekLine);
      }
      day = day.add(const Duration(days: 1));
      x += dayWidth;
    }
    // Today ライン (Win版#131 part 23: prominent — 二重線 + glow + label)
    // 1) glow halo
    final todayGlow = Paint()
      ..color = const Color(0xFFFF6B35).withValues(alpha: 0.18)
      ..strokeWidth = 8;
    canvas.drawLine(Offset(todayX, 0), Offset(todayX, size.height), todayGlow);
    // 2) main line
    final todayPaint = Paint()
      ..color = const Color(0xFFFF6B35)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(todayX, 0), Offset(todayX, size.height), todayPaint);
  }

  @override
  bool shouldRepaint(covariant _GanttGridPainter oldDelegate) =>
      oldDelegate.todayX != todayX ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.dayWidth != dayWidth;
}

class _MonthHeaderPainter extends CustomPainter {
  final DateTime start;
  final DateTime end;
  final double dayWidth;
  final DateTime today;

  _MonthHeaderPainter({
    required this.start,
    required this.end,
    required this.dayWidth,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0xFF3A3A48);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 34),
      Paint()..color = const Color(0xFF181824),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 34, size.width, size.height - 34),
      Paint()..color = const Color(0xFF12121B),
    );

    // 月ヘッダー (上段)
    DateTime monthCursor = DateTime(start.year, start.month, 1);
    while (monthCursor.isBefore(end)) {
      final monthStart = monthCursor.isAfter(start) ? monthCursor : start;
      final nextMonth = DateTime(monthCursor.year, monthCursor.month + 1, 1);
      final monthEnd = nextMonth.isBefore(end) ? nextMonth : end;
      final xStart = monthStart.difference(start).inDays * dayWidth;
      final xEnd = monthEnd.difference(start).inDays * dayWidth;
      final width = xEnd - xStart;

      // 月ラベル
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${monthCursor.year}/${monthCursor.month.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Color(0xFFE0E0EA),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: width);
      if (width > 40) {
        tp.paint(canvas, Offset(xStart + 6, 8));
      }

      // 月境界線
      canvas.drawLine(Offset(xEnd, 0), Offset(xEnd, size.height), line);

      monthCursor = nextMonth;
    }

    // 日/週ヘッダー (下段)
    const weekLabelStyle = TextStyle(
      color: Color(0xFFB8B8C8),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );
    DateTime day = start;
    double x = 0;
    while (day.isBefore(end)) {
      if (day.weekday == DateTime.monday && dayWidth >= 5) {
        final tp = TextPainter(
          text: TextSpan(
            text:
                '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}',
            style: weekLabelStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 43));
      }
      day = day.add(const Duration(days: 1));
      x += dayWidth;
    }

    final tickPaint = Paint()
      ..color = const Color(0xFF52525F)
      ..strokeWidth = 1;
    DateTime tickDay = start;
    double tickX = 0;
    while (tickDay.isBefore(end)) {
      if (tickDay.weekday == DateTime.monday || tickDay.day == 1) {
        canvas.drawLine(
          Offset(tickX, 36),
          Offset(tickX, size.height - 1),
          tickPaint,
        );
      }
      tickDay = tickDay.add(const Duration(days: 1));
      tickX += dayWidth;
    }

    // ヘッダー下の太線
    final bottomLinePaint = Paint()..color = const Color(0xFF3A3A48);
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      bottomLinePaint,
    );
    // 月/日セクション境界
    final midLinePaint = Paint()..color = const Color(0xFF2A2A36);
    canvas.drawLine(const Offset(0, 34), Offset(size.width, 34), midLinePaint);

    // Win版#131 part 23: 今日マーカー (label + 上端三角形)
    final todayDay = DateTime(today.year, today.month, today.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final todayX = todayDay.difference(startDay).inDays * dayWidth;
    if (todayX >= 0 && todayX <= size.width) {
      // 上端の小さな逆三角形 (▼)
      final triPaint = Paint()..color = const Color(0xFFFF6B35);
      final tri = Path()
        ..moveTo(todayX - 5, 0)
        ..lineTo(todayX + 5, 0)
        ..lineTo(todayX, 6)
        ..close();
      canvas.drawPath(tri, triPaint);
      // 「今日 MM/DD」 label
      final todayLabel = TextPainter(
        text: TextSpan(
          text:
              '今日 ${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // label 背景 box
      final boxRect = Rect.fromLTWH(
        todayX - todayLabel.width / 2 - 3,
        7,
        todayLabel.width + 6,
        14,
      );
      final boxPaint = Paint()..color = const Color(0xFF0F0F14);
      final boxBorder = Paint()
        ..color = const Color(0xFFFF6B35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(3));
      canvas.drawRRect(rrect, boxPaint);
      canvas.drawRRect(rrect, boxBorder);
      todayLabel.paint(canvas, Offset(todayX - todayLabel.width / 2, 9));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthHeaderPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.today != today;
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF707070),
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      );
}

/// Win版#131 part 10: イナズマ線 (Lightning Line / 進捗実態線)
///
/// PM 古典の zigzag 進捗線を Gantt に重ねる。
/// 各タスク行で:
///   - 期待進捗 (今日 - start) / (end - start)
///   - 実進捗 task.progress / 100
///   - actual >= expected → 今日 X より右 (進んでいる)
///   - actual <  expected → 今日 X より左 (遅れている)
/// 全タスク行をポリラインで縦に結ぶ。色:
///   - 全体 順調 → Green
///   - 1 タスクでも遅延 → Orange
///   - 遅延 + recovery_plan 未記入 → Red
class _LightningLinePainter extends CustomPainter {
  final List<WbsTask> tasks;
  final double dayWidth;
  final double rowHeight;
  final DateTime timelineStart;
  final DateTime today;
  final double verticalOffset;

  _LightningLinePainter({
    required this.tasks,
    required this.dayWidth,
    required this.rowHeight,
    required this.timelineStart,
    required this.today,
    required this.verticalOffset,
  });

  double _dateToX(DateTime date) {
    final s = DateTime(
      timelineStart.year,
      timelineStart.month,
      timelineStart.day,
    );
    final dt = DateTime(date.year, date.month, date.day);
    return dt.difference(s).inDays * dayWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (tasks.isEmpty) return;
    final todayX = _dateToX(today);
    if (todayX < 0 || todayX > size.width) return;

    final points = <Offset>[];
    bool anyDelay = false;
    bool anyDelayNoPlan = false;
    final firstVisibleIndex = (verticalOffset / rowHeight).floor() - 1;
    final lastVisibleIndex =
        ((verticalOffset + size.height) / rowHeight).ceil() + 1;

    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      double x = todayX;

      if (t.scheduleStartDate != null &&
          t.scheduleEndDate != null &&
          t.status != 'completed') {
        final startX = _dateToX(t.scheduleStartDate!);
        final endX = _dateToX(t.scheduleEndDate!);
        final barWidth = endX - startX;
        if (barWidth > 0) {
          // 期待進捗
          final totalDays =
              t.scheduleEndDate!.difference(t.scheduleStartDate!).inDays;
          final passedDays =
              today.difference(t.scheduleStartDate!).inDays.clamp(0, totalDays);
          final expected = totalDays > 0 ? passedDays / totalDays : 0.0;
          final actual = t.progress / 100.0;

          // 実進捗位置 = bar 内での actual position
          final actualX = startX + barWidth * actual;
          x = actualX;

          // 遅延判定
          if (actual < expected - 0.05) {
            anyDelay = true;
            if (t.recoveryPlan.trim().isEmpty) {
              anyDelayNoPlan = true;
            }
          }
        }
      } else if (t.status == 'completed' || t.scheduleEndDate == null) {
        // 完了済 or 期限なし → 今日 X 維持
        x = todayX;
      }

      // overdue 強制左折れ
      if (t.delayDays > 0) {
        anyDelay = true;
        if (t.recoveryPlan.trim().isEmpty) {
          anyDelayNoPlan = true;
        }
      }

      if (i < firstVisibleIndex || i > lastVisibleIndex) {
        continue;
      }
      final y = i * rowHeight + rowHeight / 2 - verticalOffset;
      if (y < -rowHeight || y > size.height + rowHeight) {
        continue;
      }
      points.add(Offset(x.clamp(0.0, size.width), y));
    }
    if (points.isEmpty) return;

    // 線色決定
    Color lineColor;
    if (anyDelayNoPlan) {
      lineColor = const Color(0xFFEF4444); // Red — 遅延 + 未記入
    } else if (anyDelay) {
      lineColor = const Color(0xFFF97316); // Orange — 遅延あり (recovery 記入済)
    } else {
      lineColor = const Color(0xFF22C55E); // Green — 順調
    }

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // 上下端は today vertical に固定 → 「今日のライン」が基準である事を明示
    final path = Path()..moveTo(todayX, 0);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(todayX, size.height);
    canvas.drawPath(path, paint);

    // 各 anchor に小さな○
    final dotPaint = Paint()..color = lineColor;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightningLinePainter oldDelegate) =>
      oldDelegate.tasks != tasks ||
      oldDelegate.today != today ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.timelineStart != timelineStart ||
      oldDelegate.verticalOffset != verticalOffset;
}
