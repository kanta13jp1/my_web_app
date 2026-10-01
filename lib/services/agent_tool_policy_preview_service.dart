import 'package:supabase_flutter/supabase_flutter.dart';

class AgentToolPolicyPreviewService {
  Future<Map<String, dynamic>> preview(String role, String scopes) async {
    final response = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'agent.tool_policy.preview',
        'actor_role': role,
        'requested_scopes': scopes.split(','),
      },
    );
    final data = response.data;
    if (data is! Map || data['preview'] is! Map) {
      throw const FormatException('判定結果を取得できませんでした');
    }
    return Map<String, dynamic>.from(data['preview'] as Map);
  }
}
