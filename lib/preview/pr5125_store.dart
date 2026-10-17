import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Synthetic, read-only HTTP adapter. No request is ever forwarded to a network.
class Preview5125Store {
  static const userId = '00000000-0000-4000-8000-000000005125';
  static const date = '2026-10-17T00:00:00Z';

  final Map<String, List<Map<String, dynamic>>> tables = {
    'notes': [
      {
        'id': 1, 'user_id': userId, 'title': '架空データ：秋の読書メモ',
        'content': '# 秋の読書メモ\n\nこれは画面確認専用の架空データです。\n\n- 読みたい本を整理する\n- 気になる言葉を記録する\n\n**本番・外部DBには接続しません。**',
        'tags': ['読書', 'アイデア'], 'is_favorite': true,
        'is_archived': false, 'is_inbox': false,
        'notebook_collection_id': 3, 'space_collection_id': 1,
        'created_at': date, 'updated_at': date, 'reminder_date': null,
      },
      {
        'id': 2, 'user_id': userId, 'title': '架空データ：週末の計画',
        'content': '近所を散歩する。写真と気付きをまとめる。',
        'tags': ['暮らし'], 'is_favorite': false,
        'is_archived': false, 'is_inbox': false,
        'notebook_collection_id': 4, 'space_collection_id': null,
        'created_at': date, 'updated_at': date, 'reminder_date': null,
      },
    ],
    'note_collections': [
      {'id': 1, 'user_id': userId, 'collection_type': 'space', 'name': '架空の共同Space', 'source_system': 'native', 'sort_order': 0, 'is_default': false, 'is_pinned': true,},
      {'id': 2, 'user_id': userId, 'collection_type': 'stack', 'name': 'Evernote移行サンプル', 'source_system': 'evernote', 'sort_order': 1, 'is_default': false, 'is_pinned': false,},
      {'id': 3, 'user_id': userId, 'collection_type': 'notebook', 'name': '読書ノート', 'parent_id': 1, 'source_system': 'native', 'sort_order': 0, 'is_default': true, 'is_pinned': true,},
      {'id': 4, 'user_id': userId, 'collection_type': 'notebook', 'name': '移行済みノート（保護中）', 'parent_id': 2, 'source_system': 'evernote', 'sort_order': 0, 'is_default': false, 'is_pinned': false,},
    ],
    'note_tags': [
      {'id': 1, 'user_id': userId, 'name': '読書', 'source_system': 'evernote'},
      {'id': 2, 'user_id': userId, 'name': 'アイデア', 'parent_id': 1, 'source_system': 'native',},
      {'id': 3, 'user_id': userId, 'name': '暮らし', 'source_system': 'native'},
    ],
    'note_tag_assignments': [
      {'note_id': 1, 'tag_id': 1, 'user_id': userId},
      {'note_id': 1, 'tag_id': 2, 'user_id': userId},
      {'note_id': 2, 'tag_id': 3, 'user_id': userId},
    ],
    'note_tasks': [
      {'id': '00000000-0000-4000-8000-000000000001', 'note_id': 1, 'user_id': userId, 'title': '架空タスク：読書メモを見直す', 'status': 'open', 'in_note': true, 'task_flag': true, 'sort_weight': 0, 'note_level_id': 'sample-task', 'source_system': 'evernote', 'source_key': 'sample-task', 'created_at': date, 'updated_at': date, 'due_at': '2026-11-01T00:00:00Z',},
    ],
    'note_saved_searches': [
      {'id': 'sample-search', 'user_id': userId, 'name': '読書を探す（架空）', 'query': 'tag:読書', 'source_system': 'native',},
    ],
    'note_shortcuts': [
      {'id': 'sample-shortcut', 'user_id': userId, 'position': 0, 'target_type': 'note', 'target_note_id': 1, 'label': '読書メモ（架空）', 'source_system': 'native',},
    ],
    'note_space_members': [
      {'space_id': 1, 'member_user_id': userId, 'member_email': 'reader@example.invalid', 'permission': 'owner',},
      {'space_id': 1, 'member_user_id': '00000000-0000-4000-8000-000000000002', 'member_email': 'friend@example.invalid', 'permission': 'view',},
    ],
    'evernote_migration_batches': [
      {'id': 1, 'user_id': userId, 'source_file_name': '架空の移行サンプル（ファイルなし）', 'source_export_sha256': 'synthetic-not-an-export', 'status': 'imported', 'source_note_count': 2, 'source_resource_count': 0, 'imported_note_count': 1, 'verified_note_count': 0, 'source_deleted_note_count': 0, 'created_at': date, 'updated_at': date,},
    ],
    'evernote_migration_items': [
      {'id': 1, 'batch_id': 1, 'user_id': userId, 'source_item_key': 'synthetic-reading', 'target_note_id': 1, 'status': 'imported', 'history_status': 'pending', 'task_status': 'pending', 'source_history_version_count': 2, 'imported_history_version_count': 0, 'verified_history_version_count': 0, 'source_task_count': 1, 'imported_task_count': 1, 'verified_task_count': 0, 'notes': {'title': '架空データ：秋の読書メモ'}, 'created_at': date, 'updated_at': date,},
      {'id': 2, 'batch_id': 1, 'user_id': userId, 'source_item_key': 'synthetic-weekend', 'target_note_id': null, 'status': 'failed', 'history_status': 'pending', 'task_status': 'pending', 'notes': {'title': '架空データ：再試行待ちの表示サンプル'}, 'created_at': date, 'updated_at': date,},
    ],
  };

  late final http.Client client = MockClient(respond);

  Future<http.Response> respond(http.Request request) async {
    const headers = {'content-type': 'application/json; charset=utf-8'};
    http.Response json(Object? value, {int status = 200}) =>
        http.Response(jsonEncode(value), status, headers: headers);

    if (request.url.host != 'pr5125.invalid') {
      return json({'message': 'Preview forbids external endpoints'}, status: 403,);
    }
    // Mutation is deliberately rejected, never shown as a successful real save.
    if (request.method != 'GET' && request.method != 'HEAD') {
      return json({'message': '架空データ版では保存・共有・移行は実行しません。', 'code': 'PREVIEW_READ_ONLY'}, status: 403,);
    }
    if (!request.url.path.startsWith('/rest/v1/')) {
      return json({'message': 'Preview endpoint disabled'}, status: 403);
    }
    final table = request.url.pathSegments.last;
    var rows = (tables[table] ?? <Map<String, dynamic>>[])
        .map((row) => Map<String, dynamic>.from(row)).toList();
    for (final entry in request.url.queryParameters.entries) {
      if (entry.value.startsWith('eq.')) {
        final value = entry.value.substring(3);
        rows = rows.where((row) => row[entry.key]?.toString() == value).toList();
      }
      if (entry.value == 'is.null') {
        rows = rows.where((row) => row[entry.key] == null).toList();
      }
    }
    final total = rows.length;
    final offset = int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '') ?? total;
    rows = rows.skip(offset).take(limit).toList();
    final single = request.headers['Accept']?.contains('vnd.pgrst.object') ??
        request.headers['accept']?.contains('vnd.pgrst.object') ?? false;
    return http.Response(
      jsonEncode(single ? (rows.isEmpty ? null : rows.first) : rows), 200,
      headers: {...headers, 'content-range': '0-${total == 0 ? 0 : total - 1}/$total',},
    );
  }
}
