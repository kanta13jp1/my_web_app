import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/inbox_capture_service.dart';
import '../services/note_semantic_search_service.dart';
import '../services/note_tag_service.dart';
import '../services/public_memo_service.dart';
import 'note_editor_page.dart';

enum _NoteCardAction {
  markOrganized,
  duplicate,
  publish,
  unpublish,
  delete,
}

enum _NoteListView { all, favorites, inbox }

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
  final NoteSemanticSearchDataSource? semanticSearchService;
  final String? initialSearchQuery;
  final String? initialTag;
  final int? initialCollectionId;

  const NoteListPage({
    super.key,
    this.prioritizeShareCandidates = false,
    this.supabaseClient,
    this.semanticSearchService,
    this.initialSearchQuery,
    this.initialTag,
    this.initialCollectionId,
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late final SupabaseClient _supabase;
  late final PublicMemoService _publicMemoService;
  late final NoteSemanticSearchDataSource _semanticSearchService;
  static const String _draftKeyPrefix = 'note_editor_draft_';
  static const int _notesPageSize = 500;
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  bool _showInboxOnly = false;
  List<Map<String, dynamic>> _notes = [];
  List<_LocalDraftEntry> _draftEntries = [];
  Set<String> _publishedNoteIds = <String>{};

  // Win版#108: メモ検索 (title + content 部分一致・case insensitive)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag;
  Set<int>? _allowedNotebookIds;
  Timer? _searchDebounce;
  List<NoteSearchResult> _semanticSearchResults = const <NoteSearchResult>[];
  String _semanticSearchMode = 'text_fallback';
  String? _semanticSearchError;
  bool _isSemanticSearching = false;
  bool _semanticSearchCompleted = false;
  int _semanticSearchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _publicMemoService = PublicMemoService(_supabase);
    _semanticSearchService =
        widget.semanticSearchService ?? NoteSemanticSearchService(_supabase);
    _searchQuery = widget.initialSearchQuery?.trim() ?? '';
    _searchController.text = _searchQuery;
    final initialTag = widget.initialTag?.trim();
    _selectedTag = initialTag == null || initialTag.isEmpty ? null : initialTag;
    inboxCaptureRevision.addListener(_handleInboxCapture);
    _fetchNotes();
  }

  @override
  void dispose() {
    inboxCaptureRevision.removeListener(_handleInboxCapture);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleInboxCapture() {
    _fetchNotes();
  }

  /// 検索クエリで note を絞り込み (title + content + tags 部分一致)。
  bool _matchesSearch(Map<String, dynamic> note) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final title = (note['title'] as String? ?? '').toLowerCase();
    final content = (note['content'] as String? ?? '').toLowerCase();
    return title.contains(q) ||
        content.contains(q) ||
        NoteTagService.containsSearch(note['tags'], q);
  }

  void _handleSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    final requestId = ++_semanticSearchRequestId;
    setState(() {
      _searchQuery = query;
      _semanticSearchResults = const <NoteSearchResult>[];
      _semanticSearchMode = 'text_fallback';
      _semanticSearchError = null;
      _semanticSearchCompleted = false;
      _isSemanticSearching = query.isNotEmpty;
    });
    if (query.isEmpty) return;

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_runSemanticSearch(query, requestId)),
    );
  }

  void _submitSearch(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      _handleSearchChanged('');
      return;
    }
    final requestId = ++_semanticSearchRequestId;
    setState(() {
      _searchQuery = query;
      _semanticSearchResults = const <NoteSearchResult>[];
      _semanticSearchMode = 'text_fallback';
      _semanticSearchError = null;
      _semanticSearchCompleted = false;
      _isSemanticSearching = true;
    });
    unawaited(_runSemanticSearch(query, requestId));
  }

  Future<void> _runSemanticSearch(String query, int requestId) async {
    try {
      final response = await _semanticSearchService.search(query);
      if (!mounted ||
          requestId != _semanticSearchRequestId ||
          query != _searchQuery) {
        return;
      }
      setState(() {
        _semanticSearchResults = response.results;
        _semanticSearchMode = response.searchMode;
        _semanticSearchCompleted = true;
        _isSemanticSearching = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _semanticSearchRequestId ||
          query != _searchQuery) {
        return;
      }
      setState(() {
        _semanticSearchError = error.toString();
        _semanticSearchCompleted = false;
        _isSemanticSearching = false;
      });
    }
  }

  List<Map<String, dynamic>> _visibleNotesForSearch(
    List<Map<String, dynamic>> notes,
  ) {
    final allowedNotebookIds = _allowedNotebookIds;
    final collectionFiltered = allowedNotebookIds == null
        ? notes
        : notes
            .where(
              (note) => allowedNotebookIds.contains(
                int.tryParse(
                  note['notebook_collection_id']?.toString() ?? '',
                ),
              ),
            )
            .toList(growable: false);
    final viewFiltered = _showInboxOnly
        ? collectionFiltered.where(_isInbox).toList(growable: false)
        : (_showFavoritesOnly
            ? collectionFiltered.where(_isFavorite).toList(growable: false)
            : collectionFiltered);
    final selectedTag = _selectedTag;
    final locallyFiltered = selectedTag == null
        ? viewFiltered
        : viewFiltered
            .where(
              (note) => NoteTagService.containsTag(note['tags'], selectedTag),
            )
            .toList(growable: false);
    if (_searchQuery.isEmpty) return locallyFiltered;
    if (!_semanticSearchCompleted || _semanticSearchError != null) {
      return locallyFiltered.where(_matchesSearch).toList();
    }

    final notesById = <String, Map<String, dynamic>>{
      for (final note in notes) _noteId(note): note,
    };
    final semanticMatches = _semanticSearchResults
        .map(
      (result) => result.toNoteRow(localNote: notesById[result.id]),
    )
        .where(
      (note) {
        final matchesView = _showInboxOnly
            ? _isInbox(note)
            : (!_showFavoritesOnly || _isFavorite(note));
        final matchesCollection = allowedNotebookIds == null ||
            allowedNotebookIds.contains(
              int.tryParse(
                note['notebook_collection_id']?.toString() ?? '',
              ),
            );
        return matchesView &&
            matchesCollection &&
            (selectedTag == null ||
                NoteTagService.containsTag(note['tags'], selectedTag));
      },
    ).toList(growable: false);
    final semanticIds = semanticMatches.map(_noteId).toSet();
    final localMatches = locallyFiltered
        .where(_matchesSearch)
        .where((note) => !semanticIds.contains(_noteId(note)));
    return <Map<String, dynamic>>[
      ...semanticMatches,
      ...localMatches,
    ];
  }

  String _searchStatusText(int resultCount) {
    if (_isSemanticSearching) return '意味検索中...';
    if (_semanticSearchError != null) {
      return 'オンライン検索を利用できないため端末内の一致を表示';
    }
    if (_semanticSearchCompleted) {
      final mode = _semanticSearchMode == 'ai' ? '意味検索' : 'あいまい検索';
      return '$resultCount件 / $mode';
    }
    return '$resultCount件';
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

      _allowedNotebookIds = await _resolveNotebookIds();
      final notes = await _fetchAllNotes(userId);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メモ一覧の取得に失敗しました: $e')),
      );
      setState(() {
        _draftEntries = drafts;
        _isLoading = false;
      });
    }
  }

  Future<Set<int>?> _resolveNotebookIds() async {
    final collectionId = widget.initialCollectionId;
    if (collectionId == null) return null;
    final rows = List<Map<String, dynamic>>.from(
      await _supabase
          .from('note_collections')
          .select('id,parent_id,collection_type'),
    );
    final included = <int>{collectionId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final row in rows) {
        final id = int.tryParse(row['id']?.toString() ?? '');
        final parentId = int.tryParse(row['parent_id']?.toString() ?? '');
        if (id != null && parentId != null && included.contains(parentId)) {
          changed = included.add(id) || changed;
        }
      }
    }
    return rows
        .where((row) => row['collection_type'] == 'notebook')
        .map((row) => int.tryParse(row['id']?.toString() ?? ''))
        .whereType<int>()
        .where(included.contains)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _fetchAllNotes(String userId) async {
    final notes = <Map<String, dynamic>>[];
    for (var from = 0;; from += _notesPageSize) {
      final data = await _supabase
          .from('notes')
          .select(
            'id, title, content, created_at, is_pinned, is_favorite, '
            'reminder_date, tags, capture_status, capture_source, inbox_saved_at, '
            'notebook_collection_id',
          )
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('is_pinned', ascending: false)
          .order('is_favorite', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + _notesPageSize - 1);
      final page = List<Map<String, dynamic>>.from(data);
      notes.addAll(page);
      if (page.length < _notesPageSize) break;
    }
    return notes;
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

  bool _isInbox(Map<String, dynamic> note) =>
      note['capture_status'] == inboxCaptureStatus;

  List<String> _noteTags(Map<String, dynamic> note) {
    return NoteTagService.normalize(note['tags']);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下書きを削除しました')),
    );
    await _fetchNotes();
  }

  void _toggleFavoritesOnly() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      _showInboxOnly = false;
    });
  }

  void _toggleInboxOnly() {
    setState(() {
      _showInboxOnly = !_showInboxOnly;
      _showFavoritesOnly = false;
    });
  }

  void _setListView(_NoteListView view) {
    setState(() {
      _showFavoritesOnly = view == _NoteListView.favorites;
      _showInboxOnly = view == _NoteListView.inbox;
    });
  }

  Future<void> _markNoteOrganized(
    BuildContext context,
    Map<String, dynamic> note,
  ) async {
    final noteId = _noteId(note);
    if (noteId.isEmpty || !_isInbox(note)) return;

    final tags = _noteTags(note)
        .where((tag) => tag.toLowerCase() != 'inbox')
        .toList(growable: false);
    try {
      await _supabase.from('notes').update({
        'capture_status': organizedCaptureStatus,
        'tags': tags,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', noteId);

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${_noteTitle(note)}」を整理済みにしました')),
      );
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inboxの更新に失敗しました: $e')),
      );
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
        SnackBar(
          content: Text(
            nextValue ? 'お気に入りに追加しました' : 'お気に入りを解除しました',
          ),
        ),
      );
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りの更新に失敗しました: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開するには保存済みメモが必要です')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開メモの公開に失敗しました')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開メモの公開停止に失敗しました')),
      );
      return;
    }

    setState(() {
      _publishedNoteIds = _publishedNoteIds
          .where((publishedId) => publishedId != _noteId(note))
          .toSet();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${_noteTitle(note)}」の公開を停止しました')),
    );
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
        'updated_at': now,
      }).eq('id', noteId);

      if (userId != null && numericNoteId != null) {
        await _publicMemoService.unpublishMemo(numericNoteId, userId);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_draftKeyPrefix$noteId');

      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$deletedTitle」を削除しました')),
      );
      _publishedNoteIds.remove(noteId);
      await _fetchNotes();
    } catch (e) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メモの削除に失敗しました: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メモの複製に失敗しました: $e')),
      );
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
        final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
        if (scoreCompare != 0) return scoreCompare;
        return (b['createdAt'] as DateTime)
            .compareTo(a['createdAt'] as DateTime);
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

  Widget _buildDraftCard(BuildContext context, _LocalDraftEntry draft) {
    final accentColor = Theme.of(context).colorScheme.onSurface;
    final savedAtLabel = DateFormat('yyyy/MM/dd HH:mm').format(draft.savedAt);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.12),
        ),
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
    final isInbox = _isInbox(note);
    final title = _noteTitle(note);
    final content = _noteContent(note);
    final tags = _noteTags(note);
    final reminderDate = _reminderDateOf(note);
    final accentColor = highlightShareCandidate
        ? const Color(0xFF6366F1)
        : (highlightReminder
            ? const Color(0xFF0D9488)
            : (isInbox
                ? const Color(0xFF0D9488)
                : (isPinned
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF6366F1))));
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
                    : isInbox
                        ? Icons.inbox_outlined
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
                if (isInbox && !highlightShareCandidate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '未整理',
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
                  const Icon(
                    Icons.star,
                    size: 18,
                    color: Color(0xFFFF6B35),
                  ),
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
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                key: ValueKey<String>('note_tags_${_noteId(note)}'),
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in tags.take(6))
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: ActionChip(
                        key: ValueKey<String>(
                          'note_list_tag_${_noteId(note)}_$tag',
                        ),
                        avatar: const Icon(Icons.sell_outlined, size: 14),
                        label: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedTag = tag;
                          });
                        },
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (tags.length > 6)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '+${tags.length - 6}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
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
                  case _NoteCardAction.markOrganized:
                    _markNoteOrganized(context, note);
                    break;
                  case _NoteCardAction.duplicate:
                    _duplicateNote(context, note);
                    break;
                  case _NoteCardAction.publish:
                    _publishNote(context, note);
                    break;
                  case _NoteCardAction.unpublish:
                    _unpublishNote(
                      context,
                      note,
                    );
                    break;
                  case _NoteCardAction.delete:
                    _deleteNote(
                      context,
                      note,
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                if (isInbox)
                  const PopupMenuItem<_NoteCardAction>(
                    value: _NoteCardAction.markOrganized,
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('整理済みにする'),
                      ],
                    ),
                  ),
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
    // 表示モード → 意味検索（失敗時は端末内検索）の順で絞り込む。
    final availableTags = NoteTagService.collectFromRows(_notes);
    final tagOptions = <String>[...availableTags];
    if (_selectedTag != null && !tagOptions.contains(_selectedTag)) {
      tagOptions.add(_selectedTag!);
    }
    final visibleNotes = _visibleNotesForSearch(_notes);
    final inboxEntries = visibleNotes.where(_isInbox).toList();
    final inboxIds =
        inboxEntries.map(_noteId).where((id) => id.isNotEmpty).toSet();
    final nonInboxNotes = visibleNotes
        .where((note) => !inboxIds.contains(_noteId(note)))
        .toList();
    final reminderEntries = _reminderEntries(nonInboxNotes);
    final reminderIds =
        reminderEntries.map(_noteId).where((id) => id.isNotEmpty).toSet();
    final reminderExcludedNotes = nonInboxNotes
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
    final hasAnyEntries = (!_showInboxOnly &&
            _searchQuery.isEmpty &&
            _selectedTag == null &&
            _draftEntries.isNotEmpty) ||
        visibleNotes.isNotEmpty;
    final pageTitle = _showInboxOnly
        ? 'CKO OFFICE (Inbox)'
        : (_showFavoritesOnly ? 'CKO OFFICE (お気に入り)' : 'CKO OFFICE (メモ一覧)');

    return Scaffold(
      key: const Key('note_list_page_scaffold'),
      appBar: AppBar(
        title: Text(
          pageTitle,
          key: const Key('note_list_page_title'),
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotes,
          ),
          IconButton(
            key: const Key('note_list_page_navigation_button'),
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: '保存済み検索・ショートカット',
            onPressed: () =>
                Navigator.of(context).pushNamed('/note-navigation'),
          ),
          IconButton(
            key: const Key('note_list_page_tasks_button'),
            icon: const Icon(Icons.task_alt_outlined),
            tooltip: 'ノートタスク',
            onPressed: () => Navigator.of(context).pushNamed('/note-tasks'),
          ),
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
          // Win版#108: メモ検索バー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('note_list_page_search_field'),
              controller: _searchController,
              onChanged: _handleSearchChanged,
              onSubmitted: _submitSearch,
              style: const TextStyle(
                color: Color(0xFFE5E7EB),
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: '自然な言葉でメモを検索...',
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
                          _handleSearchChanged('');
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<_NoteListView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<_NoteListView>(
                    value: _NoteListView.all,
                    icon: Icon(Icons.list_alt),
                    label: Text('すべて'),
                  ),
                  ButtonSegment<_NoteListView>(
                    value: _NoteListView.favorites,
                    icon: Icon(
                      Icons.star_border,
                      key: Key('note_list_page_favorites_filter'),
                    ),
                    label: Text('お気に入り'),
                  ),
                  ButtonSegment<_NoteListView>(
                    value: _NoteListView.inbox,
                    icon: Icon(
                      Icons.inbox_outlined,
                      key: Key('note_list_page_inbox_filter'),
                    ),
                    label: Text('Inbox'),
                  ),
                ],
                selected: <_NoteListView>{
                  if (_showInboxOnly)
                    _NoteListView.inbox
                  else if (_showFavoritesOnly)
                    _NoteListView.favorites
                  else
                    _NoteListView.all,
                },
                onSelectionChanged: (selection) =>
                    _setListView(selection.single),
              ),
            ),
          ),
          if (tagOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('タグで絞り込み'),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 180,
                      maxWidth: 320,
                    ),
                    child: DropdownButton<String>(
                      key: const Key('note_list_tag_filter'),
                      value: _selectedTag,
                      isExpanded: true,
                      hint: const Text('すべてのタグ'),
                      items: tagOptions
                          .map(
                            (tag) => DropdownMenuItem<String>(
                              value: tag,
                              child: Text(
                                tag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (tag) {
                        setState(() {
                          _selectedTag = tag;
                        });
                      },
                    ),
                  ),
                  if (_selectedTag != null)
                    TextButton.icon(
                      key: const Key('note_list_tag_filter_clear'),
                      onPressed: () {
                        setState(() {
                          _selectedTag = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('解除'),
                    ),
                ],
              ),
            ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    _isSemanticSearching
                        ? Icons.hourglass_top
                        : Icons.auto_awesome_outlined,
                    color: const Color(0xFF6366F1),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _searchStatusText(visibleNotes.length),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                              _selectedTag != null
                                  ? '「$_selectedTag」のメモはありません'
                                  : _showInboxOnly
                                      ? 'Inboxは空です'
                                      : (_showFavoritesOnly
                                          ? 'お気に入りのメモはまだありません'
                                          : 'まだメモがありません'),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFFB0B0B0),
                                height: 1.5,
                              ),
                            ),
                            if (_selectedTag != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedTag = null;
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('タグ絞り込みを解除'),
                              ),
                            ] else if (_showFavoritesOnly ||
                                _showInboxOnly) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _showInboxOnly
                                    ? _toggleInboxOnly
                                    : _toggleFavoritesOnly,
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
                          if (inboxEntries.isNotEmpty) ...[
                            _buildSectionHeader(
                              'Inbox（未整理）',
                              '思いついたことをそのまま置き、あとから整理できます。',
                            ),
                            ...inboxEntries.map(
                              (note) => _buildNoteCard(context, note),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (!_showInboxOnly &&
                              _searchQuery.isEmpty &&
                              _selectedTag == null &&
                              _draftEntries.isNotEmpty) ...[
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
      MaterialPageRoute(
        settings: const RouteSettings(name: '/note-editor'),
        builder: (_) => NoteEditorPage(
          noteId: noteId,
          supabaseClient: _supabase,
          semanticSearchService: _semanticSearchService,
        ),
      ),
    );
    _fetchNotes();
  }
}
