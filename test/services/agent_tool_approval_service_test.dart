import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/agent_tool_approval_service.dart';

void main() {
  test('AgentToolApprovalLog parses pending high-risk approval rows', () {
    final log = AgentToolApprovalLog.fromMap({
      'id': 'log-1',
      'tool_name': 'x.post',
      'actor_role': 'cmo',
      'allowed': false,
      'requires_approval': true,
      'approval_decision': 'pending',
      'requested_scopes': ['create', 'external_share'],
      'allowed_scopes': ['read', 'suggest', 'create', 'external_share'],
      'high_risk_scopes': ['external_share'],
      'blocked_reason': 'approval_required',
      'side_effects': 'Post to X timeline.',
      'payload': {'text': 'hello'},
      'created_at': '2026-05-02T12:00:00Z',
    });

    expect(log.id, 'log-1');
    expect(log.toolName, 'x.post');
    expect(log.actorRole, 'cmo');
    expect(log.isPendingApproval, isTrue);
    expect(log.requestedScopes, ['create', 'external_share']);
    expect(log.highRiskScopes, ['external_share']);
    expect(log.payload['text'], 'hello');
  });

  test('approval payload keeps tool name, scopes, and CEO metadata', () {
    final log = AgentToolApprovalLog.fromMap({
      'id': 'log-2',
      'tool_name': 'payments.purchase',
      'allowed': false,
      'requires_approval': true,
      'requested_scopes': 'purchase',
      'high_risk_scopes': ['purchase'],
    });

    final payload = jsonDecode(
      log.buildApprovalPayloadJson(
        approvedBy: 'ceo@example.com',
        approvedAt: DateTime.utc(2026, 5, 2, 12),
      ),
    ) as Map<String, dynamic>;

    expect(payload['tool_name'], 'payments.purchase');
    expect(payload['requested_scopes'], ['purchase']);
    expect(payload['approval'], {
      'decision': 'approved',
      'approved_by': 'ceo@example.com',
      'approved_at': '2026-05-02T12:00:00.000Z',
    });
  });
}
