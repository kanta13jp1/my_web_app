import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dev_review_models.dart';

class SupabaseDevReviewTrackingRepository
    implements DevReviewTrackingRepository {
  SupabaseDevReviewTrackingRepository({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  void _requireAuthenticatedUser() {
    if (_resolvedClient.auth.currentUser == null) {
      throw StateError(
        '開発レビュー管理の操作にはサインインが必要です。',
      );
    }
  }

  @override
  Future<List<DevReviewSession>> listSessions({
    String statusFilter = 'all',
    String assigneeFilter = '',
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'dev_review.session.list',
        'status_filter': statusFilter,
        'assignee_filter': assigneeFilter,
      },
    );
    final data = normalizeJsonObject(response.data, 'dev_review.session.list');
    final Object? rawList = data['sessions'];
    if (rawList is! List<Object?>) {
      throw const FormatException('Missing List "sessions".');
    }
    return rawList
        .map(
          (item) => DevReviewSession.fromJson(
            normalizeJsonObject(item, 'sessions[]'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<DevReviewSession> createSession({
    required String title,
    required String targetType,
    required String githubRepo,
    required int targetNumber,
    required String approver,
    required String assignee,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'dev_review.session.create',
        'title': title.trim(),
        'target_type': targetType,
        'github_repo': githubRepo.trim(),
        'target_number': targetNumber,
        'approver': approver.trim(),
        'assignee': assignee.trim(),
      },
    );
    final data = normalizeJsonObject(
      response.data,
      'dev_review.session.create',
    );
    return DevReviewSession.fromJson(
      normalizeJsonObject(data['session'], 'session'),
    );
  }

  @override
  Future<DevReviewSession> updateItemStatus({
    required String sessionId,
    required String itemId,
    required DevReviewItemStatus status,
    required String assignee,
    required String note,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'dev_review.item.update',
        'session_id': sessionId,
        'item_id': itemId,
        'status': status.wireValue,
        'assignee': assignee.trim(),
        'note': note.trim(),
      },
    );
    final data = normalizeJsonObject(response.data, 'dev_review.item.update');
    return DevReviewSession.fromJson(
      normalizeJsonObject(data['session'], 'session'),
    );
  }

  @override
  Future<DevReviewSession> addFinding({
    required String sessionId,
    required String title,
    required String assignee,
    required String note,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'dev_review.item.update',
        'session_id': sessionId,
        'kind': 'finding',
        'title': title.trim(),
        'status': DevReviewItemStatus.changesRequested.wireValue,
        'assignee': assignee.trim(),
        'note': note.trim(),
      },
    );
    final data = normalizeJsonObject(response.data, 'dev_review.item.update');
    return DevReviewSession.fromJson(
      normalizeJsonObject(data['session'], 'session'),
    );
  }

  @override
  Future<DevReviewSession> syncGithubStatus({
    required String sessionId,
    required String state,
    required String reviewDecision,
    bool fetchLive = false,
  }) async {
    _requireAuthenticatedUser();
    final response = await _resolvedClient.functions.invoke(
      'app-hub',
      body: <String, Object?>{
        'action': 'dev_review.github.sync',
        'session_id': sessionId,
        'state': state,
        'review_decision': reviewDecision,
        'fetch_live': fetchLive,
      },
    );
    final data = normalizeJsonObject(response.data, 'dev_review.github.sync');
    return DevReviewSession.fromJson(
      normalizeJsonObject(data['session'], 'session'),
    );
  }

  @override
  Future<PhaseAdvanceOutcome> advancePhase({
    required String sessionId,
    required DevReviewPhase targetPhase,
    required String note,
  }) async {
    _requireAuthenticatedUser();
    try {
      final response = await _resolvedClient.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'dev_review.phase.advance',
          'session_id': sessionId,
          'target_phase': targetPhase.wireValue,
          'note': note.trim(),
        },
      );
      final data = normalizeJsonObject(
        response.data,
        'dev_review.phase.advance',
      );
      if (data['blocked'] == true) {
        final Object? rawReasons = data['blocking_reasons'];
        final reasons = rawReasons is List<Object?>
            ? rawReasons.whereType<String>().toList(growable: false)
            : const <String>['承認条件が満たされていません。'];
        return PhaseAdvanceOutcome(blocked: true, blockingReasons: reasons);
      }
      return PhaseAdvanceOutcome(
        blocked: false,
        blockingReasons: const <String>[],
        updatedSession: DevReviewSession.fromJson(
          normalizeJsonObject(data['session'], 'session'),
        ),
      );
    } on FunctionException catch (error) {
      if (error.status == 409 && error.details is Map<Object?, Object?>) {
        final details = normalizeJsonObject(
          error.details,
          'dev_review.phase.advance:409',
        );
        final Object? rawReasons = details['blocking_reasons'];
        final reasons = rawReasons is List<Object?>
            ? rawReasons.whereType<String>().toList(growable: false)
            : const <String>['未承認項目があるためフェーズ移行できません。'];
        return PhaseAdvanceOutcome(blocked: true, blockingReasons: reasons);
      }
      rethrow;
    }
  }
}
