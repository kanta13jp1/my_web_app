import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'note_editor_page.dart';

enum _NoteCardAction {
  duplicate,
}

class NoteListPage extends StatefulWidget {
  final bool prioritizeShareCandidates;

  const NoteListPage({
    super.key,
    this.prioritizeShareCandidates = false,
  });

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _fetchNotes();
  }

  Future<void> _fetchNotes() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await _supabase
          .from('notes')
          .select('id, title, content, created_at, is_pinned')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _notes = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メモ一覧の取得に失敗しました: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  DateTime _createdAtOf(Map<String, dynamic> note) {
    final raw = note['created_at']?.toString();
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  String _noteId(Map<String, dynamic> note) => note['id']?.toString() ?? '';

  String _noteTitle(Map<String, dynamic> note) {
    final title = (note['title'] as String? ?? '').trim();
    return title.isEmpty ? '無題のメモ' : title;
  }

  String _noteContent(Map<String, dynamic> note) =>
      (note['content'] as String? ?? '').trim();

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
      final inserted = await _supabase
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
      if (!mounted) return;

      final duplicatedId = inserted is Map ? inserted['id']?.toString() : null;
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
      if (!mounted) return;
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
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
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
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.deepPurple.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    Map<String, dynamic> note, {
    bool highlightShareCandidate = false,
    int? shareScore,
    List<String> shareReasons = const [],
  }) {
    final created = _createdAtOf(note);
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(created);
    final isPinned = note['is_pinned'] as bool? ?? false;
    final title = _noteTitle(note);
    final content = _noteContent(note);
    final accentColor = highlightShareCandidate
        ? Colors.deepPurple
        : (isPinned ? Colors.orange : Colors.blue);

    return Card(
      elevation: highlightShareCandidate ? 3 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accentColor.withValues(
            alpha: highlightShareCandidate ? 0.35 : 0.12,
          ),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.12),
          child: Icon(
            highlightShareCandidate
                ? Icons.campaign
                : isPinned
                    ? Icons.push_pin
                    : Icons.description,
            color: accentColor,
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '共有候補',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
              ],
            ),
            if (highlightShareCandidate) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
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
            if (content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                content,
                maxLines: highlightShareCandidate ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<_NoteCardAction>(
          tooltip: 'メモ操作',
          onSelected: (action) {
            switch (action) {
              case _NoteCardAction.duplicate:
                _duplicateNote(context, note);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<_NoteCardAction>(
              value: _NoteCardAction.duplicate,
              child: Row(
                children: [
                  Icon(Icons.copy_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('複製'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToEditor(context, _noteId(note)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shareCandidateEntries = widget.prioritizeShareCandidates
        ? _shareCandidateEntries(_notes)
        : const <Map<String, dynamic>>[];
    final shareCandidateIds = shareCandidateEntries
        .map((entry) => _noteId(entry['note'] as Map<String, dynamic>))
        .where((id) => id.isNotEmpty)
        .toSet();
    final remainingNotes = widget.prioritizeShareCandidates
        ? _notes
            .where((note) => !shareCandidateIds.contains(_noteId(note)))
            .toList()
        : _notes;

    return Scaffold(
      key: const Key('note_list_page_scaffold'),
      appBar: AppBar(
        title: const Text(
          'CKO OFFICE (メモ一覧)',
          key: Key('note_list_page_title'),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.note_alt_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'まだメモがありません',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('新しいメモを作成'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _navigateToEditor(context),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.prioritizeShareCandidates &&
                        shareCandidateEntries.isNotEmpty) ...[
                      _buildSectionHeader(
                        '共有向け候補',
                        'ピン留め・共有語・導線語・説明量をスコア化して上位3件を固定表示します。',
                      ),
                      ...shareCandidateEntries.map((entry) {
                        final note = entry['note'] as Map<String, dynamic>;
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
                    _buildSectionHeader(
                      widget.prioritizeShareCandidates ? 'すべてのメモ' : 'メモ一覧',
                      widget.prioritizeShareCandidates
                          ? '共有候補の下に、残りのメモを時系列で表示します。'
                          : 'ピン留め済みメモを優先し、その後は新しい順に表示します。',
                    ),
                    ...remainingNotes.map(
                      (note) => _buildNoteCard(context, note),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        key: const Key('note_list_page_fab'),
        onPressed: () => _navigateToEditor(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _navigateToEditor(BuildContext context, [String? noteId]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(noteId: noteId),
      ),
    );
    _fetchNotes();
  }
}
