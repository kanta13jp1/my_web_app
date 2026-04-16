import 'package:supabase_flutter/supabase_flutter.dart';

class LearnerProfile {
  final List<String> weakProviders;
  final List<String> strongProviders;
  final String preferredStyle;
  final Map<String, dynamic> profileJson;

  const LearnerProfile({
    required this.weakProviders,
    required this.strongProviders,
    required this.preferredStyle,
    required this.profileJson,
  });

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
        weakProviders: List<String>.from(json['weak_providers'] as List? ?? []),
        strongProviders:
            List<String>.from(json['strong_providers'] as List? ?? []),
        preferredStyle: json['preferred_style'] as String? ?? 'text',
        profileJson: json,
      );
}

class AiLearnerProfileService {
  final _supabase = Supabase.instance.client;

  Future<LearnerProfile?> updateProfile({
    required String sessionSummary,
    required List<Map<String, dynamic>> scores,
  }) async {
    try {
      final response = await _supabase.functions.invoke('ai-hub', body: {
        'action': 'learner.update_profile',
        'session_summary': sessionSummary,
        'scores': scores,
      },);
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) return null;
      final pj = data['profile_json'] as Map<String, dynamic>? ?? {};
      return LearnerProfile.fromJson(pj);
    } catch (_) {
      return null;
    }
  }
}
