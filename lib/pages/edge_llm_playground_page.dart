import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_provider_registry.dart';
import '../services/edge_llm_playground_service.dart';
import '../services/local_rag_runtime_service.dart';
import '../widgets/ai_response_observability_panel.dart';
import '../widgets/pleias_citation_text.dart';
import 'offline_secure_mode_settings_page.dart';

class EdgeLlmPlaygroundPage extends StatefulWidget {
  final EdgeLlmPlaygroundService? service;

  const EdgeLlmPlaygroundPage({
    super.key,
    this.service,
  });

  @override
  State<EdgeLlmPlaygroundPage> createState() => _EdgeLlmPlaygroundPageState();
}

class _EdgeLlmPlaygroundPageState extends State<EdgeLlmPlaygroundPage> {
  static const List<String> _providerOptions = <String>[
    'auto',
    'google',
    'openai',
    'anthropic',
    'groq',
    'deepinfra',
    'openrouter',
  ];

  static const List<String> _tierOptions = <String>[
    'free',
    'budget',
    'performance',
    'premium',
  ];

  static const List<_PromptPreset> _presets = <_PromptPreset>[
    _PromptPreset(
      label: '今日の1手',
      prompt: '時間・お金・健康・集中力の浪費を減らすために、今日の低ハードル1手を3つ提案してください。',
      responseFormat: 'text',
    ),
    _PromptPreset(
      label: 'JSON KPI',
      prompt: 'KGI, CSF, KPI を JSON で返してください。フィールドは kgi, csf, kpis のみを使ってください。',
      responseFormat: 'json',
      contextDraft:
          '{\n  "theme": "ライフマネジメント",\n  "focus": ["時間", "お金", "健康"]\n}',
    ),
    _PromptPreset(
      label: 'ノート要約',
      prompt: '以下のコンテキストを 3 点で要約し、次のアクションを 1 つ返してください。',
      responseFormat: 'text',
      contextDraft:
          '{\n  "note_title": "週次レビュー",\n  "items": ["睡眠不足", "出費増", "運動不足"]\n}',
    ),
  ];

  final TextEditingController _systemController = TextEditingController(
    text: 'あなたは社内アプリの Edge Function 経由で動く実務AIです。短く、具体的に返答してください。',
  );
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final String _sessionId = const Uuid().v4();

  late final EdgeLlmPlaygroundService _service;

  String _provider = 'auto';
  String _tier = 'budget';
  String _responseFormat = 'text';
  bool _isSending = false;
  EdgeLlmPlaygroundResponse? _response;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const EdgeLlmPlaygroundService();
  }

  @override
  void dispose() {
    _systemController.dispose();
    _promptController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final response = await _service.invoke(
        userPrompt: prompt,
        systemPrompt: _systemController.text,
        provider: _provider,
        tier: _provider == 'auto' ? _tier : null,
        responseFormat: _responseFormat,
        contextDraft: _contextController.text,
        sessionId: _sessionId,
      );
      if (!mounted) return;
      setState(() {
        _response = response;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _applyPreset(_PromptPreset preset) {
    setState(() {
      _promptController.text = preset.prompt;
      _responseFormat = preset.responseFormat;
      if (preset.contextDraft != null) {
        _contextController.text = preset.contextDraft!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final outlineColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);
    const accent = Color(0xFF0F766E);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Edge LLM Playground'),
        actions: [
          IconButton(
            tooltip: 'オフライン設定',
            icon: const Icon(Icons.security_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OfflineSecureModeSettingsPage(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(cardColor, outlineColor, accent, isDark),
              const SizedBox(height: 16),
              _buildConfigCard(cardColor, outlineColor, isDark),
              const SizedBox(height: 16),
              _buildPromptCard(cardColor, outlineColor, isDark),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(cardColor, outlineColor, isDark),
              ],
              if (_response != null) ...[
                const SizedBox(height: 16),
                _buildResponseCard(cardColor, outlineColor, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(
    Color cardColor,
    Color outlineColor,
    Color accent,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.memory_outlined,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edge Function 経由で LLM を呼び出す共通入口',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'プロンプト、システム指示、JSON コンテキスト、応答形式をまとめて ai-hub に渡して試せます。',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map(
                    (preset) => ActionChip(
                      label: Text(preset.label),
                      onPressed: () => _applyPreset(preset),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(Color cardColor, Color outlineColor, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '呼び出し設定',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('provider-$_provider'),
                    initialValue: _provider,
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    items: _providerOptions
                        .map(
                          (providerId) => DropdownMenuItem<String>(
                            value: providerId,
                            child: Text(_providerLabel(providerId)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _provider = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('format-$_responseFormat'),
                    initialValue: _responseFormat,
                    decoration: const InputDecoration(
                      labelText: 'Response format',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('Text')),
                      DropdownMenuItem(value: 'json', child: Text('JSON')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _responseFormat = value;
                      });
                    },
                  ),
                ),
                if (_provider == 'auto')
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('tier-$_tier'),
                      initialValue: _tier,
                      decoration: const InputDecoration(
                        labelText: 'Start tier',
                        border: OutlineInputBorder(),
                      ),
                      items: _tierOptions
                          .map(
                            (tier) => DropdownMenuItem<String>(
                              value: tier,
                              child: Text(tier),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _tier = value;
                        });
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _systemController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'System prompt',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard(Color cardColor, Color outlineColor, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prompt',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'User prompt',
                hintText: '何をしてほしいかを入力します。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Context JSON / plain text',
                hintText: '{"goal":"KPI review"}',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_outlined),
                label: Text(_isSending ? '呼び出し中...' : 'Edge Function で実行'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(Color cardColor, Color outlineColor, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFDA4AF),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF881337),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseCard(Color cardColor, Color outlineColor, bool isDark) {
    final response = _response!;
    final parsedJson = response.parsedJson;
    final prettyJson = parsedJson == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(parsedJson);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _responseChip(response.provider),
                if (response.tier != null) _responseChip(response.tier!),
                if (response.model != null) _responseChip(response.model!),
                _responseChip(response.responseFormat.toUpperCase()),
              ],
            ),
            const SizedBox(height: 12),
            if (response.observability != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AiResponseObservabilityPanel(
                  observability: response.observability!,
                  isDark: isDark,
                  fallbackLabel: response.provider,
                ),
              ),
            const Text(
              'Raw response',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _codeBlock(
              text: response.text,
              isDark: isDark,
              citations: response.citations,
            ),
            if (prettyJson != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Parsed JSON',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              _codeBlock(text: prettyJson, isDark: isDark),
            ],
            if (response.parseError != null) ...[
              const SizedBox(height: 12),
              Text(
                'JSON parse: ${response.parseError}',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFB91C1C),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _codeBlock({
    required String text,
    required bool isDark,
    List<LocalRagCitation> citations = const <LocalRagCitation>[],
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: PleiasCitationText(
        text: text,
        citations: citations,
        isDark: isDark,
      ),
    );
  }

  Widget _responseChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  String _providerLabel(String providerId) {
    if (providerId == 'auto') return '自動ルーティング';
    final match = kAiProviderRegistry.cast<AiProviderEntry?>().firstWhere(
          (entry) => entry?.id == providerId,
          orElse: () => null,
        );
    return match?.displayName ?? providerId;
  }
}

class _PromptPreset {
  final String label;
  final String prompt;
  final String responseFormat;
  final String? contextDraft;

  const _PromptPreset({
    required this.label,
    required this.prompt,
    required this.responseFormat,
    this.contextDraft,
  });
}
