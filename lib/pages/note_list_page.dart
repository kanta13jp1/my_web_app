import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/public_memo_service.dart';
import '../services/note_inbox_service.dart';
import '../services/note_search_ranker.dart';
import 'note_editor_page.dart';

enum _NoteCardAction { duplicate, organize, publish, unpublish, delete }

class _LocalDraftEntry {
  final String storageKey;
  final String? noteId;
  final String title;
  final String content;
  final bool isFavorite;
  final DateTime savedAt;

  const _LocalDraftEntry({
    required this.storageKey,
    required this.noteId,
    required this.title,
    required this.content,
    required this.isFavorite,
    required this.savedAt,
  });

  bool get isNewNoteDraft => noteId == null || noteId!.isEmpty;
}

class NoteListPage extends StatefulWidget {
  final bool prioritizeShareCandidates;
  final SupabaseClient? supabaseClient;

  const NoteListPage({
    super.key,
    this.prioritizeShareCandidates = false,
    this.supabaseClient,
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late final SupabaseClient _supabase;
  late final PublicMemoService _publicMemoService;
  late final NoteInboxService _noteInboxService;
  static const String _draftKeyPrefix = 'note_editor_draft_';
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  bool _showInboxOnly = false;
  bool _isQuickCapturing = false;
  List<Map<String, dynamic>> _notes = [];
  List<_LocalDraftEntry> _draftEntries = [];
  Set<String> _publishedNoteIds = <String>{};

  // Win版#108: メモ検索 (title + content 部分一致・case insensitive)
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickInboxController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _publicMemoService = PublicMemoService(_supabase);
    _noteInboxService = NoteInboxService(_supabase);
    _fetchNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickInboxController.dispose();
    super.dispose();
  }

  /// 検索クエリで note を絞り込み (title + content 部分一致・case insensitive)
  bool _matchesSearch(Map<String, dynamic> note) {
    if (_searchQuery.isEmpty) return true;
    return NoteSearchRanker.matches(note, _searchQuery);
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        final drafts = await _loadDraftEntries(const <Map<String, dynamic>>[]);
        if (mounted) {
          setState(() {
            _notes = [];
            _draftEntries = drafts;
            _publishedNoteIds = <String>{};
            _isLoading = false;
          });
        }
        return;
      }

      final data = await _supabase
          .from('notes')
          .select(
            'id, title, content, created_at, is_pinned, is_favorite, reminder_date, tags, capture_status, capture_source, classification_status, inbox_saved_at',
          )
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('is_pinned', ascending: false)
          .order('is_favorite', ascending: false)
          .order('created_at', ascending: false);
      final notes = List<Map<String, dynamic>>.from(data);
      final results = await Future.wait<dynamic>([
        _loadDraftEntries(notes),
        _loadPublishedNoteIds(userId),
      ]);
      final drafts = results[0] as List<_LocalDraftEntry>;
      final publishedNoteIds = results[1] as Set<String>;

      if (!mounted) return;
      setState(() {
        _notes = notes;
        _draftEntries = drafts;
        _publishedNoteIds = publishedNoteIds;
        _isLoading = false;
      });
    } catch (e) {
      final drafts = await _loadDraftEntries(_notes);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メモ一覧の取得に失敗しました: $e')));
      setState(() {
        _draftEntries = drafts;
        _isLoading = false;
      });
    }
  }

  Future<Set<String>> _loadPublishedNoteIds(String userId) async {
    final memos = await _publicMemoService.getUserPublicMemos(userId);
    return memos.map((memo) => memo.noteId.toString()).toSet();
  }

  DateTime _createdAtOf(Map<String, dynamic> note) {
    final raw = note['created_at']?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  String _noteId(Map<String, dynamic> note) => note['id']?.toString() ?? '';

  int? _noteNumericId(Map<String, dynamic> note) => int.tryParse(_noteId(note));

  String _noteTitle(Map<String, dynamic> note) {
    final title = (note['title'] as String? ?? '').trim();
    return title.isEmpty ? '無題のメモ' : title;
  }

  String _noteContent(Map<String, dynamic> note) =>
      (note['content'] as String? ?? '').trim();

  bool _isFavorite(Map<String, dynamic> note) => note['is_favorite'] == true;

  List<String> _noteTags(Map<String, dynamic> note) {
    final rawTags = note['tags'];
    if (rawTags is List) {
      return rawTags
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  bool _isInboxNote(Map<String, dynamic> note) {
    final captureStatus = note['capture_status']?.toString();
    final classificationStatus = note['classification_status']?.toString();
    return captureStatus == NoteInboxService.captureStatusInbox ||
        classificationStatus == NoteInboxService.classificationStatusPending;
  }

  bool _isPublished(Map<String, dynamic> note) =>
      _publishedNoteIds.contains(_noteId(note));

  DateTime? _reminderDateOf(Map<String, dynamic> note) {
    final raw = note['reminder_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatReminderDate(DateTime reminderDate) =>
      DateFormat('MM/dd HH:mm').format(reminderDate);

  bool _isReminderOverdue(DateTime reminderDate) =>
      reminderDate.isBefore(DateTime.now());

  bool _isReminderDueToday(DateTime reminderDate) =>
      DateUtils.isSameDay(reminderDate, DateTime.now());

  String _reminderLabel(DateTime reminderDate) {
    if (_isReminderOverdue(reminderDate)) {
      return '期限超過 ${_formatReminderDate(reminderDate)}';
    }
    if (_isReminderDueToday(reminderDate)) {
      return '今日 ${DateFormat('HH:mm').format(reminderDate)}';
    }
    return _formatReminderDate(reminderDate);
  }

  Color _reminderColor(DateTime reminderDate) {
    if (_isReminderOverdue(reminderDate)) {
      return const Color(0xFFB91C1C);
    }
    if (_isReminderDueToday(reminderDate)) {
      return const Color(0xFFF57C00);
    }
    return const Color(0xFF0F766E);
  }

  List<Map<String, dynamic>> _reminderEntries(
    List<Map<String, dynamic>> notes,
  ) {
    final reminders =
        notes.where((note) => _reminderDateOf(note) != null).toList()
          ..sort((a, b) {
            final aReminder = _reminderDateOf(a) ?? DateTime(9999);
            final bReminder = _reminderDateOf(b) ?? DateTime(9999);
            return aReminder.compareTo(bReminder);
          });
    return reminders;
  }

  Future<List<_LocalDraftEntry>> _loadDraftEntries(
    List<Map<String, dynamic>> notes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final noteById = <String, Map<String, dynamic>>{
      for (final note in notes)
        if (_noteId(note).isNotEmpty) _noteId(note): note,
    };
    final drafts = <_LocalDraftEntry>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_draftKeyPrefix)) continue;

      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;

        final suffix = key.substring(_draftKeyPrefix.length);
        final noteId = suffix == 'new' ? null : suffix;
        final title = (decoded['title'] ?? '').toString();
        final content = (decoded['content'] ?? '').toString();
        final isFavorite = decoded['is_favorite'] == true;
        if (title.trim().isEmpty && content.trim().isEmpty && !isFavorite) {
          continue;
        }

        final fallbackNote = noteId == null ? null : noteById[noteId];
        final savedAt = DateTime.tryParse(
              (decoded['saved_at'] ?? '').toString(),
            )?.toLocal() ??
            _createdAtOf(fallbackNote ?? const <String, dynamic>{});

        drafts.add(
          _LocalDraftEntry(
            storageKey: key,
            noteId: noteId,
            title: title,
            content: content,
            isFavorite: isFavorite,
            savedAt: savedAt,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }

  String _draftTitle(_LocalDraftEntry draft) {
    final title = draft.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    if (draft.isNewNoteDraft) {
      return '新規メモの下書き';
    }

    for (final note in _notes) {
      if (_noteId(note) == draft.noteId) {
        return '${_noteTitle(note)} の下書き';
      }
    }
    return '編集中のメモ';
  }

  String _draftPreview(_LocalDraftEntry draft) {
    final content = draft.content.trim();
    if (content.isNotEmpty) {
      return content;
    }
    if (draft.isFavorite) {
      return 'お気に入りに追加したメモをここから再開できます。';
    }
    if (draft.isNewNoteDraft) {
      return '途中まで書いた新規メモをここから再開できます。';
    }
    return '保存前の変更があります。';
  }

  Future<void> _deleteDraft(_LocalDraftEntry draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draft.storageKey);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下書きを削除しました')));
    await _fetchNotes();
  }

  void _toggleFavoritesOnly() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      if (_showFavoritesOnly) _showInboxOnly = false;
    });
  }

  void _toggleInboxOnly() {
    setState(() {
      _showInboxOnly = !_showInboxOnly;
      if (_showInboxOnly) _showFavoritesOnly = false;
    });
  }

  Future<void> _quickCaptureInbox() async {
    final content = _quickInboxController.text.trim();
    if (content.isEmpty || _isQuickCapturing) return;

    setState(() => _isQuickCapturing = true);
    try {
      final noteId = await _noteInboxService.quickCapture(content);
      if (!mounted) return;
      _quickInboxController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved to Inbox.'),
          action: noteId == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  onPressed: () => _navigateToEditor(context, noteId),
                ),
        ),
      );
      await _fetchNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Inbox save failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isQuickCapturing = false);
      }
    }
  }

  Future<void> _markOrganized(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final noteId = _noteId(note);
    if (noteId.isEmpty) return;

    try {
      await _supabase.from('notes').update({
        'capture_status': NoteInboxService.captureStatusOrganized,
        'classification_status':
            NoteInboxService.classificationStatusClassified,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as organized.')));
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Organize failed: $e')));
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final noteId = _noteId(note);
    if (noteId.isEmpty) return;

    final nextValue = !_isFavorite(note);
    try {
      await _supabase.from('notes').update({
        'is_favorite': nextValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nextValue ? 'お気に入りに追加しました' : 'お気に入りを解除しました')),
      );
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('お気に入りの更新に失敗しました: $e')));
    }
  }

  Future<void> _publishNote(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    final noteId = _noteNumericId(note);
    if (userId == null || noteId == null) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公開するには保存済みメモが必要です')));
      return;
    }

    final success = await _publicMemoService.publishMemo(
      noteId: noteId,
      userId: userId,
      title: _noteTitle(note),
      content: _noteContent(note),
      category: null,
    );

    if (!mounted || !context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公開メモの公開に失敗しました')));
      return;
    }

    setState(() {
      _publishedNoteIds = <String>{..._publishedNoteIds, _noteId(note)};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${_noteTitle(note)}」を公開メモにしました'),
        action: SnackBarAction(
          label: '公開一覧',
          onPressed: () => Navigator.of(context).pushNamed('/public-memos'),
        ),
      ),
    );
  }

  Future<void> _unpublishNote(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    final noteId = _noteNumericId(note);
    if (userId == null || noteId == null) {
      return;
    }

    final success = await _publicMemoService.unpublishMemo(noteId, userId);
    if (!mounted || !context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('公開メモの公開停止に失敗しました')));
      return;
    }

    setState(() {
      _publishedNoteIds = _publishedNoteIds
          .where((publishedId) => publishedId != _noteId(note))
          .toSet();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「${_noteTitle(note)}」の公開を停止しました')));
  }

  Future<bool> _confirmDeleteNote(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final title = _noteTitle(note);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('メモを削除'),
        content: Text('「$title」を削除しますか？\n一覧から非表示になり、下書きも削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteNote(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final noteId = _noteId(note);
    if (noteId.isEmpty) return;

    final confirmed = await _confirmDeleteNote(context, note);
    if (!confirmed || !mounted || !context.mounted) return;

    final deletedTitle = _noteTitle(note);
    final now = DateTime.now().toIso8601String();
    final userId = _supabase.auth.currentUser?.id;
    final numericNoteId = _noteNumericId(note);

    try {
      await _supabase.from('notes').update({
        'is_archived': true,
        'archived_at': now,
        'updated_at': now
      }).eq('id', noteId);

      if (userId != null && numericNoteId != null) {
        await _publicMemoService.unpublishMemo(numericNoteId, userId);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_draftKeyPrefix$noteId');

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「$deletedTitle」を削除しました')));
      _publishedNoteIds.remove(noteId);
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メモの削除に失敗しました: $e')));
    }
  }

  String _buildDuplicateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return '無題のメモ (コピー)';
    }

    final match = RegExp(r'^(.*) \(コピー(?: (\d+))?\)$').firstMatch(trimmed);
    if (match == null) {
      return '$trimmed (コピー)';
    }

    final baseTitle = (match.group(1) ?? trimmed).trim();
    final currentCopyNumber = int.tryParse(match.group(2) ?? '1') ?? 1;
    return '$baseTitle (コピー ${currentCopyNumber + 1})';
  }

  Future<void> _duplicateNote(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final duplicateTitle = _buildDuplicateTitle(_noteTitle(note));
    final duplicateContent = _noteContent(note);

    try {
      final Map<String, dynamic>? inserted = await _supabase
          .from('notes')
          .insert({
            'user_id': userId,
            'title': duplicateTitle,
            'content': duplicateContent,
            'is_archived': false,
            'is_pinned': false,
          })
          .select('id')
          .maybeSingle();

      await _fetchNotes();
      if (!mounted || !context.mounted) return;

      final duplicatedId = inserted?['id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$duplicateTitle」を複製しました'),
          action: duplicatedId == null
              ? null
              : SnackBarAction(
                  label: '開く',
                  onPressed: () => _navigateToEditor(context, duplicatedId),
                ),
        ),
      );
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メモの複製に失敗しました: $e')));
    }
  }

  Map<String, dynamic>? _keywordMatch(
    String haystack,
    List<Map<String, dynamic>> keywordRules,
  ) {
    for (final rule in keywordRules) {
      final keyword = rule['keyword'] as String;
      if (haystack.contains(keyword)) {
        return rule;
      }
    }
    return null;
  }

  Map<String, dynamic> _buildShareCandidateEntry(Map<String, dynamic> note) {
    final title = _noteTitle(note);
    final content = _noteContent(note);
    final haystack = '$title $content'.toLowerCase();

    const keywordRules = <Map<String, dynamic>>[
      {'keyword': '共有', 'label': '共有語', 'score': 3},
      {'keyword': '投稿', 'label': '投稿語', 'score': 3},
      {'keyword': '導線', 'label': '導線語', 'score': 3},
      {'keyword': '告知', 'label': '告知語', 'score': 3},
      {'keyword': '紹介', 'label': '紹介語', 'score': 3},
      {'keyword': '登録', 'label': '登録語', 'score': 3},
      {'keyword': 'line', 'label': 'LINE向け', 'score': 3},
      {'keyword': 'facebook', 'label': 'Facebook向け', 'score': 3},
      {'keyword': 'qr', 'label': 'QR向け', 'score': 3},
      {'keyword': 'x', 'label': 'X向け', 'score': 2},
    ];

    final reasons = <String>[];
    var score = 0;

    if ((note['is_pinned'] as bool?) == true) {
      score += 3;
      reasons.add('ピン留め');
    }

    if (title.isNotEmpty) {
      score += 2;
      reasons.add('タイトルあり');
    }

    if (content.isNotEmpty) {
      score += 2;
      reasons.add('本文あり');
    }

    if (content.length >= 80) {
      score += 2;
      reasons.add('説明量あり');
    }

    if (content.length >= 160) {
      score += 1;
      reasons.add('長文素材');
    }

    final keywordMatch = _keywordMatch(haystack, keywordRules);
    if (keywordMatch != null) {
      score += keywordMatch['score'] as int;
      reasons.add(keywordMatch['label'] as String);
    }

    return <String, dynamic>{
      'note': note,
      'score': score,
      'reasons': reasons,
      'createdAt': _createdAtOf(note),
    };
  }

  List<Map<String, dynamic>> _shareCandidateEntries(
    List<Map<String, dynamic>> notes,
  ) {
    final entries = notes
        .where((note) {
          final title = _noteTitle(note);
          final content = _noteContent(note);
          return title.isNotEmpty || content.isNotEmpty;
        })
        .map(_buildShareCandidateEntry)
        .toList()
      ..sort((a, b) {
        final scoreCompare = (b['score'] as int).compareTo(
          a['score'] as int,
        );
        if (scoreCompare != 0) return scoreCompare;
        return (b['createdAt'] as DateTime).compareTo(
          a['createdAt'] as DateTime,
        );
      });

    if (entries.isNotEmpty) {
      return entries.take(3).toList();
    }

    return notes
        .take(3)
        .map((note) => _buildShareCandidateEntry(note))
        .toList();
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6366F1),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQuickInboxBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('note_list_page_quick_inbox_field'),
              controller: _quickInboxController,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _quickCaptureInbox(),
              decoration: InputDecoration(
                hintText: 'Drop a thought into Inbox...',
                prefixIcon: const Icon(Icons.inbox_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const Key('note_list_page_quick_inbox_save'),
            tooltip: 'Save to Inbox',
            onPressed: _isQuickCapturing ? null : _quickCaptureInbox,
            icon: _isQuickCapturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(BuildContext context, _LocalDraftEntry draft) {
    final accentColor = Theme.of(context).colorScheme.onSurface;
    final savedAtLabel = DateFormat('yyyy/MM/dd HH:mm').format(draft.savedAt);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.08),
                  child: Icon(Icons.drafts_outlined, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _draftTitle(draft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.isNewNoteDraft ? '新規メモの下書き' : '既存メモの下書き',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '下書きを削除',
                  onPressed: () => _deleteDraft(draft),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _draftPreview(draft),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '最終保存: $savedAtLabel',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outlineVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _navigateToEditor(context, draft.noteId),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('続きから編集'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    Map<String, dynamic> note, {
    bool highlightReminder = false,
    bool highlightShareCandidate = false,
    int? shareScore,
    List<String> shareReasons = const [],
  }) {
    final created = _createdAtOf(note);
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(created);
    final isPinned = note['is_pinned'] as bool? ?? false;
    final isFavorite = _isFavorite(note);
    final title = _noteTitle(note);
    final content = _noteContent(note);
    final isInbox = _isInboxNote(note);
    final tags = _noteTags(note);
    final reminderDate = _reminderDateOf(note);
    final accentColor = highlightShareCandidate
        ? const Color(0xFF6366F1)
        : (highlightReminder
            ? const Color(0xFF0D9488)
            : (isPinned ? const Color(0xFFFF6B35) : const Color(0xFF6366F1)));
    final fallbackAccentColor = isFavorite &&
            !highlightReminder &&
            !highlightShareCandidate &&
            !isPinned
        ? const Color(0xFFFF6B35)
        : accentColor;

    return Card(
      elevation: highlightShareCandidate ? 3 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: fallbackAccentColor.withValues(
            alpha: highlightShareCandidate ? 0.35 : 0.12,
          ),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: fallbackAccentColor.withValues(alpha: 0.12),
          child: Icon(
            highlightShareCandidate
                ? Icons.campaign
                : highlightReminder
                    ? Icons.alarm
                    : isPinned
                        ? Icons.push_pin
                        : isFavorite
                            ? Icons.star
                            : Icons.description,
            color: fallbackAccentColor,
            size: 20,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (highlightShareCandidate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '共有候補',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                        height: 1.5,
                      ),
                    ),
                  ),
                if (isInbox) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Inbox',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D9488),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                if (isFavorite) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 18, color: Color(0xFFFF6B35)),
                ],
              ],
            ),
            if (highlightShareCandidate) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (shareScore != null) _buildReasonChip('score $shareScore'),
                  ...shareReasons.take(4).map(_buildReasonChip),
                ],
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.take(5).map(_buildReasonChip).toList(),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminderDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _reminderColor(reminderDate).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm,
                      size: 14,
                      color: _reminderColor(reminderDate),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _reminderLabel(reminderDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _reminderColor(reminderDate),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content,
                maxLines: highlightShareCandidate ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isFavorite ? 'お気に入り解除' : 'お気に入りに追加',
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              color: isFavorite
                  ? const Color(0xFFFF6B35)
                  : Theme.of(context).colorScheme.outlineVariant,
              onPressed: () {
                _toggleFavorite(context, note);
              },
            ),
            PopupMenuButton<_NoteCardAction>(
              tooltip: 'メモ操作',
              onSelected: (action) {
                switch (action) {
                  case _NoteCardAction.duplicate:
                    _duplicateNote(context, note);
                    break;
                  case _NoteCardAction.organize:
                    _markOrganized(context, note);
                    break;
                  case _NoteCardAction.publish:
                    _publishNote(context, note);
                    break;
                  case _NoteCardAction.unpublish:
                    _unpublishNote(context, note);
                    break;
                  case _NoteCardAction.delete:
                    _deleteNote(context, note);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<_NoteCardAction>(
                  value: _NoteCardAction.duplicate,
                  child: Row(
                    children: [
                      Icon(Icons.copy_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('複製'),
                    ],
                  ),
                ),
                if (isInbox)
                  const PopupMenuItem<_NoteCardAction>(
                    value: _NoteCardAction.organize,
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 18),
                        SizedBox(width: 8),
                        Text('Mark organized'),
                      ],
                    ),
                  ),
                PopupMenuItem<_NoteCardAction>(
                  value: _isPublished(note)
                      ? _NoteCardAction.unpublish
                      : _NoteCardAction.publish,
                  child: Row(
                    children: [
                      Icon(
                        _isPublished(note)
                            ? Icons.public_off_outlined
                            : Icons.public,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_isPublished(note) ? '公開停止' : '公開する'),
                    ],
                  ),
                ),
                const PopupMenuItem<_NoteCardAction>(
                  value: _NoteCardAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 8),
                      Text('削除'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _navigateToEditor(context, _noteId(note)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Win版#108: お気に入り → 検索 の順でフィルタ適用
    final modeFiltered = _showInboxOnly
        ? _notes.where(_isInboxNote).toList()
        : _showFavoritesOnly
            ? _notes.where(_isFavorite).toList()
            : _notes;
    final visibleNotes = _searchQuery.isEmpty
        ? modeFiltered
        : modeFiltered.where(_matchesSearch).toList();
    final reminderEntries = _reminderEntries(visibleNotes);
    final reminderIds =
        reminderEntries.map(_noteId).where((id) => id.isNotEmpty).toSet();
    final reminderExcludedNotes = visibleNotes
        .where((note) => !reminderIds.contains(_noteId(note)))
        .toList();
    final shareCandidateEntries = widget.prioritizeShareCandidates
        ? _shareCandidateEntries(reminderExcludedNotes)
        : const <Map<String, dynamic>>[];
    final shareCandidateIds = shareCandidateEntries
        .map((entry) => _noteId(entry['note'] as Map<String, dynamic>))
        .where((id) => id.isNotEmpty)
        .toSet();
    final remainingNotes = widget.prioritizeShareCandidates
        ? reminderExcludedNotes
            .where((note) => !shareCandidateIds.contains(_noteId(note)))
            .toList()
        : reminderExcludedNotes;
    final hasAnyEntries = _draftEntries.isNotEmpty || visibleNotes.isNotEmpty;
    final pageTitle =
        _showFavoritesOnly ? 'CKO OFFICE (お気に入り)' : 'CKO OFFICE (メモ一覧)';

    final effectivePageTitle =
        _showInboxOnly ? 'CKO OFFICE (Inbox)' : pageTitle;

    return Scaffold(
      key: const Key('note_list_page_scaffold'),
      appBar: AppBar(
        title: Text(effectivePageTitle, key: const Key('note_list_page_title')),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            key: const Key('note_list_page_favorites_filter'),
            icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_border),
            color: _showFavoritesOnly ? const Color(0xFFFFD54F) : Colors.white,
            tooltip: _showFavoritesOnly ? 'すべてのメモを表示' : 'お気に入りのみ表示',
            onPressed: _toggleFavoritesOnly,
          ),
          IconButton(
            key: const Key('note_list_page_inbox_filter'),
            icon: Icon(_showInboxOnly ? Icons.inbox : Icons.inbox_outlined),
            color: _showInboxOnly ? const Color(0xFFA7F3D0) : Colors.white,
            tooltip: _showInboxOnly ? 'Show all notes' : 'Show Inbox',
            onPressed: _toggleInboxOnly,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchNotes),
          IconButton(
            icon: const Icon(Icons.public),
            tooltip: '公開メモ一覧',
            onPressed: () => Navigator.of(context).pushNamed('/public-memos'),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'インポート',
            onPressed: () => Navigator.of(context).pushNamed('/import'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickInboxBar(),
          // Win版#108: メモ検索バー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('note_list_page_search_field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'タイトル・本文で検索...',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                        tooltip: '検索クリア',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: Color(0xFF6366F1),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${visibleNotes.length} 件 ヒット',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !hasAnyEntries
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.note_alt_outlined,
                              size: 64,
                              color: Color(0xFFB0B0B0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showFavoritesOnly
                                  ? 'お気に入りのメモはまだありません'
                                  : 'まだメモがありません',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFFB0B0B0),
                                height: 1.5,
                              ),
                            ),
                            if (_showFavoritesOnly) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _toggleFavoritesOnly,
                                icon: const Icon(Icons.list_alt),
                                label: const Text('すべてのメモを見る'),
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('新しいメモを作成'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _navigateToEditor(context),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/import'),
                              icon: const Icon(Icons.file_upload_outlined),
                              label: const Text('Notion / Evernote を取り込む'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_draftEntries.isNotEmpty) ...[
                            _buildSectionHeader(
                              '下書き',
                              'X の下書きのように、書きかけのメモを一覧からすぐ再開できます。',
                            ),
                            ..._draftEntries.map(
                              (draft) => _buildDraftCard(context, draft),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (reminderEntries.isNotEmpty) ...[
                            _buildSectionHeader(
                              'リマインダー',
                              'Evernote のように、期限付きノートを先頭でまとめて確認できます。',
                            ),
                            ...reminderEntries.map(
                              (note) => _buildNoteCard(
                                context,
                                note,
                                highlightReminder: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (widget.prioritizeShareCandidates &&
                              shareCandidateEntries.isNotEmpty) ...[
                            _buildSectionHeader(
                              '共有向け候補',
                              'ピン留め・共有語・導線語・説明量をスコア化して上位3件を固定表示します。',
                            ),
                            ...shareCandidateEntries.map((entry) {
                              final note =
                                  entry['note'] as Map<String, dynamic>;
                              final score = entry['score'] as int;
                              final reasons = List<String>.from(
                                entry['reasons'] as List,
                              );
                              return _buildNoteCard(
                                context,
                                note,
                                highlightShareCandidate: true,
                                shareScore: score,
                                shareReasons: reasons,
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                          if (remainingNotes.isNotEmpty)
                            _buildSectionHeader(
                              widget.prioritizeShareCandidates
                                  ? 'すべてのメモ'
                                  : 'メモ一覧',
                              _showFavoritesOnly
                                  ? 'Evernote のスター付きノートのように、お気に入りだけをまとめて見返せます。'
                                  : widget.prioritizeShareCandidates
                                      ? '共有候補の下に、残りのメモを時系列で表示します。'
                                      : 'ピン留めとお気に入りを優先し、その後は新しい順に表示します。',
                            ),
                          ...remainingNotes.map(
                            (note) => _buildNoteCard(context, note),
                          ),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('note_list_page_fab'),
        onPressed: () => _navigateToEditor(context),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _navigateToEditor(BuildContext context, [String? noteId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: noteId)),
    );
    _fetchNotes();
  }
}
