import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_knowledge_graph.dart';
import 'offline_secure_mode_settings_service.dart';

typedef UserKnowledgeGraphInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

abstract interface class UserKnowledgeDocumentPicker {
  Future<UserKnowledgeGraphUpload?> pickDocument();
}

abstract interface class UserKnowledgeGraphRepository {
  Future<UserKnowledgeGraphStatus> loadStatus();

  Future<UserKnowledgeGraphDocument> upload(UserKnowledgeGraphUpload document);

  Future<UserKnowledgeGraphAnswer> ask(String question);

  Future<void> deleteDocument(String documentId);
}

enum UserKnowledgeGraphFailure {
  general,
  authenticationRequired,
  notConfigured,
}

class UserKnowledgeGraphException implements Exception {
  final String message;
  final UserKnowledgeGraphFailure failure;

  const UserKnowledgeGraphException(
    this.message, {
    this.failure = UserKnowledgeGraphFailure.general,
  });

  @override
  String toString() => message;
}

class FilePickerUserKnowledgeDocumentPicker
    implements UserKnowledgeDocumentPicker {
  const FilePickerUserKnowledgeDocumentPicker();

  static const List<String> allowedExtensions = <String>[
    'txt',
    'csv',
    'html',
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'xls',
    'xlsx',
  ];

  @override
  Future<UserKnowledgeGraphUpload?> pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes == null) {
      throw UserKnowledgeGraphException(
        '${file.name}を読み込めませんでした。別のファイルを選んでください。',
      );
    }
    final extension = (file.extension ?? '').toLowerCase();
    final mimeType = _mimeTypes[extension];
    if (mimeType == null) {
      throw const UserKnowledgeGraphException('対応していないファイル形式です。');
    }
    return UserKnowledgeGraphUpload(
      fileName: file.name,
      mimeType: mimeType,
      bytes: Uint8List.fromList(bytes),
    );
  }

  static const Map<String, String> _mimeTypes = <String, String>{
    'txt': 'text/plain',
    'csv': 'text/csv',
    'html': 'text/html',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
}

class SupabaseUserKnowledgeGraphService
    implements UserKnowledgeGraphRepository {
  static const int maxFileBytes = 4 * 1024 * 1024;
  static const int maxQuestionChars = 2000;

  final SupabaseClient? _supabase;
  final UserKnowledgeGraphInvoker? _invoker;
  final OfflineSecureModeSettingsService _offlineSettingsService;

  const SupabaseUserKnowledgeGraphService({
    SupabaseClient? supabase,
    UserKnowledgeGraphInvoker? invoker,
    OfflineSecureModeSettingsService offlineSettingsService =
        const OfflineSecureModeSettingsService(),
  })  : _supabase = supabase,
        _invoker = invoker,
        _offlineSettingsService = offlineSettingsService;

  @override
  Future<UserKnowledgeGraphStatus> loadStatus() async {
    final data = await _invoke(<String, dynamic>{
      'action': 'knowledge_graph.status',
    });
    final rawDocuments = data['documents'];
    final documents = rawDocuments is List
        ? rawDocuments
            .whereType<Map>()
            .map(
              (item) => UserKnowledgeGraphDocument.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((document) => document.id.isNotEmpty)
            .toList(growable: false)
        : const <UserKnowledgeGraphDocument>[];
    return UserKnowledgeGraphStatus(
      configured: data['configured'] == true,
      graphReady: data['graph_ready'] == true,
      documents: documents,
    );
  }

  @override
  Future<UserKnowledgeGraphDocument> upload(
    UserKnowledgeGraphUpload document,
  ) async {
    _validateUpload(document);
    final offline = await _offlineSettingsService.loadSettingsOrDefaults();
    final data = await _invoke(<String, dynamic>{
      'action': 'knowledge_graph.upload',
      'file_name': _safeFileName(document.fileName),
      'mime_type': document.mimeType,
      'file_base64': base64Encode(document.bytes),
      ...offline.toAiHubPolicyPayload(),
    });
    final raw = data['document'];
    if (raw is! Map) {
      throw const UserKnowledgeGraphException('文書の登録結果を確認できませんでした。');
    }
    return UserKnowledgeGraphDocument.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<UserKnowledgeGraphAnswer> ask(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty) {
      throw const UserKnowledgeGraphException('質問を入力してください。');
    }
    if (normalized.length > maxQuestionChars) {
      throw const UserKnowledgeGraphException('質問は2000文字以内にしてください。');
    }
    final offline = await _offlineSettingsService.loadSettingsOrDefaults();
    final data = await _invoke(<String, dynamic>{
      'action': 'knowledge_graph.query',
      'question': normalized,
      ...offline.toAiHubPolicyPayload(),
    });
    final rawCitations = data['citations'];
    final citations = rawCitations is List
        ? rawCitations
            .whereType<Map>()
            .map(
              (item) => UserKnowledgeGraphCitation.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((citation) => citation.index > 0)
            .toList(growable: false)
        : const <UserKnowledgeGraphCitation>[];
    return UserKnowledgeGraphAnswer(
      answer: data['answer']?.toString() ?? '',
      citations: citations,
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    if (documentId.trim().isEmpty) return;
    await _invoke(<String, dynamic>{
      'action': 'knowledge_graph.delete_document',
      'document_id': documentId,
    });
  }

  void _validateUpload(UserKnowledgeGraphUpload document) {
    if (document.bytes.isEmpty) {
      throw const UserKnowledgeGraphException('空のファイルは登録できません。');
    }
    if (document.bytes.length > maxFileBytes) {
      throw const UserKnowledgeGraphException('ファイルは4MB以下にしてください。');
    }
    if (!FilePickerUserKnowledgeDocumentPicker._mimeTypes.values.contains(
      document.mimeType,
    )) {
      throw const UserKnowledgeGraphException('対応していないファイル形式です。');
    }
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return _ensureSuccess(await invoker(body));
    final client = _supabase ?? Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw const UserKnowledgeGraphException(
        '個人ナレッジグラフを使うにはログインが必要です。',
        failure: UserKnowledgeGraphFailure.authenticationRequired,
      );
    }
    try {
      final response = await client.functions.invoke('ai-hub', body: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return _ensureSuccess(data);
      if (data is Map) {
        return _ensureSuccess(Map<String, dynamic>.from(data));
      }
      throw const UserKnowledgeGraphException('サーバーから不正な応答を受信しました。');
    } on FunctionException catch (error) {
      throw _fromFunctionException(error);
    }
  }

  Map<String, dynamic> _ensureSuccess(Map<String, dynamic> data) {
    if (data['success'] == true) return data;
    final code = data['code']?.toString() ?? '';
    final message = data['error']?.toString() ?? data['message']?.toString();
    throw _mappedException(code, message);
  }

  UserKnowledgeGraphException _fromFunctionException(FunctionException error) {
    final details = error.details;
    final code = details is Map ? details['code']?.toString() ?? '' : '';
    final message =
        details is Map ? details['error']?.toString() : details?.toString();
    return _mappedException(code, message);
  }

  UserKnowledgeGraphException _mappedException(
    String code,
    String? message,
  ) {
    if (code == 'writer_api_key_required') {
      return const UserKnowledgeGraphException(
        '管理者による WRITER_API_KEY の設定が必要です。',
        failure: UserKnowledgeGraphFailure.notConfigured,
      );
    }
    if (code == 'usage_limit_reached') {
      return const UserKnowledgeGraphException('今月のAI質問上限に達しました。');
    }
    if (code == 'budget_limit_reached' || code == 'writer_rate_limited') {
      return const UserKnowledgeGraphException('利用が集中しています。時間をおいて再試行してください。');
    }
    if (code == 'no_cited_source') {
      return const UserKnowledgeGraphException(
        '引用できる根拠が見つかりませんでした。文書の処理完了後に再試行してください。',
      );
    }
    return UserKnowledgeGraphException(
      message?.trim().isNotEmpty == true ? message! : 'ナレッジグラフ処理に失敗しました。',
    );
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/\r\n\t]+'), '_')
        .replaceAll(RegExp(r'[<>:"|?*]+'), '_');
    if (cleaned.isEmpty) return 'document.txt';
    return cleaned.length <= 160 ? cleaned : cleaned.substring(0, 160);
  }
}
