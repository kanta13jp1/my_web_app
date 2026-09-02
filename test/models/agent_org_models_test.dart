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
      'department': 'Finance',
      'status': 'active',
      'identity_prompt': 'You are the CFO.',
      'permissions_summary': 'Budget / fixed cost / financial reporting',
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
      'title': 'Improve LP copy',
      'description': 'Shorten first-view CTA message',
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

  test('AgentTask exposes task clarity metadata', () {
    final task = AgentTask.fromJson(<String, dynamic>{
      'id': 'task-clarity',
      'user_id': 'user-1',
      'supervisor_agent_id': 'agent-ceo',
      'assignee_agent_id': 'agent-cmo',
      'title': 'Improve launch plan',
      'status': 'queued',
      'priority': 'high',
      'task_type': 'delegated_action',
      'source': 'manual_delegate',
      'created_at': '2026-03-04T09:00:00.000Z',
      'updated_at': '2026-03-04T09:05:00.000Z',
      'metadata': <String, dynamic>{
        'clarity': <String, dynamic>{
          'score': 4,
          'threshold': 6,
          'status': 'needs_clarification',
        },
      },
    });

    expect(task.clarityScore, 4);
    expect(task.clarityThreshold, 6);
    expect(task.clarityStatus, 'needs_clarification');
    expect(task.needsClarification, isTrue);
  });

  test('AgentMemoryEntry parses layer and content', () {
    final memory = AgentMemoryEntry.fromJson(<String, dynamic>{
      'id': 'memory-1',
      'user_id': 'user-1',
      'agent_id': 'agent-cmo',
      'memory_layer': 'activity_log',
      'content': 'Delegated LP task received',
      'source': 'delegate_task',
      'created_at': '2026-03-04T09:15:00.000Z',
    });

    expect(memory.memoryLayer, 'activity_log');
    expect(memory.content, contains('LP'));
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
      'department': 'Marketing',
      'status': 'active',
      'identity_prompt': 'You are the CMO for growth and conversion.',
      'permissions_summary': 'Traffic / LP / share / conversion',
      'created_at': '2026-03-04T09:00:00.000Z',
      'updated_at': '2026-03-04T09:00:00.000Z',
    });
    final memories = <AgentMemoryEntry>[
      AgentMemoryEntry.fromJson(<String, dynamic>{
        'id': 'memory-1',
        'user_id': 'user-1',
        'agent_id': 'agent-cmo',
        'memory_layer': 'activity_log',
        'content': 'LP hero copy changed for faster first action',
        'source': 'delegate_task',
        'created_at': '2026-03-04T09:10:00.000Z',
      }),
    ];
    final tasks = <AgentTask>[
      AgentTask.fromJson(<String, dynamic>{
        'id': 'task-1',
        'user_id': 'user-1',
        'supervisor_agent_id': 'agent-ceo',
        'assignee_agent_id': 'agent-cmo',
        'title': 'Refine first-view CTA',
        'description': 'Show immediate user outcome on first screen',
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

    expect(prompt, contains('You are CMO'));
    expect(prompt, contains('Traffic / LP / share / conversion'));
    expect(prompt, contains('[Activity Log]'));
    expect(prompt, contains('LP hero copy changed for faster first action'));
    expect(prompt, contains('Refine first-view CTA'));
  });
}
