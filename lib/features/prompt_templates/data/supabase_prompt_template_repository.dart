import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/ai_hub_chat_service.dart';
import '../domain/prompt_template_models.dart';

/// Supabase `prompt_templates` テーブルおよび `ai-hub` 送信連携リポジトリ (#2665).
class SupabasePromptTemplateRepository implements PromptTemplateRepository {
  SupabasePromptTemplateRepository({
    final SupabaseClient? client,
    final AiHubChatService? chatService,
    final Future<PromptTemplateSendResult> Function(String compiledPrompt)?
        externalSender,
  })  : _client = client,
        _chatService = chatService,
        _externalSender = externalSender;

  final SupabaseClient? _client;
  final AiHubChatService? _chatService;
  final Future<PromptTemplateSendResult> Function(String compiledPrompt)?
      _externalSender;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  @override
  String? get currentUserId => _resolvedClient.auth.currentUser?.id;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) {
      throw StateError('認証済みセッションが必要です。サインイン後に再試行してください。');
    }
    return userId;
  }

  Map<String, Object?> _normalizeRow(final Map<Object?, Object?> raw) {
    final normalized = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key != null) {
        normalized[key.toString()] = entry.value;
      }
    }
    return normalized;
  }

  List<Map<String, Object?>> _extractRowList(final Object response) {
    if (response is! List<Object?>) {
      return const <Map<String, Object?>>[];
    }
    final rows = <Map<String, Object?>>[];
    for (final item in response) {
      if (item is Map<String, Object?>) {
        rows.add(item);
      } else if (item is Map<Object?, Object?>) {
        rows.add(_normalizeRow(item));
      }
    }
    return rows;
  }

  Map<String, Object?> _extractSingleRow(
    final Object response, {
    required final String contextLabel,
  }) {
    if (response is Map<String, Object?>) {
      return response;
    }
    if (response is Map<Object?, Object?>) {
      return _normalizeRow(response);
    }
    if (response is List<Object?> && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, Object?>) {
        return first;
      }
      if (first is Map<Object?, Object?>) {
        return _normalizeRow(first);
      }
    }
    throw StateError('$contextLabelのレスポンス形式が不正です。');
  }

  @override
  Future<List<PromptTemplate>> listTemplates() async {
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client
        .from('prompt_templates')
        .select()
        .order('updated_at', ascending: false)
        .limit(100);
    return _extractRowList(response)
        .map(PromptTemplate.fromSupabaseRow)
        .toList(growable: false);
  }

  @override
  Future<PromptTemplate> saveTemplate(final PromptTemplateDraft draft) async {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError(errors.first);
    }
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    final editingId = draft.editingTemplateId?.trim();
    if (editingId == null || editingId.isEmpty) {
      final Object response = await client
          .from('prompt_templates')
          .insert(draft.toInsertPayload(userId: userId))
          .select()
          .single();
      return PromptTemplate.fromSupabaseRow(
        _extractSingleRow(response, contextLabel: 'テンプレート作成'),
      );
    }

    final Object response = await client
        .from('prompt_templates')
        .update(draft.toUpdatePayload())
        .eq('id', editingId)
        .eq('user_id', userId)
        .select()
        .single();
    return PromptTemplate.fromSupabaseRow(
      _extractSingleRow(response, contextLabel: 'テンプレート更新'),
    );
  }

  @override
  Future<void> deleteTemplate(final String templateId) async {
    final trimmedId = templateId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('削除対象のテンプレートIDが指定されていません。');
    }
    final client = _resolvedClient;
    final userId = _requireUserId(client);
    await client
        .from('prompt_templates')
        .delete()
        .eq('id', trimmedId)
        .eq('user_id', userId);
  }

  @override
  Future<PromptTemplate> recordTemplateUsage(final String templateId) async {
    final trimmedId = templateId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError('利用記録対象のテンプレートIDが指定されていません。');
    }
    final client = _resolvedClient;
    _requireUserId(client);
    final Object response = await client.rpc<Object?>(
          'increment_prompt_template_usage',
          params: <String, Object?>{
            'p_template_id': trimmedId,
          },
        ) ??
        const <String, Object?>{};
    return PromptTemplate.fromSupabaseRow(
      _extractSingleRow(response, contextLabel: '利用回数更新'),
    );
  }

  @override
  Future<PromptTemplateSendResult> sendCompiledPrompt(
    final String compiledPrompt,
  ) async {
    final normalized = compiledPrompt.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('送信するプロンプト本文が空です。');
    }
    if (_externalSender != null) {
      return _externalSender(normalized);
    }

    final client = _resolvedClient;
    _requireUserId(client);
    final service = _chatService ?? AiHubChatService(supabase: client);
    final response = await service.sendAutoChat(
      message: normalized,
      routingUseCase: 'prompt_template_execution',
      providerChoiceReason: '5_element_prompt_template',
    );
    return PromptTemplateSendResult(
      responseText: response.text,
      providerLabel: response.source,
      latencyMs: response.observability?.latencyMs,
    );
  }
}
