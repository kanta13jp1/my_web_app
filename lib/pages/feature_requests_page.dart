import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/structured_field_chips.dart';

typedef FeatureRequestsLoader = Future<List<Map<String, dynamic>>> Function();
typedef FeatureRequestSubmitter = Future<void> Function(
  String title,
  String description,
);
typedef FeatureRequestVoter = Future<int?> Function(
  String id,
);

class FeatureRequestsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final FeatureRequestsLoader? loadRequests;
  final FeatureRequestSubmitter? submitRequest;
  final FeatureRequestVoter? voteRequest;

  const FeatureRequestsPage({
    super.key,
    this.supabaseClient,
    this.loadRequests,
    this.submitRequest,
    this.voteRequest,
  });

  static int? safeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      return int.tryParse(cleaned);
    }
    return null;
  }

  static String formatCreatedAt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return DateFormat('yyyy/MM/dd HH:mm').format(local);
  }

  @override
  State<FeatureRequestsPage> createState() => _FeatureRequestsPageState();
}

class _FeatureRequestsPageState extends State<FeatureRequestsPage> {
  List<Map<String, dynamic>> _requests = const <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;
  final Set<String> _votedIds = <String>{};
  final Set<String> _votingIds = <String>{};

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _defaultLoadRequests() async {
    final data = await _supabase
        .from('feature_requests')
        .select(
          'id, title, description, votes, status, created_at, user_id, '
          'priority, effort, target_date',
        )
        .eq('status', 'open')
        .order('votes', ascending: false)
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _defaultSubmitRequest(String title, String description) async {
    final user = _supabase.auth.currentUser;
    await _supabase.from('feature_requests').insert(<String, dynamic>{
      'user_id': user?.id,
      'email': user?.email,
      'title': title,
      'description': description,
      'votes': 1,
      'status': 'open',
    });
  }

  Future<int?> _defaultVoteRequest(String id) async {
    final res = await _supabase.rpc(
      'increment_feature_request_vote',
      params: <String, dynamic>{'p_request_id': id},
    );
    return FeatureRequestsPage.safeInt(res);
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: backgroundColor != null
              ? const TextStyle(color: Colors.white)
              : null,
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.loadRequests ?? _defaultLoadRequests;
      final rows = await loader();
      if (!mounted) return;
      setState(() {
        _requests = rows
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      });
    } catch (e) {
      debugPrint('FeatureRequestsPage load error: $e');
      if (!mounted) return;
      setState(() => _error = '機能要望を読み込めませんでした。時間をおいて再試行してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRequestDialog() async {
    final submitter = widget.submitRequest ?? _defaultSubmitRequest;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _FeatureRequestSubmitDialog(onSubmit: submitter),
    );
    if (submitted != true || !mounted) return;
    _showSnack('機能要望を保存しました。');
    await _loadRequests();
  }

  Future<void> _upvote(String id) async {
    if (id.isEmpty || _votedIds.contains(id) || _votingIds.contains(id)) {
      return;
    }

    setState(() => _votingIds.add(id));
    try {
      final voter = widget.voteRequest ?? _defaultVoteRequest;
      final updatedVotes = await voter(id);
      if (!mounted) return;
      if (updatedVotes == null) {
        _showSnack(
          '投票を反映できませんでした（受付終了または対象が見つかりません）。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }

      setState(() {
        _votedIds.add(id);
        _requests = _requests.map((request) {
          if ('${request['id'] ?? ''}' == id) {
            return <String, dynamic>{...request, 'votes': updatedVotes};
          }
          return request;
        }).toList(growable: false);
      });
    } catch (e) {
      _showSnack(
        '投票の保存に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    } finally {
      if (mounted) {
        setState(() => _votingIds.remove(id));
      }
    }
  }

  void _openRoute(String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('シングルページMVP'),
        actions: <Widget>[
          IconButton(
            tooltip: '更新',
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '今日使うコア機能',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '複雑な画面遷移を避け、記録・検索・発信の入口を1画面に集約しています。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 720;
                        final actions = <_CoreAction>[
                          _CoreAction(
                            icon: Icons.note_add_outlined,
                            title: '記録する',
                            subtitle: 'メモや作業ログを残す',
                            onTap: () => _openRoute('/note-editor'),
                          ),
                          _CoreAction(
                            icon: Icons.search_outlined,
                            title: '探す',
                            subtitle: '外部脳と既存メモを検索',
                            onTap: () => _openRoute('/memory-search'),
                          ),
                          _CoreAction(
                            icon: Icons.article_outlined,
                            title: '発信する',
                            subtitle: 'ブログとニュース投稿へ進む',
                            onTap: () => _openRoute('/blog'),
                          ),
                        ];
                        if (compact) {
                          return Column(
                            children: actions
                                .map(
                                  (action) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: action,
                                  ),
                                )
                                .toList(growable: false),
                          );
                        }
                        return Row(
                          children: actions
                              .map(
                                (action) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: action,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('feature_requests_open_dialog_button'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      onPressed: _openRequestDialog,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('機能要望を送る'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '届いている要望',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      _StatusMessage(
                        key: const Key('feature_requests_error_state'),
                        icon: Icons.error_outline,
                        color: colorScheme.error,
                        text: _error!,
                        liveRegion: true,
                        action: OutlinedButton.icon(
                          key: const Key('feature_requests_retry_button'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          onPressed: _loadRequests,
                          icon: const Icon(Icons.refresh),
                          label: const Text('再試行'),
                        ),
                      )
                    else if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_requests.isEmpty)
                      _StatusMessage(
                        key: const Key('feature_requests_empty_state'),
                        icon: Icons.inbox_outlined,
                        color: colorScheme.primary,
                        text: 'まだ要望はありません。最初の1件を送ってください。',
                      )
                    else
                      ..._requests.map(_buildRequestTile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final id = '${request['id'] ?? ''}';
    final votes = FeatureRequestsPage.safeInt(request['votes']) ?? 0;
    final title = '${request['title'] ?? ''}';
    final description = '${request['description'] ?? ''}'.trim();
    final createdAt = FeatureRequestsPage.formatCreatedAt(
      '${request['created_at'] ?? ''}',
    );
    final voted = id.isNotEmpty && _votedIds.contains(id);
    final voting = id.isNotEmpty && _votingIds.contains(id);
    final chips = <Widget?>[
      priorityChip(request['priority']?.toString()),
      effortChip(request['effort']?.toString()),
      dueDateChip(request['target_date']),
    ].whereType<Widget>().toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: chips),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (createdAt.isNotEmpty)
                  Text(
                    '受付日時: $createdAt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Tooltip(
                  message: voted ? '投票済み ($votes票)' : '$title に投票 ($votes票)',
                  child: OutlinedButton.icon(
                    key: Key('feature_request_vote_button_$id'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: (id.isEmpty || voted || voting)
                        ? null
                        : () => _upvote(id),
                    icon: voting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            voted
                                ? Icons.thumb_up_alt
                                : Icons.thumb_up_alt_outlined,
                            size: 18,
                          ),
                    label: Text(voted ? '投票済 $votes' : '$votes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRequestSubmitDialog extends StatefulWidget {
  final FeatureRequestSubmitter onSubmit;

  const _FeatureRequestSubmitDialog({
    required this.onSubmit,
  });

  @override
  State<_FeatureRequestSubmitDialog> createState() =>
      _FeatureRequestSubmitDialogState();
}

class _FeatureRequestSubmitDialogState
    extends State<_FeatureRequestSubmitDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _submitting = false;
  String? _titleError;
  String? _descriptionError;
  String? _submitError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final titleErr = title.length < 3 ? 'タイトルは3文字以上で入力してください。' : null;
    final descErr = description.length < 10 ? '詳細は10文字以上で入力してください。' : null;
    if (titleErr != null || descErr != null) {
      setState(() {
        _titleError = titleErr;
        _descriptionError = descErr;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _titleError = null;
      _descriptionError = null;
      _submitError = null;
    });
    try {
      await widget.onSubmit(title, description);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = '送信に失敗しました。時間をおいて再試行してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('機能要望を送る'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _titleController,
                maxLength: 120,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: '要望タイトル',
                  hintText: '例: ブログ投稿前に自動チェックしてほしい',
                  errorText: _titleError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_titleError != null || _submitError != null) {
                    setState(() {
                      _titleError = null;
                      _submitError = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: '詳細',
                  hintText: '困っていること、ほしい動作、成功条件を短く書いてください。',
                  errorText: _descriptionError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_descriptionError != null || _submitError != null) {
                    setState(() {
                      _descriptionError = null;
                      _submitError = null;
                    });
                  }
                },
              ),
              if (_submitError != null) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _submitError!,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('feature_requests_dialog_submit_button'),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? '送信中' : '送信'),
        ),
      ],
    );
  }
}

class _CoreAction extends StatelessWidget {
  const _CoreAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.liveRegion = false,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool liveRegion;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final messageText = Text(text);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: liveRegion
                    ? Semantics(liveRegion: true, child: messageText)
                    : messageText,
              ),
            ],
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }
}
