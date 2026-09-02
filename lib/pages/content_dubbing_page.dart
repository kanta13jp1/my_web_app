import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/voice_dubbing_service.dart';
import '../theme/design_tokens.dart';

class ContentDubbingPage extends StatefulWidget {
  final VoiceDubbingApi? api;

  const ContentDubbingPage({super.key, this.api});

  @override
  State<ContentDubbingPage> createState() => _ContentDubbingPageState();
}

class _ContentDubbingPageState extends State<ContentDubbingPage> {
  late final VoiceDubbingApi _api;
  final _textController = TextEditingController();
  final _fileNameController = TextEditingController(
    text: 'multilingual-dubbing',
  );
  final _voiceSearchController = TextEditingController();

  VoiceDubbingModel _model = voiceDubbingModels.first;
  VoiceDubbingLanguage _language = voiceDubbingLanguages.firstWhere(
    (language) => language.code == 'ja',
  );
  List<VoiceOption> _voices = const [];
  VoiceOption? _voice;
  VoiceUsage? _usage;
  VoiceDubbingResult? _result;
  String? _nextPageToken;
  int _voiceTotalCount = 0;
  bool _hasMoreVoices = false;
  bool _loadingVoices = true;
  bool _generating = false;
  bool _downloading = false;
  double _stability = 0.5;
  double _similarityBoost = 0.75;
  double _style = 0;
  double _speed = 1;
  bool _speakerBoost = true;
  String _status = '';
  String? _pendingIdempotencyKey;
  String? _pendingRequestFingerprint;

  List<VoiceDubbingLanguage> get _availableLanguages =>
      voiceDubbingLanguages.where(_model.supports).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? SupabaseVoiceDubbingService();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadVoices(reset: true), _loadUsage()]);
  }

  Future<void> _loadUsage() async {
    try {
      final usage = await _api.loadUsage();
      if (mounted) setState(() => _usage = usage);
    } catch (error) {
      if (mounted) setState(() => _status = _message(error));
    }
  }

  Future<void> _loadVoices({required bool reset}) async {
    if (_loadingVoices && !reset) return;
    setState(() {
      _loadingVoices = true;
      _status = '';
    });
    try {
      final page = await _api.loadVoices(
        search: _voiceSearchController.text,
        pageToken: reset ? null : _nextPageToken,
      );
      if (!mounted) return;
      setState(() {
        _voices = reset ? page.voices : [..._voices, ...page.voices];
        _voice = _voices.any((candidate) => candidate.id == _voice?.id)
            ? _voice
            : (_voices.isEmpty ? null : _voices.first);
        _nextPageToken = page.nextPageToken;
        _hasMoreVoices = page.hasMore && page.nextPageToken != null;
        _voiceTotalCount = page.totalCount;
      });
    } catch (error) {
      if (mounted) setState(() => _status = _message(error));
    } finally {
      if (mounted) setState(() => _loadingVoices = false);
    }
  }

  Future<void> _pickArticle() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'csv', 'json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _status = 'ファイルを読み込めませんでした。');
      return;
    }
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    setState(() {
      _textController.text = text;
      _fileNameController.text = file.name.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      );
      _result = null;
      _status = '';
    });
  }

  Future<void> _generate() async {
    final text = _textController.text.trim();
    final voice = _voice;
    if (text.isEmpty) {
      setState(() => _status = '音声化するテキストを入力してください。');
      return;
    }
    if (text.length > _model.maxCharacters) {
      setState(
        () => _status =
            '${_model.label} は1回 ${_formatNumber(_model.maxCharacters)}文字までです。',
      );
      return;
    }
    if (voice == null) {
      setState(() => _status = '音声を選択してください。');
      return;
    }
    setState(() {
      _generating = true;
      _result = null;
      _status = '音声を生成しています...';
    });
    final requestFingerprint = <Object>[
      text,
      _fileNameController.text,
      _model.id,
      _language.code,
      voice.id,
      _stability,
      _similarityBoost,
      _style,
      _speed,
      _speakerBoost,
    ].join('\u001f');
    final request = VoiceDubbingRequest(
      idempotencyKey: _pendingRequestFingerprint == requestFingerprint
          ? _pendingIdempotencyKey
          : null,
      text: text,
      fileName: _fileNameController.text,
      model: _model,
      language: _language,
      voice: voice,
      stability: _stability,
      similarityBoost: _similarityBoost,
      style: _style,
      speed: _speed,
      speakerBoost: _speakerBoost,
    );
    _pendingIdempotencyKey = request.idempotencyKey;
    _pendingRequestFingerprint = requestFingerprint;
    try {
      final result = await _api.generate(request);
      if (!mounted) return;
      setState(() {
        _result = result;
        _usage = result.usage;
        _status = '生成が完了しました。';
        _pendingIdempotencyKey = null;
        _pendingRequestFingerprint = null;
      });
      await _api.preview(result);
    } catch (error) {
      final message = _message(error);
      if (mounted) {
        setState(() {
          _status = message;
          if (message.contains('retry_with_new_request_id') ||
              message.contains('idempotency_conflict') ||
              message.contains('voice_generation_failed') ||
              message.contains('voice_replay_unavailable')) {
            _pendingIdempotencyKey = null;
            _pendingRequestFingerprint = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _download() async {
    final result = _result;
    if (result == null) return;
    setState(() => _downloading = true);
    try {
      await _api.download(result);
    } catch (error) {
      if (mounted) setState(() => _status = _message(error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _fileNameController.dispose();
    _voiceSearchController.dispose();
    unawaited(_api.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        foregroundColor: Colors.white,
        title: const Text('多言語ダビング'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DesignTokens.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _usagePanel(),
                const SizedBox(height: DesignTokens.space16),
                _section(
                  title: '原稿',
                  icon: Icons.article_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('dubbing-text'),
                        controller: _textController,
                        minLines: 8,
                        maxLines: 16,
                        maxLength: _model.maxCharacters,
                        style: const TextStyle(color: DesignTokens.textPrimary),
                        decoration: _inputDecoration('テキストを入力'),
                        onChanged: (_) => setState(() => _result = null),
                      ),
                      const SizedBox(height: DesignTokens.space8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _generating ? null : _pickArticle,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('記事を読み込む'),
                          ),
                          const SizedBox(width: DesignTokens.space12),
                          Expanded(
                            child: TextField(
                              controller: _fileNameController,
                              style: const TextStyle(
                                color: DesignTokens.textPrimary,
                              ),
                              decoration: _inputDecoration('ファイル名'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                _section(
                  title: '言語と音声',
                  icon: Icons.record_voice_over_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _responsiveFields([
                        _menu<VoiceDubbingModel>(
                          label: 'モデル',
                          value: _model,
                          items: voiceDubbingModels,
                          itemLabel: (model) => model.label,
                          onChanged: (model) {
                            setState(() {
                              _model = model;
                              if (!model.supports(_language)) {
                                _language = _availableLanguages.first;
                              }
                              _result = null;
                            });
                          },
                        ),
                        _menu<VoiceDubbingLanguage>(
                          key: const Key('dubbing-language'),
                          label: '読み上げ言語 (${_availableLanguages.length})',
                          value: _language,
                          items: _availableLanguages,
                          itemLabel: (language) => language.label,
                          onChanged: (language) => setState(() {
                            _language = language;
                            _result = null;
                          }),
                        ),
                      ]),
                      const SizedBox(height: DesignTokens.space8),
                      Text(
                        _model.description,
                        style: const TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: DesignTokens.space16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _voiceSearchController,
                              style: const TextStyle(
                                color: DesignTokens.textPrimary,
                              ),
                              decoration: _inputDecoration('音声を検索'),
                              onSubmitted: (_) => _loadVoices(reset: true),
                            ),
                          ),
                          const SizedBox(width: DesignTokens.space8),
                          IconButton.filledTonal(
                            tooltip: '音声を検索',
                            onPressed: _loadingVoices
                                ? null
                                : () => _loadVoices(reset: true),
                            icon: const Icon(Icons.search),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space12),
                      _voiceMenu(),
                      if (_hasMoreVoices) ...[
                        const SizedBox(height: DesignTokens.space8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _loadingVoices
                                ? null
                                : () => _loadVoices(reset: false),
                            icon: _loadingVoices
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.expand_more),
                            label: Text(
                              'さらに読み込む (${_voices.length}/$_voiceTotalCount)',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                _section(
                  title: '音声表現',
                  icon: Icons.tune,
                  child: Column(
                    children: [
                      _slider(
                        '安定性',
                        _stability,
                        (value) => setState(() => _stability = value),
                      ),
                      _slider(
                        'スタイル強調',
                        _style,
                        (value) => setState(() => _style = value),
                      ),
                      _slider(
                        '類似度',
                        _similarityBoost,
                        (value) => setState(() => _similarityBoost = value),
                        enabled: _model.id != 'eleven_v3',
                      ),
                      _slider(
                        '速度',
                        _speed,
                        (value) => setState(() => _speed = value),
                        min: 0.7,
                        max: 1.2,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '話者ブースト',
                          style: TextStyle(color: DesignTokens.textPrimary),
                        ),
                        value: _speakerBoost,
                        onChanged: _model.id == 'eleven_v3'
                            ? null
                            : (value) => setState(() => _speakerBoost = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space16),
                FilledButton.icon(
                  key: const Key('generate-dubbing'),
                  onPressed: _generating ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignTokens.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _generating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.graphic_eq),
                  label: Text(_generating ? '生成中' : '音声を生成'),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.space12),
                  Text(
                    _status,
                    key: const Key('dubbing-status'),
                    style: TextStyle(
                      color: _result == null && !_generating
                          ? DesignTokens.amber
                          : DesignTokens.textSecondary,
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: DesignTokens.space16),
                  _resultPanel(_result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _usagePanel() {
    final usage = _usage;
    final progress = usage == null || usage.limit <= 0
        ? 0.0
        : (usage.used / usage.limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.data_usage, color: DesignTokens.indigoLight),
            const SizedBox(width: DesignTokens.space8),
            Expanded(
              child: Text(
                usage == null
                    ? '文字数を確認中'
                    : '${usage.tier.toUpperCase()}  ${_formatNumber(usage.used)} / ${_formatNumber(usage.limit)}文字',
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (usage != null && usage.generationLimit > 0) ...[
          const SizedBox(height: DesignTokens.space4),
          Text(
            '生成回数 ${_formatNumber(usage.generationCount)} / ${_formatNumber(usage.generationLimit)}回',
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: DesignTokens.space8),
        LinearProgressIndicator(
          minHeight: 6,
          value: progress,
          color: progress >= 0.9 ? DesignTokens.amber : DesignTokens.indigo,
          backgroundColor: DesignTokens.surface3,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _resultPanel(VoiceDubbingResult result) {
    return _section(
      title: result.fileName,
      icon: Icons.audio_file_outlined,
      trailing:
          '${_formatNumber(result.characterCount)}文字 / ${result.chunkCount}区間',
      child: Row(
        children: [
          IconButton.filled(
            tooltip: '再生',
            onPressed: () => _api.preview(result),
            icon: const Icon(Icons.play_arrow),
          ),
          const SizedBox(width: DesignTokens.space8),
          IconButton.filledTonal(
            tooltip: 'ダウンロード',
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
          ),
          const Spacer(),
          const Icon(
            Icons.lock_outline,
            size: 16,
            color: DesignTokens.textTertiary,
          ),
          const SizedBox(width: DesignTokens.space4),
          const Text(
            '非公開保存',
            style: TextStyle(color: DesignTokens.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _voiceMenu() {
    if (_loadingVoices && _voices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_voices.isEmpty) {
      return const Text(
        '利用できる音声がありません。',
        style: TextStyle(color: DesignTokens.textSecondary),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _menu<VoiceOption>(
            key: const Key('dubbing-voice'),
            label: '音声 (${_voices.length})',
            value: _voice!,
            items: _voices,
            itemLabel: (voice) {
              final labels = voice.labels.values
                  .where((value) => value.isNotEmpty)
                  .take(2);
              return labels.isEmpty
                  ? voice.name
                  : '${voice.name} - ${labels.join(' / ')}';
            },
            onChanged: (voice) => setState(() {
              _voice = voice;
              _result = null;
            }),
          ),
        ),
        if (_voice?.previewUrl.isNotEmpty == true) ...[
          const SizedBox(width: DesignTokens.space8),
          IconButton.filledTonal(
            tooltip: '音声サンプルを再生',
            onPressed: () => _api.previewVoice(_voice!),
            icon: const Icon(Icons.volume_up_outlined),
          ),
        ],
      ],
    );
  }

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const SizedBox(height: DesignTokens.space12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1)
                const SizedBox(width: DesignTokens.space12),
            ],
          ],
        );
      },
    );
  }

  Widget _menu<T>({
    Key? key,
    required String label,
    required T value,
    required List<T> items,
    required String Function(T item) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return InputDecorator(
      key: key,
      decoration: _inputDecoration(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: DesignTokens.surface2,
          style: const TextStyle(color: DesignTokens.textPrimary),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (item) {
            if (item != null) onChanged(item);
          },
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double min = 0,
    double max = 1,
    bool enabled = true,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(
              color: enabled
                  ? DesignTokens.textPrimary
                  : DesignTokens.textDisabled,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: 20,
            label: value.toStringAsFixed(2),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(color: DesignTokens.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: DesignTokens.indigoLight),
              const SizedBox(width: DesignTokens.space8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DesignTokens.textSecondary),
        filled: true,
        fillColor: DesignTokens.surface2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.indigo),
        ),
      );

  String _message(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('FunctionException(status: 429, details: ', '上限に達しました: ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _formatNumber(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}
