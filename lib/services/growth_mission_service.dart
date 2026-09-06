import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/referral_code.dart';
import '../models/site_statistics.dart';
import 'app_share_service.dart';
import 'growth_acquisition_service.dart';

class GrowthBenchmarks {
  static const int notionUsersFloor = 100000000;
  static const int evernoteUsersFloor = 250000000;
  static const int beatNotionTarget = notionUsersFloor + 1;
  static const int beatEvernoteTarget = evernoteUsersFloor + 1;
}

enum SessionHygieneState { active, expired, invalidated, unknown, unavailable }

class SessionHygieneStatus {
  static const expiredMessage = 'Session expired. Please sign in again.';

  final SessionHygieneState state;
  final bool requiresRelogin;
  final String message;
  final DateTime? expiresAt;
  final DateTime? invalidatedAt;
  final String? reason;

  const SessionHygieneStatus({
    required this.state,
    required this.requiresRelogin,
    required this.message,
    this.expiresAt,
    this.invalidatedAt,
    this.reason,
  });

  const SessionHygieneStatus.unavailable()
      : state = SessionHygieneState.unavailable,
        requiresRelogin = false,
        message = 'Session hygiene is unavailable.',
        expiresAt = null,
        invalidatedAt = null,
        reason = null;

  const SessionHygieneStatus.active()
      : state = SessionHygieneState.active,
        requiresRelogin = false,
        message = 'Session is active.',
        expiresAt = null,
        invalidatedAt = null,
        reason = null;

  factory SessionHygieneStatus.fromJson(Map<String, dynamic> json) {
    final rawState = (json['status'] as String?)?.toLowerCase();
    final state = switch (rawState) {
      'active' => SessionHygieneState.active,
      'expired' => SessionHygieneState.expired,
      'invalidated' => SessionHygieneState.invalidated,
      'unavailable' => SessionHygieneState.unavailable,
      _ => SessionHygieneState.unknown,
    };
    final inferredRequiresRelogin = state == SessionHygieneState.expired ||
        state == SessionHygieneState.invalidated;
    final requiresRelogin =
        json['requires_relogin'] as bool? ?? inferredRequiresRelogin;

    return SessionHygieneStatus(
      state: state,
      requiresRelogin: requiresRelogin,
      message: json['message'] as String? ??
          (requiresRelogin ? expiredMessage : 'Session state is unknown.'),
      expiresAt: _parseOptionalDateTime(json['expires_at']),
      invalidatedAt: _parseOptionalDateTime(json['invalidated_at']),
      reason: json['reason'] as String?,
    );
  }

  bool get isActive => state == SessionHygieneState.active && !requiresRelogin;

  static DateTime? _parseOptionalDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class ReferralGrowthSnapshot {
  final ReferralCode? myReferralCode;
  final int totalReferrals;
  final int successfulReferrals;
  final int billingConvertedReferrals;
  final List<ReferralBillingChannelSnapshot> billingChannels;
  final String? pendingReferralCode;

  const ReferralGrowthSnapshot({
    required this.myReferralCode,
    required this.totalReferrals,
    required this.successfulReferrals,
    this.billingConvertedReferrals = 0,
    this.billingChannels = const <ReferralBillingChannelSnapshot>[],
    required this.pendingReferralCode,
  });

  const ReferralGrowthSnapshot.empty()
      : myReferralCode = null,
        totalReferrals = 0,
        successfulReferrals = 0,
        billingConvertedReferrals = 0,
        billingChannels = const <ReferralBillingChannelSnapshot>[],
        pendingReferralCode = null;

  String? get referralCode => myReferralCode?.referralCode;

  String? get inviteUrl {
    final code = referralCode;
    if (code == null || code.isEmpty) {
      return null;
    }
    return GrowthMissionService.buildInviteUrlForCode(code);
  }

  double get freeToProConversionRate {
    if (totalReferrals <= 0) {
      return 0;
    }
    return billingConvertedReferrals / totalReferrals;
  }
}

class ReferralBillingChannelSnapshot {
  final String id;
  final String label;
  final int totalReferrals;
  final int proConversions;

  const ReferralBillingChannelSnapshot({
    required this.id,
    required this.label,
    required this.totalReferrals,
    required this.proConversions,
  });

  factory ReferralBillingChannelSnapshot.fromJson(Map<String, dynamic> json) {
    return ReferralBillingChannelSnapshot(
      id: json['id']?.toString() ?? 'referral',
      label: json['label']?.toString() ?? 'Referral',
      totalReferrals: GrowthAcquisitionTouchpointSnapshot._toInt(
        json['totalReferrals'],
      ),
      proConversions: GrowthAcquisitionTouchpointSnapshot._toInt(
        json['proConversions'],
      ),
    );
  }

  double get freeToProConversionRate {
    if (totalReferrals <= 0) {
      return 0;
    }
    return proConversions / totalReferrals;
  }
}

class GrowthAcquisitionTouchpointSnapshot {
  final String id;
  final String label;
  final int touchCount;
  final int signupSubmitCount;

  const GrowthAcquisitionTouchpointSnapshot({
    required this.id,
    required this.label,
    required this.touchCount,
    required this.signupSubmitCount,
  });

  factory GrowthAcquisitionTouchpointSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return GrowthAcquisitionTouchpointSnapshot(
      id: json['id']?.toString() ?? 'touchpoint',
      label: (json['label'] ?? json['touchpoint'])?.toString() ?? 'Touchpoint',
      touchCount: _toInt(json['touchCount'] ?? json['touches']),
      signupSubmitCount: _toInt(json['signupSubmitCount'] ?? json['signups']),
    );
  }

  double get signupSubmitRate {
    if (touchCount <= 0) {
      return 0;
    }
    return signupSubmitCount / touchCount;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class GrowthImportPreviewSnapshot {
  final String id;
  final String label;
  final int previewCount;

  const GrowthImportPreviewSnapshot({
    required this.id,
    required this.label,
    required this.previewCount,
  });

  factory GrowthImportPreviewSnapshot.fromJson(Map<String, dynamic> json) {
    return GrowthImportPreviewSnapshot(
      id: json['id']?.toString() ?? 'preview',
      label: json['label']?.toString() ?? 'Preview',
      previewCount: GrowthAcquisitionTouchpointSnapshot._toInt(
        json['previewCount'],
      ),
    );
  }
}

class GrowthAcquisitionSnapshot {
  final int windowDays;
  final DateTime startDate;
  final DateTime endDate;
  final List<GrowthAcquisitionTouchpointSnapshot> touchpoints;
  final List<GrowthImportPreviewSnapshot> importPreviews;
  final int importSignupCtaCount;
  final int publicMemoSignupCtaCount;

  const GrowthAcquisitionSnapshot({
    required this.windowDays,
    required this.startDate,
    required this.endDate,
    required this.touchpoints,
    required this.importPreviews,
    required this.importSignupCtaCount,
    required this.publicMemoSignupCtaCount,
  });

  factory GrowthAcquisitionSnapshot.empty({int windowDays = 30}) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: math.max(0, windowDays - 1)));
    return GrowthAcquisitionSnapshot(
      windowDays: windowDays,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(now.year, now.month, now.day),
      touchpoints: const <GrowthAcquisitionTouchpointSnapshot>[
        GrowthAcquisitionTouchpointSnapshot(
          id: 'landing',
          label: 'Landing',
          touchCount: 0,
          signupSubmitCount: 0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'import',
          label: 'Import',
          touchCount: 0,
          signupSubmitCount: 0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'public_memo',
          label: 'Public memo',
          touchCount: 0,
          signupSubmitCount: 0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'referral',
          label: 'Referral',
          touchCount: 0,
          signupSubmitCount: 0,
        ),
      ],
      importPreviews: const <GrowthImportPreviewSnapshot>[
        GrowthImportPreviewSnapshot(
          id: 'notion',
          label: 'Notion previews',
          previewCount: 0,
        ),
        GrowthImportPreviewSnapshot(
          id: 'evernote',
          label: 'Evernote previews',
          previewCount: 0,
        ),
        GrowthImportPreviewSnapshot(
          id: 'markdown',
          label: 'Markdown previews',
          previewCount: 0,
        ),
      ],
      importSignupCtaCount: 0,
      publicMemoSignupCtaCount: 0,
    );
  }

  factory GrowthAcquisitionSnapshot.fromJson(Map<String, dynamic> json) {
    final windowDays = GrowthAcquisitionTouchpointSnapshot._toInt(
      json['windowDays'],
    );
    return GrowthAcquisitionSnapshot(
      windowDays: windowDays <= 0 ? 30 : windowDays,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ??
          DateTime.now(),
      touchpoints: (json['touchpoints'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => GrowthAcquisitionTouchpointSnapshot.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      importPreviews:
          (json['importPreviews'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => GrowthImportPreviewSnapshot.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      importSignupCtaCount: GrowthAcquisitionTouchpointSnapshot._toInt(
        json['importSignupCtaCount'],
      ),
      publicMemoSignupCtaCount: GrowthAcquisitionTouchpointSnapshot._toInt(
        json['publicMemoSignupCtaCount'],
      ),
    );
  }

  int get totalTouches =>
      touchpoints.fold<int>(0, (sum, item) => sum + item.touchCount);

  int get totalSignupSubmits =>
      touchpoints.fold<int>(0, (sum, item) => sum + item.signupSubmitCount);
}

class GrowthMissionDashboard {
  final int totalRegisteredUsers;
  final int todayRegistrations;
  final int activeUsersToday;
  final int liveRegisteredUsers;
  final int liveGuestViewers;
  final int todayLandingViews;
  final int monthLandingViews;
  final int totalLandingViews;
  final int todayShares;
  final ReferralGrowthSnapshot referralSnapshot;
  final GrowthAcquisitionSnapshot acquisitionSnapshot;
  final DateTime refreshedAt;

  const GrowthMissionDashboard({
    required this.totalRegisteredUsers,
    required this.todayRegistrations,
    required this.activeUsersToday,
    required this.liveRegisteredUsers,
    required this.liveGuestViewers,
    required this.todayLandingViews,
    required this.monthLandingViews,
    required this.totalLandingViews,
    required this.todayShares,
    required this.referralSnapshot,
    required this.acquisitionSnapshot,
    required this.refreshedAt,
  });

  factory GrowthMissionDashboard.empty() {
    return GrowthMissionDashboard(
      totalRegisteredUsers: 0,
      todayRegistrations: 0,
      activeUsersToday: 0,
      liveRegisteredUsers: 0,
      liveGuestViewers: 0,
      todayLandingViews: 0,
      monthLandingViews: 0,
      totalLandingViews: 0,
      todayShares: 0,
      referralSnapshot: const ReferralGrowthSnapshot.empty(),
      acquisitionSnapshot: GrowthAcquisitionSnapshot.empty(),
      refreshedAt: DateTime.now(),
    );
  }

  int get liveViewers => liveRegisteredUsers + liveGuestViewers;

  int get gapToBeatNotion =>
      math.max(0, GrowthBenchmarks.beatNotionTarget - totalRegisteredUsers);

  int get gapToBeatEvernote =>
      math.max(0, GrowthBenchmarks.beatEvernoteTarget - totalRegisteredUsers);

  double get progressToBeatNotion =>
      totalRegisteredUsers / GrowthBenchmarks.beatNotionTarget;

  double get progressToBeatEvernote =>
      totalRegisteredUsers / GrowthBenchmarks.beatEvernoteTarget;
}

class GrowthDepartmentBrief {
  final String id;
  final String label;
  final String owner;
  final String priority;
  final String objective;
  final List<String> actions;

  const GrowthDepartmentBrief({
    required this.id,
    required this.label,
    required this.owner,
    required this.priority,
    required this.objective,
    required this.actions,
  });

  factory GrowthDepartmentBrief.fromJson(Map<String, dynamic> json) {
    return GrowthDepartmentBrief(
      id: json['id']?.toString() ?? 'department',
      label: json['label']?.toString() ?? 'Department',
      owner: json['owner']?.toString() ?? 'TBD',
      priority: json['priority']?.toString() ?? 'P1',
      objective: json['objective']?.toString() ?? '',
      actions: (json['actions'] as List<dynamic>? ?? const <dynamic>[])
          .map((action) => action.toString())
          .where((action) => action.trim().isNotEmpty)
          .toList(),
    );
  }
}

class GrowthCommandCenterBrief {
  final String stageLabel;
  final String stageReason;
  final List<String> focusTags;
  final List<GrowthDepartmentBrief> departments;
  final DateTime generatedAt;

  const GrowthCommandCenterBrief({
    required this.stageLabel,
    required this.stageReason,
    required this.focusTags,
    required this.departments,
    required this.generatedAt,
  });

  factory GrowthCommandCenterBrief.empty() {
    return GrowthCommandCenterBrief(
      stageLabel: 'Pre-PMF',
      stageReason: 'Waiting for growth data.',
      focusTags: const <String>[],
      departments: const <GrowthDepartmentBrief>[],
      generatedAt: DateTime.now(),
    );
  }

  factory GrowthCommandCenterBrief.fromJson(Map<String, dynamic> json) {
    return GrowthCommandCenterBrief(
      stageLabel: json['stageLabel']?.toString() ?? 'Pre-PMF',
      stageReason: json['stageReason']?.toString() ?? '',
      focusTags: (json['focusTags'] as List<dynamic>? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(),
      departments: (json['departments'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (department) => GrowthDepartmentBrief.fromJson(
              Map<String, dynamic>.from(department),
            ),
          )
          .toList(),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Digest
// ---------------------------------------------------------------------------

class WeeklyDigestChannelMetrics {
  final String id;
  final String label;
  final int touches;
  final int signupSubmits;
  final int cvr;
  final int touchesDelta;
  final int signupSubmitsDelta;

  const WeeklyDigestChannelMetrics({
    required this.id,
    required this.label,
    required this.touches,
    required this.signupSubmits,
    required this.cvr,
    required this.touchesDelta,
    required this.signupSubmitsDelta,
  });

  factory WeeklyDigestChannelMetrics.fromJson(Map<String, dynamic> json) {
    return WeeklyDigestChannelMetrics(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      touches: (json['touches'] as num?)?.toInt() ?? 0,
      signupSubmits: (json['signupSubmits'] as num?)?.toInt() ?? 0,
      cvr: (json['cvr'] as num?)?.toInt() ?? 0,
      touchesDelta: (json['touchesDelta'] as num?)?.toInt() ?? 0,
      signupSubmitsDelta: (json['signupSubmitsDelta'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeeklyDigestDecision {
  final String id;
  final String owner;
  final String priorityChannelId;
  final String priorityChannelLabel;
  final int targetCvr;
  final int minimumTouches;
  final String nextAction;
  final String dueDate;
  final String outcomeStatus;

  const WeeklyDigestDecision({
    required this.id,
    required this.owner,
    required this.priorityChannelId,
    required this.priorityChannelLabel,
    required this.targetCvr,
    required this.minimumTouches,
    required this.nextAction,
    required this.dueDate,
    required this.outcomeStatus,
  });

  const WeeklyDigestDecision.empty()
      : id = '',
        owner = '',
        priorityChannelId = '',
        priorityChannelLabel = '',
        targetCvr = 0,
        minimumTouches = 0,
        nextAction = '',
        dueDate = '',
        outcomeStatus = '';

  factory WeeklyDigestDecision.fromJson(Map<String, dynamic> json) {
    final priorityChannel = _weeklyDigestMap(json['priorityChannel']);
    final threshold = _weeklyDigestMap(json['threshold']);
    final outcome = _weeklyDigestMap(json['outcome']);
    return WeeklyDigestDecision(
      id: json['id']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      priorityChannelId: priorityChannel['id']?.toString() ?? '',
      priorityChannelLabel: priorityChannel['label']?.toString() ?? '',
      targetCvr: (threshold['target'] as num?)?.toInt() ?? 0,
      minimumTouches: (threshold['minimumTouches'] as num?)?.toInt() ?? 0,
      nextAction: json['nextAction']?.toString() ?? '',
      dueDate: json['dueDate']?.toString() ?? '',
      outcomeStatus: outcome['status']?.toString() ?? '',
    );
  }
}

class WeeklyDigestDecisionOutcome {
  final String decisionId;
  final String priorityChannelId;
  final String priorityChannelLabel;
  final String status;
  final int actualCvr;
  final int actualTouches;
  final int actualSignupSubmits;

  const WeeklyDigestDecisionOutcome({
    required this.decisionId,
    required this.priorityChannelId,
    required this.priorityChannelLabel,
    required this.status,
    required this.actualCvr,
    required this.actualTouches,
    required this.actualSignupSubmits,
  });

  const WeeklyDigestDecisionOutcome.empty()
      : decisionId = '',
        priorityChannelId = '',
        priorityChannelLabel = '',
        status = '',
        actualCvr = 0,
        actualTouches = 0,
        actualSignupSubmits = 0;

  factory WeeklyDigestDecisionOutcome.fromJson(Map<String, dynamic> json) {
    final priorityChannel = _weeklyDigestMap(json['priorityChannel']);
    final actual = _weeklyDigestMap(json['actual']);
    return WeeklyDigestDecisionOutcome(
      decisionId: json['decisionId']?.toString() ?? '',
      priorityChannelId: priorityChannel['id']?.toString() ?? '',
      priorityChannelLabel: priorityChannel['label']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      actualCvr: (actual['cvr'] as num?)?.toInt() ?? 0,
      actualTouches: (actual['touches'] as num?)?.toInt() ?? 0,
      actualSignupSubmits: (actual['signupSubmits'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeeklyDigestSnapshot {
  final String currentWeekStart;
  final String currentWeekEnd;
  final List<WeeklyDigestChannelMetrics> channels;
  final int signupSubmitTotal;
  final int signupSubmitDelta;
  final int referralsCompleted;
  final int referralsDelta;
  final int importCtaClicks;
  final int publicMemoCtaClicks;
  final WeeklyDigestDecision decision;
  final WeeklyDigestDecisionOutcome previousDecisionOutcome;
  final String brief;

  const WeeklyDigestSnapshot({
    required this.currentWeekStart,
    required this.currentWeekEnd,
    required this.channels,
    required this.signupSubmitTotal,
    required this.signupSubmitDelta,
    required this.referralsCompleted,
    required this.referralsDelta,
    required this.importCtaClicks,
    required this.publicMemoCtaClicks,
    required this.decision,
    required this.previousDecisionOutcome,
    required this.brief,
  });

  const WeeklyDigestSnapshot.empty()
      : currentWeekStart = '',
        currentWeekEnd = '',
        channels = const [],
        signupSubmitTotal = 0,
        signupSubmitDelta = 0,
        referralsCompleted = 0,
        referralsDelta = 0,
        importCtaClicks = 0,
        publicMemoCtaClicks = 0,
        decision = const WeeklyDigestDecision.empty(),
        previousDecisionOutcome = const WeeklyDigestDecisionOutcome.empty(),
        brief = '';

  factory WeeklyDigestSnapshot.fromJson(Map<String, dynamic> json) {
    final currentWeek = json['currentWeek'];
    final channels = <WeeklyDigestChannelMetrics>[];
    if (json['channels'] is List) {
      for (final c in json['channels'] as List<dynamic>) {
        if (c is Map) {
          channels.add(
            WeeklyDigestChannelMetrics.fromJson(Map<String, dynamic>.from(c)),
          );
        }
      }
    }
    return WeeklyDigestSnapshot(
      currentWeekStart:
          (currentWeek is Map ? currentWeek['startDate'] : null)?.toString() ??
              '',
      currentWeekEnd:
          (currentWeek is Map ? currentWeek['endDate'] : null)?.toString() ??
              '',
      channels: channels,
      signupSubmitTotal: (json['signupSubmitTotal'] as num?)?.toInt() ?? 0,
      signupSubmitDelta: (json['signupSubmitDelta'] as num?)?.toInt() ?? 0,
      referralsCompleted: (json['referralsCompleted'] as num?)?.toInt() ?? 0,
      referralsDelta: (json['referralsDelta'] as num?)?.toInt() ?? 0,
      importCtaClicks: (json['importCtaClicks'] as num?)?.toInt() ?? 0,
      publicMemoCtaClicks: (json['publicMemoCtaClicks'] as num?)?.toInt() ?? 0,
      decision: WeeklyDigestDecision.fromJson(
        _weeklyDigestMap(json['decision']),
      ),
      previousDecisionOutcome: WeeklyDigestDecisionOutcome.fromJson(
        _weeklyDigestMap(json['previousDecisionOutcome']),
      ),
      brief: json['brief']?.toString() ?? '',
    );
  }
}

Map<String, dynamic> _weeklyDigestMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

class GrowthMissionService {
  static const _guestSessionIdKey = 'growth_guest_session_id';
  static const _pendingReferralCodeKey = 'growth_pending_referral_code';
  static const _referralAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const Duration _aggregateRefreshCooldown = Duration(minutes: 3);
  static const Duration _sessionHygieneTimeout = Duration(hours: 48);
  static DateTime? _lastAggregateRefreshAt;
  static Future<void>? _aggregateRefreshInFlight;

  // #551 Phase 1: guest→user 遷移時のみ guest_presence.delete を発火し
  // heartbeat ごとの無駄な DELETE を抑止する。
  static String? _lastGuestCleanupSession;

  final SupabaseClient? _clientOverride;

  const GrowthMissionService({SupabaseClient? clientOverride})
      : _clientOverride = clientOverride;

  SupabaseClient? get _client {
    if (_clientOverride != null) {
      return _clientOverride;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isPresenceTrackingAvailable => _client != null;

  static String buildInviteUrlForCode(String code) {
    final baseUri = Uri.parse(AppShareService.appUrl);
    final nextQuery = Map<String, String>.from(baseUri.queryParameters)
      ..['ref'] = code
      ..['utm_source'] = 'referral'
      ..['utm_medium'] = 'invite'
      ..['utm_campaign'] = 'growth_mission';
    return baseUri
        .replace(path: '/referral', queryParameters: nextQuery)
        .toString();
  }

  static String buildInviteCopyText({
    required String inviteUrl,
    required int totalRegisteredUsers,
    required int liveViewers,
  }) {
    return '''
閾ｪ蛻・ｪ蠑丈ｼ夂､ｾ繧剃ｸ邱偵↓隧ｦ縺励※縺上□縺輔＞縲・莉翫・逋ｻ骭ｲ閠・$totalRegisteredUsers 莠ｺ縲∫樟蝨ｨ髢ｲ隕ｧ $liveViewers 莠ｺ縺ｧ縺吶・
諡帛ｾ・Μ繝ｳ繧ｯ:
$inviteUrl
''';
  }

  static String buildReferralInviteMessage({
    required String inviteUrl,
    required int totalRegisteredUsers,
    required int liveViewers,
  }) {
    return '''
Trying to build a note app that can eventually beat Notion and Evernote takes real users and honest feedback.

Current live snapshot:
- Registered users: $totalRegisteredUsers
- Live viewers: $liveViewers

Join from this invite:
$inviteUrl
''';
  }

  Future<void> capturePendingReferralFromUri({Uri? currentUri}) async {
    final uri = currentUri ?? Uri.base;
    final refCode = (uri.queryParameters['ref'] ?? uri.queryParameters['code'])
        ?.trim()
        .toUpperCase();
    if (refCode == null || refCode.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralCodeKey, refCode);
    unawaited(const GrowthAcquisitionService().recordReferralTouch());
  }

  Future<String?> loadPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingReferralCodeKey)?.trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return null;
    }
    return code;
  }

  Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReferralCodeKey);
  }

  Future<String> ensureGuestSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_guestSessionIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = const Uuid().v4();
    await prefs.setString(_guestSessionIdKey, created);
    return created;
  }

  Future<void> resetLocalPresenceSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestSessionIdKey);
    _lastGuestCleanupSession = null;
  }

  Future<void> syncPresence({required String pagePath}) async {
    final client = _client;
    if (client == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final sessionId = await ensureGuestSessionId();
    final user = client.auth.currentUser;

    try {
      if (user != null) {
        final hygieneStatus = await checkSessionHygiene(sessionId: sessionId);
        if (hygieneStatus.requiresRelogin) {
          await _signOutForExpiredSession(client, hygieneStatus);
          return;
        }

        await client.from('user_presence').upsert(
          <String, dynamic>{
            'user_id': user.id,
            'session_id': sessionId,
            'is_online': true,
            'last_seen': nowIso,
            'expires_at': now.add(_sessionHygieneTimeout).toIso8601String(),
            'invalidated_at': null,
            'invalidation_reason': null,
            'page_path': pagePath,
          },
          onConflict: 'user_id,session_id',
        );

        if (_lastGuestCleanupSession != sessionId) {
          await client
              .from('guest_presence')
              .delete()
              .eq('session_id', sessionId)
              .select();
          _lastGuestCleanupSession = sessionId;
        }
      } else {
        await client.from('guest_presence').upsert(
          <String, dynamic>{
            'session_id': sessionId,
            'last_seen': nowIso,
            'page_path': pagePath,
          },
          onConflict: 'session_id',
        );
      }
    } catch (error) {
      debugPrint('Growth presence sync failed: $error');
    }
  }

  Future<SessionHygieneStatus> checkSessionHygiene({String? sessionId}) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      return const SessionHygieneStatus.unavailable();
    }

    final resolvedSessionId = sessionId ?? await ensureGuestSessionId();
    try {
      final response = await client.rpc(
        'get_session_hygiene_status',
        params: <String, dynamic>{'p_session_id': resolvedSessionId},
      );
      if (response is Map<String, dynamic>) {
        return SessionHygieneStatus.fromJson(response);
      }
      if (response is Map) {
        return SessionHygieneStatus.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
    } catch (error) {
      debugPrint('get_session_hygiene_status failed: $error');
    }

    return const SessionHygieneStatus(
      state: SessionHygieneState.unknown,
      requiresRelogin: false,
      message: 'Session hygiene status could not be checked.',
    );
  }

  Future<void> _signOutForExpiredSession(
    SupabaseClient client,
    SessionHygieneStatus status,
  ) async {
    debugPrint(status.message);
    try {
      await client.auth.signOut();
    } catch (error) {
      debugPrint('Session hygiene signOut failed: $error');
    } finally {
      await resetLocalPresenceSession();
    }
  }

  Future<void> refreshAggregateMetrics({bool force = false}) async {
    final client = _client;
    if (client == null) {
      return;
    }

    final DateTime now = DateTime.now();
    if (!force) {
      final Future<void>? inFlight = _aggregateRefreshInFlight;
      if (inFlight != null) {
        await inFlight;
        return;
      }

      final DateTime? lastRefreshedAt = _lastAggregateRefreshAt;
      if (lastRefreshedAt != null &&
          now.difference(lastRefreshedAt) < _aggregateRefreshCooldown) {
        return;
      }
    }

    final Future<void> refreshFuture = _runAggregateRefresh(client);
    _aggregateRefreshInFlight = refreshFuture;
    try {
      await refreshFuture;
      _lastAggregateRefreshAt = DateTime.now();
    } finally {
      if (identical(_aggregateRefreshInFlight, refreshFuture)) {
        _aggregateRefreshInFlight = null;
      }
    }
  }

  Future<void> _runAggregateRefresh(SupabaseClient client) async {
    try {
      await client.rpc('update_site_statistics');
    } catch (error) {
      debugPrint('update_site_statistics failed: $error');
    }
  }

  Future<ReferralCode?> ensureMyReferralCode() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return null;
    }

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: const <String, dynamic>{'action': 'referral.list'},
      );
      final data = _toMapValue(response.data);
      if (data['success'] == true) {
        final referralCode = _toMapValue(data['referralCode']);
        if (referralCode.isNotEmpty) {
          return ReferralCode.fromJson(referralCode);
        }
      }
    } catch (error) {
      debugPrint('Referral ensure edge function fallback: $error');
    }

    final existingCode = await _fetchMyReferralCode(
      client: client,
      userId: user.id,
    );
    if (existingCode != null) {
      return existingCode;
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final generatedCode = _generateReferralCode();
      try {
        await client.from('referral_codes').insert(<String, dynamic>{
          'user_id': user.id,
          'referral_code': generatedCode,
        });
        return await _fetchMyReferralCode(client: client, userId: user.id);
      } catch (error) {
        debugPrint('Referral code insert retry $attempt failed: $error');
      }
    }

    return _fetchMyReferralCode(client: client, userId: user.id);
  }

  Future<ReferralCode?> _fetchMyReferralCode({
    required SupabaseClient client,
    required String userId,
  }) async {
    try {
      final existing = await client
          .from('referral_codes')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (existing == null) {
        return null;
      }
      return ReferralCode.fromJson(existing);
    } catch (error) {
      debugPrint('Referral code fetch failed: $error');
    }
    return null;
  }

  Future<void> applyPendingReferralIfPossible() async {
    final client = _client;
    final user = client?.auth.currentUser;
    final pendingCode = await loadPendingReferralCode();
    if (client == null || user == null || pendingCode == null) {
      return;
    }

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'referral.list',
          'pendingCode': pendingCode,
        },
      );
      final data = _toMapValue(response.data);
      if (data['success'] == true) {
        if (data['clearPendingCode'] == true) {
          await clearPendingReferralCode();
        }
        return;
      }
    } catch (error) {
      debugPrint('Referral apply edge function fallback: $error');
    }

    try {
      final existing = await client
          .from('referrals')
          .select('id')
          .eq('referred_user_id', user.id)
          .maybeSingle();
      if (existing != null) {
        await clearPendingReferralCode();
        return;
      }

      final referrer = await client
          .from('referral_codes')
          .select('user_id, referral_code')
          .eq('referral_code', pendingCode)
          .maybeSingle();
      if (referrer == null) {
        return;
      }
      final referrerMap = Map<String, dynamic>.from(referrer);

      final referrerUserId = referrerMap['user_id']?.toString();
      if (referrerUserId == null || referrerUserId == user.id) {
        await clearPendingReferralCode();
        return;
      }

      await client.from('referrals').insert(<String, dynamic>{
        'referrer_user_id': referrerUserId,
        'referred_user_id': user.id,
        'referral_code': pendingCode,
        'bonus_points': 500,
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      });

      await clearPendingReferralCode();
    } catch (error) {
      debugPrint('Applying pending referral failed: $error');
    }
  }

  Future<ReferralGrowthSnapshot> loadReferralSnapshot() async {
    final pendingCode = await loadPendingReferralCode();
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return ReferralGrowthSnapshot(
        myReferralCode: null,
        totalReferrals: 0,
        successfulReferrals: 0,
        billingConvertedReferrals: 0,
        pendingReferralCode: pendingCode,
      );
    }

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: const <String, dynamic>{'action': 'referral.list'},
      );
      final data = _toMapValue(response.data);
      if (data['success'] == true) {
        final referralCodeRow = _toMapValue(data['referralCode']);
        return ReferralGrowthSnapshot(
          myReferralCode: referralCodeRow.isEmpty
              ? null
              : ReferralCode.fromJson(referralCodeRow),
          totalReferrals: _toIntValue(data['totalReferrals']),
          successfulReferrals: _toIntValue(data['successfulReferrals']),
          billingConvertedReferrals: _toIntValue(
            data['billingConvertedReferrals'],
          ),
          billingChannels:
              (data['billingChannels'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<Map>()
                  .map(
                    (row) => ReferralBillingChannelSnapshot.fromJson(
                      Map<String, dynamic>.from(row),
                    ),
                  )
                  .toList(),
          pendingReferralCode: pendingCode,
        );
      }
    } catch (error) {
      debugPrint('Referral snapshot edge function fallback: $error');
    }

    final myCode = await ensureMyReferralCode();
    try {
      final rows = await client
          .from('referrals')
          .select('referred_user_id, status')
          .eq('referrer_user_id', user.id);
      final referralRows = rows;
      final successful = referralRows.where((row) {
        return row['status']?.toString() == 'completed';
      }).length;
      final referredUserIds = referralRows
          .map((row) => row['referred_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      var billingConverted = 0;
      if (referredUserIds.isNotEmpty) {
        final billingRows = await client
            .from('billing_subscriptions')
            .select('user_id, tier, status')
            .inFilter('user_id', referredUserIds);
        billingConverted = billingRows.where((row) {
          final tier = row['tier']?.toString();
          final status = row['status']?.toString();
          return (tier == 'pro' || tier == 'team') &&
              (status == 'active' || status == 'trialing');
        }).length;
      }

      return ReferralGrowthSnapshot(
        myReferralCode: myCode,
        totalReferrals: referralRows.length,
        successfulReferrals: successful,
        billingConvertedReferrals: billingConverted,
        billingChannels: [
          ReferralBillingChannelSnapshot(
            id: 'referral',
            label: 'Referral',
            totalReferrals: referralRows.length,
            proConversions: billingConverted,
          ),
        ],
        pendingReferralCode: pendingCode,
      );
    } catch (error) {
      debugPrint('Referral snapshot failed: $error');
      return ReferralGrowthSnapshot(
        myReferralCode: myCode,
        totalReferrals: 0,
        successfulReferrals: 0,
        billingConvertedReferrals: 0,
        pendingReferralCode: pendingCode,
      );
    }
  }

  Future<GrowthAcquisitionSnapshot> loadAcquisitionSnapshot({
    int windowDays = 30,
  }) async {
    final client = _client;
    if (client == null) {
      return GrowthAcquisitionSnapshot.empty(windowDays: windowDays);
    }

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'acquisition.touchpoint_report',
          'windowDays': windowDays,
        },
      );
      final data = _toMapValue(response.data);
      if (data['success'] == true) {
        final report = _toMapValue(data['report']);
        return GrowthAcquisitionSnapshot.fromJson(
          report.isEmpty ? data : report,
        );
      }
    } catch (error) {
      debugPrint('Acquisition snapshot edge function fallback: $error');
    }

    try {
      final now = DateTime.now();
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: math.max(0, windowDays - 1)));
      final rows = await client
          .from('app_analytics')
          .select('source_details')
          .gte('date', _formatDate(startDate))
          .lte('date', _formatDate(now));
      final aggregated = <String, int>{};
      for (final row in rows) {
        _mergeSourceCounts(aggregated, row['source_details']);
      }
      return _buildAcquisitionSnapshotFromSourceCounts(
        aggregated,
        windowDays: windowDays,
        now: now,
      );
    } catch (error) {
      debugPrint('Acquisition snapshot fallback failed: $error');
      return GrowthAcquisitionSnapshot.empty(windowDays: windowDays);
    }
  }

  Future<GrowthMissionDashboard> loadDashboard() async {
    final client = _client;
    if (client == null) {
      return GrowthMissionDashboard.empty();
    }

    await refreshAggregateMetrics();

    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final activeUserCutoff =
        now.subtract(const Duration(minutes: 5)).toUtc().toIso8601String();
    final guestCutoff =
        now.subtract(const Duration(minutes: 30)).toUtc().toIso8601String();

    try {
      final results = await Future.wait<dynamic>([
        client
            .from('site_statistics')
            .select()
            .order('stat_date', ascending: false)
            .limit(1)
            .maybeSingle(),
        client
            .from('user_presence')
            .select('session_id')
            .eq('is_online', true)
            .gte('last_seen', activeUserCutoff),
        client
            .from('guest_presence')
            .select('session_id')
            .gte('last_seen', guestCutoff),
        client.rpc('get_lp_view_stats'),
        client
            .from('app_analytics')
            .select('share_count')
            .eq('date', todayKey)
            .maybeSingle(),
        loadReferralSnapshot(),
        loadAcquisitionSnapshot(),
      ]);

      final statRow = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : null;
      final latestStat =
          statRow == null ? null : SiteStatistics.fromJson(statRow);
      final activeUserRows =
          results[1] is List ? results[1] as List<dynamic> : const <dynamic>[];
      final guestRows =
          results[2] is List ? results[2] as List<dynamic> : const <dynamic>[];
      final lpStats = results[3] is Map
          ? Map<String, dynamic>.from(results[3] as Map)
          : <String, dynamic>{};
      final analyticsRow = results[4] is Map
          ? Map<String, dynamic>.from(results[4] as Map)
          : <String, dynamic>{};
      final referralSnapshot = results[5] is ReferralGrowthSnapshot
          ? results[5] as ReferralGrowthSnapshot
          : const ReferralGrowthSnapshot.empty();
      final acquisitionSnapshot = results[6] is GrowthAcquisitionSnapshot
          ? results[6] as GrowthAcquisitionSnapshot
          : GrowthAcquisitionSnapshot.empty();

      return GrowthMissionDashboard(
        totalRegisteredUsers: latestStat?.totalUsers ?? 0,
        todayRegistrations: latestStat?.newUsersToday ?? 0,
        activeUsersToday: latestStat?.activeUsersToday ?? 0,
        liveRegisteredUsers: activeUserRows.length,
        liveGuestViewers: guestRows.length,
        todayLandingViews: _toIntValue(lpStats['today']),
        monthLandingViews: _toIntValue(lpStats['month']),
        totalLandingViews: _toIntValue(lpStats['total']),
        todayShares: _toIntValue(analyticsRow['share_count']),
        referralSnapshot: referralSnapshot,
        acquisitionSnapshot: acquisitionSnapshot,
        refreshedAt: now,
      );
    } catch (error) {
      debugPrint('Growth dashboard load failed: $error');
      return GrowthMissionDashboard.empty();
    }
  }

  Future<GrowthCommandCenterBrief> loadCommandCenterBrief(
    GrowthMissionDashboard dashboard,
  ) async {
    final client = _client;
    if (client == null) {
      return _buildLocalCommandCenterBrief(dashboard);
    }

    try {
      final response = await client.functions.invoke(
        'growth-hub',
        body: <String, dynamic>{
          'action': 'command.analyze',
          'totalRegisteredUsers': dashboard.totalRegisteredUsers,
          'todayRegistrations': dashboard.todayRegistrations,
          'activeUsersToday': dashboard.activeUsersToday,
          'liveViewers': dashboard.liveViewers,
          'todayLandingViews': dashboard.todayLandingViews,
          'monthLandingViews': dashboard.monthLandingViews,
          'todayShares': dashboard.todayShares,
          'gapToBeatNotion': dashboard.gapToBeatNotion,
          'gapToBeatEvernote': dashboard.gapToBeatEvernote,
          'progressToBeatNotion': dashboard.progressToBeatNotion,
          'progressToBeatEvernote': dashboard.progressToBeatEvernote,
          'successfulReferrals': dashboard.referralSnapshot.successfulReferrals,
          'totalReferrals': dashboard.referralSnapshot.totalReferrals,
        },
      );

      final data = _toMapValue(response.data);
      if (data['success'] != true) {
        throw Exception(
          data['error']?.toString() ?? 'Growth command center failed.',
        );
      }

      return GrowthCommandCenterBrief.fromJson(_toMapValue(data['brief']));
    } catch (error) {
      debugPrint('Growth command center fallback: $error');
      return _buildLocalCommandCenterBrief(dashboard);
    }
  }

  Future<WeeklyDigestSnapshot> loadWeeklyDigest() async {
    final client = _client;
    if (client == null) {
      return const WeeklyDigestSnapshot.empty();
    }

    try {
      final response = await client.functions.invoke(
        'growth-weekly-digest',
        body: <String, dynamic>{},
      );

      final data = _toMapValue(response.data);
      if (data['success'] != true) {
        throw Exception(data['error']?.toString() ?? 'Weekly digest failed.');
      }

      // R30: edge は {success, digest:{currentWeek,...}} と nested で返す。
      // 兄弟の command-center brief (data['brief']) は unwrap しているのに
      // ここだけ top-level を渡していたため fromJson が全キー null →
      // currentWeekStart='' → カードが常に「計測待ち」を表示していた
      // (成功レスポンス+実データでも空表示)。digest を unwrap する。
      return WeeklyDigestSnapshot.fromJson(_toMapValue(data['digest']));
    } catch (error) {
      debugPrint('Weekly digest fallback: $error');
      return const WeeklyDigestSnapshot.empty();
    }
  }

  String _generateReferralCode() {
    final random = math.Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      final index = random.nextInt(_referralAlphabet.length);
      buffer.write(_referralAlphabet[index]);
    }
    return buffer.toString();
  }

  int _toIntValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> _toMapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  void _mergeSourceCounts(Map<String, int> target, dynamic raw) {
    if (raw is! Map) {
      return;
    }

    raw.forEach((key, value) {
      final signalKey = key.toString();
      final count = _toIntValue(value);
      if (signalKey.isEmpty || count <= 0) {
        return;
      }
      target.update(
        signalKey,
        (current) => current + count,
        ifAbsent: () => count,
      );
    });
  }

  GrowthAcquisitionSnapshot _buildAcquisitionSnapshotFromSourceCounts(
    Map<String, int> sourceCounts, {
    required int windowDays,
    required DateTime now,
  }) {
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: math.max(0, windowDays - 1)));

    return GrowthAcquisitionSnapshot(
      windowDays: windowDays,
      startDate: startDate,
      endDate: DateTime(now.year, now.month, now.day),
      touchpoints: <GrowthAcquisitionTouchpointSnapshot>[
        GrowthAcquisitionTouchpointSnapshot(
          id: 'landing',
          label: 'Landing',
          touchCount: sourceCounts[GrowthAcquisitionService.touchLanding] ?? 0,
          signupSubmitCount:
              sourceCounts[GrowthAcquisitionService.signupSubmitLanding] ?? 0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'import',
          label: 'Import',
          touchCount: sourceCounts[GrowthAcquisitionService.touchImport] ?? 0,
          signupSubmitCount:
              sourceCounts[GrowthAcquisitionService.signupSubmitImport] ?? 0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'public_memo',
          label: 'Public memo',
          touchCount:
              sourceCounts[GrowthAcquisitionService.touchPublicMemo] ?? 0,
          signupSubmitCount:
              sourceCounts[GrowthAcquisitionService.signupSubmitPublicMemo] ??
                  0,
        ),
        GrowthAcquisitionTouchpointSnapshot(
          id: 'referral',
          label: 'Referral',
          touchCount: sourceCounts[GrowthAcquisitionService.touchReferral] ?? 0,
          signupSubmitCount:
              sourceCounts[GrowthAcquisitionService.signupSubmitReferral] ?? 0,
        ),
      ],
      importPreviews: <GrowthImportPreviewSnapshot>[
        GrowthImportPreviewSnapshot(
          id: 'notion',
          label: 'Notion previews',
          previewCount:
              sourceCounts[GrowthAcquisitionService.importPreviewNotion] ?? 0,
        ),
        GrowthImportPreviewSnapshot(
          id: 'evernote',
          label: 'Evernote previews',
          previewCount:
              sourceCounts[GrowthAcquisitionService.importPreviewEvernote] ?? 0,
        ),
        GrowthImportPreviewSnapshot(
          id: 'markdown',
          label: 'Markdown previews',
          previewCount:
              sourceCounts[GrowthAcquisitionService.importPreviewMarkdown] ?? 0,
        ),
      ],
      importSignupCtaCount:
          sourceCounts[GrowthAcquisitionService.importSignupCta] ?? 0,
      publicMemoSignupCtaCount:
          sourceCounts[GrowthAcquisitionService.publicMemoSignupCta] ?? 0,
    );
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  GrowthCommandCenterBrief _buildLocalCommandCenterBrief(
    GrowthMissionDashboard dashboard,
  ) {
    final totalUsers = dashboard.totalRegisteredUsers;
    final stageLabel = totalUsers < 100
        ? 'Pre-PMF'
        : totalUsers < 1000
            ? 'Early traction'
            : 'Scale-up';
    final stageReason = totalUsers < 100
        ? 'The product still needs user acquisition loops and tighter activation.'
        : totalUsers < 1000
            ? 'The product is showing traction and needs repeatable channels.'
            : 'The product needs process, hiring, and channel scaling discipline.';

    return GrowthCommandCenterBrief(
      stageLabel: stageLabel,
      stageReason: stageReason,
      focusTags: <String>[
        'public-memo-seo',
        'notion-evernote-import',
        'referral-loop',
        if (dashboard.todayRegistrations == 0) 'registration-bottleneck',
        if (dashboard.todayShares == 0) 'share-bottleneck',
      ],
      departments: <GrowthDepartmentBrief>[
        const GrowthDepartmentBrief(
          id: 'development',
          label: 'Development',
          owner: 'Engineering',
          priority: 'P0',
          objective:
              'Keep linter at zero and continue moving growth-critical logic into Supabase Edge Functions.',
          actions: <String>[
            'Keep route-level acquisition signals live across landing, import, referral, and public memo flows, then expand assisted conversion reporting.',
            'Keep competitor migration flows backend-first from preview through commit.',
            'Keep growth-facing screens analyzable with zero lint issues.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'product',
          label: 'Product',
          owner: 'Product',
          priority: 'P0',
          objective:
              'Tighten activation from landing page to first imported note or first public memo.',
          actions: <String>[
            'Keep import preview and public memo sign-up prompts measurable and easy to reach.',
            'Carry acquisition touchpoints into sign-up intent tracking.',
            'Reduce first-value time for new users from visit to first saved note.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'advertising',
          label: 'Advertising',
          owner: 'Growth',
          priority: 'P1',
          objective:
              'Spend only after conversion instrumentation is stable enough to protect CAC.',
          actions: <String>[
            'Prepare small-budget search and social tests for Notion/Evernote replacement keywords.',
            'Gate paid spend on working sign-up and import funnels.',
            'Review ad creative once public memo sharing data starts accumulating.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'pr',
          label: 'PR',
          owner: 'Founder',
          priority: 'P1',
          objective:
              'Tell a credible underdog story tied to product progress and user wins.',
          actions: <String>[
            'Publish weekly product-shipping summaries.',
            'Turn public memos into founder updates for note and Substack.',
            'Prepare a Product Hunt / indie launch narrative with clear proof points.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'sales',
          label: 'Sales',
          owner: 'Founder',
          priority: 'P1',
          objective:
              'Win early design partners instead of waiting for broad self-serve demand.',
          actions: <String>[
            'Reach out to small teams using Notion or Evernote with import-based demos.',
            'Offer migration help for the first pilot accounts.',
            'Track objections and feed them back into the product roadmap.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'marketing',
          label: 'Marketing',
          owner: 'Growth',
          priority: 'P0',
          objective:
              'Use public memos, comparison content, and import messaging to create recurring organic traffic.',
          actions: <String>[
            'Ship comparison pages and public memo content for replacement keywords.',
            'Use public memo shares as reusable social content.',
            'Cross-post technical and migration articles to Qiita, Zenn, Medium, dev.to, and Hashnode.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'hr',
          label: 'HR',
          owner: 'Operations',
          priority: 'P2',
          objective:
              'Delay full-time hiring until repeatable acquisition exists, but define fractional roles now.',
          actions: <String>[
            'Define contractor scopes for growth design, content, and backend operations.',
            'Set hiring triggers tied to registrations, active users, and revenue.',
            'Prepare onboarding docs so the first hires can ship quickly.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'finance',
          label: 'Finance',
          owner: 'Finance',
          priority: 'P1',
          objective:
              'Protect runway while funding only the channels and tools that improve acquisition or retention.',
          actions: <String>[
            'Set a weekly growth spending cap.',
            'Track CAC assumptions against actual sign-up and retention data.',
            'Review infrastructure/tool costs before adding new paid vendors.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'procurement',
          label: 'Procurement',
          owner: 'Operations',
          priority: 'P2',
          objective:
              'Buy only the tools required to measure or accelerate the next growth bottleneck.',
          actions: <String>[
            'Prefer Supabase / existing stack before adding new SaaS tools.',
            'Document required vendors for analytics, ads, and design support.',
            'Delay non-essential purchases until activation metrics improve.',
          ],
        ),
        const GrowthDepartmentBrief(
          id: 'business-planning',
          label: 'Business Planning',
          owner: 'Founder',
          priority: 'P0',
          objective:
              'Turn the gap to Notion/Evernote into staged milestones instead of a vague aspiration.',
          actions: <String>[
            'Track the path to 100 users, 1,000 users, and 10,000 users first.',
            'Update the roadmap with cross-functional owners and dates every week.',
            'Tie growth goals to revenue, hiring, and infrastructure scenarios.',
          ],
        ),
      ],
      generatedAt: DateTime.now(),
    );
  }
}

class GrowthPresenceNavigatorObserver extends NavigatorObserver
    with WidgetsBindingObserver {
  static const Duration _immediatePresenceCooldown = Duration(seconds: 45);

  final GrowthMissionService _service;
  final GrowthAcquisitionService _acquisitionService;
  Timer? _heartbeatTimer;
  Timer? _metricsTimer;
  Future<void>? _immediatePresenceSyncInFlight;
  DateTime? _lastImmediatePresenceSyncAt;
  String _currentPagePath = '/';

  /// まだ 1 ルートも track していない状態の区別。初期値 _currentPagePath='/'
  /// と初回ルート '/' (root 直行 = 最多の入口) が一致して同一 path skip に
  /// 入ると、touchpoint/referral 記録が丸ごと消えるため。
  bool _hasTrackedRoute = false;

  GrowthPresenceNavigatorObserver({
    GrowthMissionService service = const GrowthMissionService(),
    GrowthAcquisitionService acquisitionService =
        const GrowthAcquisitionService(),
  })  : _service = service,
        _acquisitionService = acquisitionService {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _cancelTimers();
    } else if (state == AppLifecycleState.resumed) {
      // バックグラウンド復帰時はタイマーを作り直し、即時 sync も試みる
      // (グローバル cooldown 内なら書き込みはスキップされる)。
      _cancelTimers();
      _startTimersIfNeeded(syncNow: true);
    }
  }

  void _cancelTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  /// タイマーが未生成のときだけ生成する。ルート遷移のたびに周期を
  /// リセットしていた旧実装と違い、2分 heartbeat / 5分 metrics の周期を
  /// 遷移頻度と無関係に保つ。
  void _startTimersIfNeeded({required bool syncNow}) {
    if (!_service.isPresenceTrackingAvailable) return;
    if (syncNow) {
      _syncPresenceImmediately();
    }
    _heartbeatTimer ??= Timer.periodic(const Duration(minutes: 2), (_) {
      _runSafely(
        _service.syncPresence(pagePath: _currentPagePath),
        'syncPresence heartbeat',
      );
    });
    _metricsTimer ??= Timer.periodic(const Duration(minutes: 5), (_) {
      _runSafely(_service.refreshAggregateMetrics(), 'refreshAggregateMetrics');
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackRoute(newRoute);
    }
  }

  void _trackRoute(Route<dynamic> route) {
    final resolved = _resolvePagePath(route);
    if (resolved == null ||
        (_hasTrackedRoute && resolved == _currentPagePath)) {
      // ダイアログ等の無名ルートや同一ページへの出入りでは presence 書き込み
      // もタッチポイント記録も行わない (直前ページに滞在している扱い)。
      // アプリ起動直後の初回ルートでまだタイマーが無い場合のみ起動する。
      _startTimersIfNeeded(syncNow: _heartbeatTimer == null);
      return;
    }
    _hasTrackedRoute = true;
    _currentPagePath = resolved;
    _runSafely(
      _acquisitionService.recordTouchpointForPagePath(_currentPagePath),
      'recordTouchpointForPagePath',
    );
    _runSafely(
      _service.capturePendingReferralFromUri(),
      'capturePendingReferralFromUri',
    );
    _runSafely(
      _service.applyPendingReferralIfPossible(),
      'applyPendingReferralIfPossible',
    );
    _syncPresenceImmediately();
    _startTimersIfNeeded(syncNow: false);
  }

  void _syncPresenceImmediately() {
    if (_immediatePresenceSyncInFlight != null) {
      return;
    }

    // cooldown は pagePath 非依存 (グローバル)。cooldown 中の遷移は
    // _currentPagePath の更新だけ行い、書き込みは次の heartbeat に委ねる。
    final lastSyncedAt = _lastImmediatePresenceSyncAt;
    if (lastSyncedAt != null &&
        DateTime.now().difference(lastSyncedAt) < _immediatePresenceCooldown) {
      return;
    }

    final syncFuture = _service.syncPresence(pagePath: _currentPagePath);
    _immediatePresenceSyncInFlight = syncFuture;
    _lastImmediatePresenceSyncAt = DateTime.now();

    _runSafely(
      syncFuture.whenComplete(() {
        if (identical(_immediatePresenceSyncInFlight, syncFuture)) {
          _immediatePresenceSyncInFlight = null;
        }
      }),
      'syncPresence',
    );
  }

  void _runSafely(Future<void> future, String label) {
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        debugPrint('Growth observer $label failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  /// ルート名から page_path を解決する。ダイアログ等の無名ルートは null を
  /// 返し、呼び出し側で「直前ページに滞在中」として扱う (旧実装の
  /// runtimeType 文字列は 'minified:yL<dynamic>' のようなゴミ行を
  /// user_presence に量産していた)。
  String? _resolvePagePath(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      final uri = Uri.tryParse(name);
      if (uri != null && uri.path.trim().isNotEmpty) {
        return uri.path;
      }
      return name;
    }
    return null;
  }
}
