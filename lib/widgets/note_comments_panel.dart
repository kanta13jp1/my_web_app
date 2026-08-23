import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/note_comments_service.dart';

class NoteCommentsSheet extends StatelessWidget {
  const NoteCommentsSheet({
    super.key,
    required this.noteId,
    this.service,
    this.onCountChanged,
    this.currentUserId,
  });

  final int noteId;
  final NoteCommentsService? service;
  final ValueChanged<int>? onCountChanged;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.34,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return NoteCommentsPanel(
          noteId: noteId,
          service: service,
          onCountChanged: onCountChanged,
          currentUserId: currentUserId,
          scrollController: scrollController,
          showSheetHandle: true,
        );
      },
    );
  }
}

class NoteCommentsPanel extends StatefulWidget {
  const NoteCommentsPanel({
    super.key,
    required this.noteId,
    this.service,
    this.onCountChanged,
    this.currentUserId,
    this.scrollController,
    this.showSheetHandle = false,
  });

  final int noteId;
  final NoteCommentsService? service;
  final ValueChanged<int>? onCountChanged;
  final String? currentUserId;
  final ScrollController? scrollController;
  final bool showSheetHandle;

  @override
  State<NoteCommentsPanel> createState() => _NoteCommentsPanelState();
}

class _NoteCommentsPanelState extends State<NoteCommentsPanel> {
  late NoteCommentsService _service;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _internalScrollController = ScrollController();
  StreamSubscription<void>? _watchSubscription;

  List<NoteComment> _comments = const <NoteComment>[];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isRealtimeAvailable = true;
  String? _errorMessage;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _internalScrollController;

  String? get _currentUserId =>
      widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ?? SupabaseNoteCommentsService(Supabase.instance.client);
    unawaited(_loadComments());
    _attachRealtime();
  }

  @override
  void didUpdateWidget(covariant NoteCommentsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId ||
        oldWidget.service != widget.service) {
      _watchSubscription?.cancel();
      _service = widget.service ??
          SupabaseNoteCommentsService(Supabase.instance.client);
      setState(() {
        _comments = const <NoteComment>[];
        _errorMessage = null;
        _isLoading = true;
      });
      unawaited(_loadComments());
      _attachRealtime();
    }
  }

  @override
  void dispose() {
    _watchSubscription?.cancel();
    _inputController.dispose();
    _internalScrollController.dispose();
    super.dispose();
  }

  void _attachRealtime() {
    _watchSubscription =
        _service.watchCommentChanges(noteId: widget.noteId).listen(
      (_) {
        if (mounted && !_isRealtimeAvailable) {
          setState(() => _isRealtimeAvailable = true);
        }
        unawaited(_loadComments(showSpinner: false));
      },
      onError: (Object error) {
        if (!mounted) return;
        if (_isRealtimeAvailable) {
          setState(() => _isRealtimeAvailable = false);
        }
        unawaited(_loadComments(showSpinner: false));
        if (!isExpectedNoteCommentRealtimeDisconnect(error)) {
          debugPrint('Note comment realtime stream error: $error');
        }
      },
    );
  }

  Future<void> _loadComments({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final comments = await _service.fetchComments(noteId: widget.noteId);
      if (!mounted) {
        widget.onCountChanged?.call(comments.length);
        return;
      }
      setState(() {
        _comments = comments;
        _isLoading = false;
        _errorMessage = null;
      });
      widget.onCountChanged?.call(comments.length);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'コメントの取得に失敗しました: $error';
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final comment = await _service.addComment(
        noteId: widget.noteId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = <NoteComment>[..._comments, comment];
        _inputController.clear();
        _isSubmitting = false;
      });
      widget.onCountChanged?.call(_comments.length);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'コメントの投稿に失敗しました: $error';
      });
    }
  }

  Future<void> _deleteComment(NoteComment comment) async {
    try {
      await _service.deleteComment(commentId: comment.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .where((entry) => entry.id != comment.id)
            .toList(growable: false);
      });
      widget.onCountChanged?.call(_comments.length);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'コメントの削除に失敗しました: $error';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_effectiveScrollController.hasClients) return;
      _effectiveScrollController.animateTo(
        _effectiveScrollController.position.maxScrollExtent + 64,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _displayNameOf(NoteComment comment) {
    final raw = comment.userDisplayName?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    if (comment.userId == _currentUserId) {
      return 'あなた';
    }
    return 'ユーザー';
  }

  String _avatarLabelFor(NoteComment comment) {
    final displayName = _displayNameOf(comment).replaceAll(RegExp(r'\s+'), '');
    if (displayName.isEmpty) return '人';
    if (displayName.length == 1) return displayName;
    return displayName.substring(0, 2);
  }

  String _timestampLabelFor(NoteComment comment) {
    final formatted =
        DateFormat('M/d HH:mm').format(comment.createdAt.toLocal());
    final isEdited =
        comment.updatedAt.difference(comment.createdAt).inSeconds.abs() >= 1;
    return isEdited ? '$formatted 編集済み' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentCount = _comments.length;
    final cardBorder = theme.colorScheme.outline.withValues(alpha: 0.18);
    final badgeColor = theme.colorScheme.primary.withValues(alpha: 0.10);

    return SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          if (widget.showSheetHandle) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.comment_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'コメント',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$commentCount件',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (_isRealtimeAvailable)
                  Text(
                    'リアルタイム',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => unawaited(
                      _loadComments(showSpinner: false),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('手動更新'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'まだコメントはありません。\n下の入力欄から最初のコメントを追加できます。',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _effectiveScrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final isOwnComment = comment.userId == _currentUserId;
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _CommentAvatar(
                                    label: _avatarLabelFor(comment),
                                    avatarUrl: comment.userAvatarUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: <Widget>[
                                            Text(
                                              _displayNameOf(comment),
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              _timestampLabelFor(comment),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          comment.content,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwnComment) ...<Widget>[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: '削除',
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: theme.colorScheme.error,
                                      ),
                                      onPressed: () async {
                                        final shouldDelete =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) =>
                                              AlertDialog(
                                            title: const Text('コメントを削除しますか？'),
                                            content: const Text(
                                              'このコメントを削除します。あとから元に戻せません。',
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(false),
                                                child: const Text('キャンセル'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop(true),
                                                child: const Text('削除'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (shouldDelete == true) {
                                          await _deleteComment(comment);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: 'コメントを追加…',
                      counterText: '',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerLowest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _submitComment,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('送信'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({
    required this.label,
    this.avatarUrl,
  });

  final String label;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedUrl = avatarUrl?.trim();
    if (trimmedUrl != null && trimmedUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        foregroundImage: NetworkImage(trimmedUrl),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
