import 'package:my_web_app/models/micro_survey.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MicroSurveyRepository {
  Future<bool> claimPrompt(MicroSurveyContext surveyContext);

  Future<void> submit(
    MicroSurveyContext surveyContext,
    MicroSurveyAnswer answer,
  );

  Future<void> setOptOut(bool optedOut);
}

class SupabaseMicroSurveyRepository implements MicroSurveyRepository {
  SupabaseMicroSurveyRepository(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<bool> claimPrompt(MicroSurveyContext surveyContext) async {
    if (_userId == null) return false;

    final result = await _client.rpc(
      'claim_micro_survey_prompt',
      params: surveyContext.claimParameters,
    );
    return result == true;
  }

  @override
  Future<void> submit(
    MicroSurveyContext surveyContext,
    MicroSurveyAnswer answer,
  ) async {
    final userId = _userId;
    if (userId == null) {
      throw StateError('A signed-in user is required to submit a survey.');
    }

    final normalizedComment = answer.comment?.trim();
    await _client.from('micro_survey_responses').insert(<String, Object?>{
      'user_id': userId,
      'survey_key': surveyContext.surveyKey,
      'trigger': surveyContext.trigger.databaseValue,
      'route': surveyContext.route,
      'resource_type': surveyContext.resourceType,
      'completion_status': surveyContext.completionStatus,
      'rating': answer.rating,
      'comment': normalizedComment == null || normalizedComment.isEmpty
          ? null
          : normalizedComment,
    });
  }

  @override
  Future<void> setOptOut(bool optedOut) async {
    if (_userId == null) return;
    await _client.rpc(
      'set_micro_survey_opt_out',
      params: <String, Object>{'p_opted_out': optedOut},
    );
  }
}
