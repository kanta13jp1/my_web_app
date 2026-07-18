import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingUserContext {
  const OnboardingUserContext({required this.id, this.email});

  final String id;
  final String? email;
}

class OnboardingCompletion {
  const OnboardingCompletion({
    required this.displayName,
    required this.intent,
    required this.challenge,
    required this.firstAction,
    required this.saveAsDailyTask,
  });

  final String displayName;
  final String intent;
  final String challenge;
  final String firstAction;
  final bool saveAsDailyTask;
}

abstract interface class OnboardingActivationGateway {
  OnboardingUserContext? currentUser();

  Future<void> complete(OnboardingCompletion completion);
}

class SupabaseOnboardingActivationGateway
    implements OnboardingActivationGateway {
  const SupabaseOnboardingActivationGateway({this.clientOverride});

  final SupabaseClient? clientOverride;

  SupabaseClient get _client => clientOverride ?? Supabase.instance.client;

  @override
  OnboardingUserContext? currentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return OnboardingUserContext(id: user.id, email: user.email);
  }

  @override
  Future<void> complete(OnboardingCompletion completion) async {
    final user = currentUser();
    if (user == null) {
      throw StateError('ログイン情報を確認できませんでした。もう一度ログインしてください。');
    }

    await _client.from('user_profiles').upsert({
      'user_id': user.id,
      'display_name': completion.displayName,
      'role': 'CEO',
      'updated_at': DateTime.now().toIso8601String(),
    });

    Map<String, dynamic> metadata = <String, dynamic>{};
    try {
      final existing = await _client
          .from('user_stats')
          .select('metadata')
          .eq('user_id', user.id)
          .maybeSingle();
      final rawMetadata = existing?['metadata'];
      if (rawMetadata is Map) {
        metadata = Map<String, dynamic>.from(rawMetadata);
      }
    } catch (_) {
      // Completion remains available even when an older deployment lacks metadata.
    }

    if (completion.saveAsDailyTask) {
      await _saveFirstActionAsDailyTask(user.id, completion);
    }

    metadata.addAll(<String, dynamic>{
      'onboarding_completed': true,
      'onboarding_intent': completion.intent,
      'onboarding_challenge': completion.challenge,
      'onboarding_first_action': completion.firstAction,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _client.from('user_stats').upsert(
      {
        'user_id': user.id,
        'metadata': metadata,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<void> _saveFirstActionAsDailyTask(
    String userId,
    OnboardingCompletion completion,
  ) async {
    final now = DateTime.now();
    final taskDate = _dateKey(now);
    final existing = await _client
        .from('daily_todos')
        .select('id')
        .eq('user_id', userId)
        .eq('task_date', taskDate)
        .eq('task', completion.firstAction)
        .limit(1)
        .maybeSingle();
    if (existing != null) return;

    await _client.from('daily_todos').insert({
      'user_id': userId,
      'task': completion.firstAction,
      'is_completed': false,
      'is_important': true,
      'category': _categoryForIntent(completion.intent),
      'estimated_minutes': 10,
      'difficulty': 'easy',
      'order_index': 0,
      'task_date': taskDate,
      'due_date': now.toIso8601String(),
      'recurrence': 'none',
    });
  }

  String _categoryForIntent(String intent) {
    return switch (intent) {
      'learning' => 'study',
      'money' => 'other',
      _ => 'work',
    };
  }

  String _dateKey(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';
  }
}
