import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/agent_memory_entry.dart';
import 'package:my_web_app/models/agent_message.dart';
import 'package:my_web_app/models/agent_profile.dart';
import 'package:my_web_app/models/agent_relationship.dart';
import 'package:my_web_app/models/agent_task.dart';
import 'package:my_web_app/services/agent_org_service.dart';

void main() {
  test('AgentProfile parses and serializes correctly', () {
    final json = <String, dynamic>{
      'id': 'agent-1',
      'user_id': 'user-1',
      'slug': 'cfo',
      'display_name': 'CFO',
      'role_title': 'Chief Financial Officer',
      'department': '財務',
      'status': 'active',
      'identity_prompt': '財務責任者',
      'permissions_summary': '予算管理',
      'supervisor_agent_id': 'agent-ceo',
      'last_active_at': '2026-03-04T09:30:00.000Z',
      'created_at': '2026-03-04T09:00:00.000Z',
      'updated_at': '2026-03-04T09:10:00.000Z',
      'metadata': {'source': 'seed'},
    };

    final profile = AgentProfile.fromJson(json);

    expect(profile.slug, 'cfo');
    expect(profile.isActive, isTrue);
    expect(profile.isPaused, isFalse);
    expect(profile.toJson()['display_name'], 'CFO');
  });

  test('AgentTask status helpers reflect current state', () {
    final task = AgentTask.fromJson(<String, dynamic>{
      'id': 'task-1',
      'user_id': 'user-1',
      'supervisor_agent_id': 'agent-ceo',
      'assignee_agent_id': 'agent-cmo',
      'title': 'LP改善',
      'description': '体験導線を見直す',
      'status': 'in_progress',
      'priority': 'high',
      'task_type': 'delegated_action',
      'source': 'manual_delegate',
      'created_at': '2026-03-04T09:00:00.000Z',
      'updated_at': '2026-03-04T09:05:00.000Z',
    });

    expect(task.isQueued, isFalse);
    expect(task.isInProgress, isTrue);
    expect(task.isCompleted, isFalse);
    expect(task.toJson()['priority'], 'high');
  });

  test('AgentMemoryEntry parses layer and content', () {
    final memory = AgentMemoryEntry.fromJson(<String, dynamic>{
      'id': 'memory-1',
      'user_id': 'user-1',
      'agent_id': 'agent-cmo',
      'memory_layer': 'handoff',
      'content': 'CEOからの新規委任',
      'source': 'delegate_task',
      'created_at': '2026-03-04T09:15:00.000Z',
    });

    expect(memory.memoryLayer, 'handoff');
    expect(memory.content, contains('委任'));
    expect(memory.toJson()['source'], 'delegate_task');
  });

  test('AgentRelationship parses direction and status', () {
    final relationship = AgentRelationship.fromJson(<String, dynamic>{
      'id': 'rel-1',
      'user_id': 'user-1',
      'from_agent_id': 'agent-ceo',
      'to_agent_id': 'agent-cfo',
      'relationship_type': 'supervises',
      'communication_protocol': 'directive_then_report',
      'status': 'active',
      'created_at': '2026-03-05T01:00:00.000Z',
      'updated_at': '2026-03-05T01:00:00.000Z',
    });

    expect(relationship.relationshipType, 'supervises');
    expect(relationship.isActive, isTrue);
    expect(relationship.toJson()['to_agent_id'], 'agent-cfo');
  });

  test('AgentMessage parses payload and status helpers', () {
    final message = AgentMessage.fromJson(<String, dynamic>{
      'id': 'msg-1',
      'user_id': 'user-1',
      'from_agent_id': 'agent-ceo',
      'to_agent_id': 'agent-cmo',
      'linked_task_id': 'task-1',
      'conversation_id': 'meeting-1',
      'message_kind': 'directive',
      'summary': 'LP conversion recovery plan',
      'payload': <String, dynamic>{'priority': 'high'},
      'status': 'sent',
      'created_at': '2026-03-05T01:10:00.000Z',
      'updated_at': '2026-03-05T01:10:00.000Z',
    });

    expect(message.messageKind, 'directive');
    expect(message.isSent, isTrue);
    expect(message.payload['priority'], 'high');
    expect(message.toJson()['linked_task_id'], 'task-1');
  });

  test('composeStartupPrompt injects identity, memories and tasks', () {
    final agent = AgentProfile.fromJson(<String, dynamic>{
      'id': 'agent-cmo',
      'user_id': 'user-1',
      'slug': 'cmo',
      'display_name': 'CMO',
      'role_title': 'Chief Marketing Officer',
      'department': '広報',
      'status': 'active',
      'identity_prompt': 'あなたは広報責任者です。',
      'permissions_summary': '流入改善 / 登録導線改善',
      'created_at': '2026-03-04T09:00:00.000Z',
      'updated_at': '2026-03-04T09:00:00.000Z',
    });
    final memories = [
      AgentMemoryEntry.fromJson(<String, dynamic>{
        'id': 'memory-1',
        'user_id': 'user-1',
        'agent_id': 'agent-cmo',
        'memory_layer': 'handoff',
        'content': 'LPの無料体験導線を優先する',
        'source': 'delegate_task',
        'created_at': '2026-03-04T09:10:00.000Z',
      }),
    ];
    final tasks = [
      AgentTask.fromJson(<String, dynamic>{
        'id': 'task-1',
        'user_id': 'user-1',
        'supervisor_agent_id': 'agent-ceo',
        'assignee_agent_id': 'agent-cmo',
        'title': '登録率改善プランを作る',
        'description': '無料体験導線を最優先で見る',
        'status': 'queued',
        'priority': 'high',
        'task_type': 'delegated_action',
        'source': 'manual_delegate',
        'created_at': '2026-03-04T09:05:00.000Z',
        'updated_at': '2026-03-04T09:05:00.000Z',
      }),
    ];

    final prompt = AgentOrgService.composeStartupPrompt(
      agent: agent,
      recentMemories: memories,
      openTasks: tasks,
    );

    expect(prompt, contains('あなたは CMO'));
    expect(prompt, contains('流入改善 / 登録導線改善'));
    expect(prompt, contains('Operational Memory'));
    expect(prompt, contains('LPの無料体験導線を優先する'));
    expect(prompt, contains('登録率改善プランを作る'));
  });
}
