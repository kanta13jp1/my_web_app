import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attachment.dart';
import '../models/note_snapshot.dart';
import '../services/ai_model_preference_service.dart';
import '../services/ai_service.dart';
import '../services/attachment_cache_service.dart';
import '../services/attachment_service.dart';
import '../services/auto_save_service.dart';
import '../services/note_comments_service.dart';
import '../services/note_prompt_library_service.dart';
import '../services/note_semantic_search_service.dart';
import '../services/note_tag_service.dart';
import '../services/note_task_service.dart';
import '../services/public_memo_service.dart';
import '../services/undo_redo_service.dart';
import '../utils/note_image_clipboard.dart';
import '../utils/note_image_drop.dart';
import '../widgets/attachment_list_widget.dart';
import '../widgets/ai_free_limit_upgrade_dialog.dart';
import '../widgets/markdown_preview.dart';
import '../widgets/note_comments_panel.dart';
import '../widgets/note_editor/ai_assistant_menu.dart';
import '../widgets/note_editor/editor_dialogs.dart';
import '../widgets/note_tags_field.dart';
import '../widgets/note_tasks_panel.dart';
import '../widgets/related_notes_strip.dart';

class NoteEditorPage extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;
  final SupabaseClient? supabaseClient;
  final AIService? aiService;
  final NoteSemanticSearchDataSource? semanticSearchService;
  final AiModelPreferenceService modelPreferenceService;
  final NotePromptLibraryService promptLibraryService;

  const NoteEditorPage({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
    this.supabaseClient,
    this.aiService,
    this.semanticSearchService,
    this.modelPreferenceService = const AiModelPreferenceService(),
    this.promptLibraryService = const NotePromptLibraryService(),
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

enum NoteEditorAiStyle {
  normal,
  concise,
  formal,
  explanatory,
}

extension NoteEditorAiStyleX on NoteEditorAiStyle {
  String get commandValue {
    switch (this) {
      case NoteEditorAiStyle.normal:
        return 'normal';
      case NoteEditorAiStyle.concise:
        return 'concise';
      case NoteEditorAiStyle.formal:
        return 'formal';
      case NoteEditorAiStyle.explanatory:
        return 'explanatory';
    }
  }

  String get label {
    switch (this) {
      case NoteEditorAiStyle.normal:
        return '標準';
      case NoteEditorAiStyle.concise:
        return '簡潔';
      case NoteEditorAiStyle.formal:
        return '硬め';
      case NoteEditorAiStyle.explanatory:
        return '詳しく';
    }
  }

  String get helperText {
    switch (this) {
      case NoteEditorAiStyle.normal:
        return 'ふだんの編集に向いたバランスの取れたトーンです。';
      case NoteEditorAiStyle.concise:
        return '短く直接的で、ざっと読みやすい文章にします。';
      case NoteEditorAiStyle.formal:
        return '落ち着いた、ビジネス向けの言い回しにします。';
      case NoteEditorAiStyle.explanatory:
        return '背景や理由を補い、筋道を追いやすくします。';
    }
  }

  String? get instruction {
    switch (this) {
      case NoteEditorAiStyle.normal:
        return null;
      case NoteEditorAiStyle.concise:
        return 'Use a concise writing style. Keep the output brief, direct, and easy to scan. Prefer shorter sentences and compact structure.';
      case NoteEditorAiStyle.formal:
        return 'Use a polished and professional writing style. Keep the tone calm, businesslike, and well structured.';
      case NoteEditorAiStyle.explanatory:
        return 'Use an explanatory writing style. Add enough context to make the reasoning easy to follow, while staying clear and practical.';
    }
  }
}

NoteEditorAiStyle? _tryParseNoteEditorAiStyle(String? raw) {
  final normalized = raw?.trim().toLowerCase();
  switch (normalized) {
    case 'normal':
    case 'default':
    case 'standard':
      return NoteEditorAiStyle.normal;
    case 'concise':
    case 'brief':
    case 'short':
      return NoteEditorAiStyle.concise;
    case 'formal':
    case 'professional':
      return NoteEditorAiStyle.formal;
    case 'explanatory':
    case 'explain':
    case 'teacher':
      return NoteEditorAiStyle.explanatory;
    default:
      return null;
  }
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _slashCommandController;
  late FocusNode _contentFocusNode;
  late AutoSaveService _autoSaveService;
  late UndoRedoService _undoRedoService;
  late final SupabaseClient _supabase;
  late final AIService _aiService;
  late final NoteCommentsService _noteCommentsService;
  late final NoteSemanticSearchDataSource _semanticSearchService;
  NoteImagePasteRegistration? _imagePasteRegistration;

  String? _currentNoteId;
  DateTime? _reminderDate;
  bool _isFavorite = false;
  List<String> _tags = const <String>[];
  bool _isLoading = false;
  bool _isLoadingAttachments = false;
  bool _isUploadingAttachment = false;
  bool _isRunningSlashCommand = false;
  bool _isApplyingSnapshot = false;
  String _observedTitle = '';
  String _observedContent = '';
  String? _persistedTitle;
  String? _persistedContent;
  String? _persistedReminderIso;
  bool? _persistedIsFavorite;
  List<String>? _persistedTags;
  DateTime? _serverUpdatedAt;
  bool _showMarkdownPreview = false;
  bool? _isSlashCommandBarExpanded;
  int _commentCount = 0;
  NoteEditorAiStyle _selectedAiStyle = NoteEditorAiStyle.normal;
  String? _selectedAiModel;
  List<NotePromptTemplate> _savedPromptTemplates = const <NotePromptTemplate>[];
  List<Attachment> _attachments = const <Attachment>[];
  List<NoteSearchResult> _relatedNotes = const <NoteSearchResult>[];
  bool _isLoadingRelatedNotes = false;
  bool _relatedNotesHasError = false;
  int _relatedNotesRequestId = 0;
  static const String _draftKeyPrefix = 'note_editor_draft_';
  static const String _aiStylePreferenceKey = 'note_editor_ai_style';
  static const String _slashBarExpandedKey = 'note_editor_slash_bar_expanded';
  static const List<String> _slashCommandSuggestions = <String>[
    '/help',
    '/improve',
    '/summarize',
    '/prompt executive-brief',
    '/style concise',
    '/title',
    '/translate en',
    '/favorite',
    '/stamp',
    '/tabs',
  ];
  static final List<NotePromptTemplate> _builtInPromptTemplates =
      <NotePromptTemplate>[
    NotePromptTemplate(
      id: 'executive-brief',
      title: 'Executive Brief',
      prompt:
          'Rewrite the current note as a concise executive brief.\n\nInclude:\n- Executive summary\n- Decisions made\n- Risks or blockers\n- Next steps with owners\n\nContext\nTitle: {{note_title}}\nContent:\n{{note_content}}',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    NotePromptTemplate(
      id: 'follow-up-message',
      title: 'Follow-up Message',
      prompt:
          'Turn the current note into a clear follow-up message that can be shared with teammates.\n\nUse this information:\nTitle: {{note_title}}\nContent:\n{{note_content}}\n\nKeep the tone aligned with {{writing_style}}.',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    NotePromptTemplate(
      id: 'counterpoint-review',
      title: 'Counterpoint Review',
      prompt:
          'Review the current note like a skeptical partner.\n\nContext\nTitle: {{note_title}}\nContent:\n{{note_content}}\n\nList blind spots, assumptions, and questions that should be answered before acting.',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _aiService = widget.aiService ?? AIService(_supabase);
    _noteCommentsService = SupabaseNoteCommentsService(_supabase);
    _semanticSearchService =
        widget.semanticSearchService ?? NoteSemanticSearchService(_supabase);
    _currentNoteId = widget.noteId;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _slashCommandController = TextEditingController();
    _contentFocusNode = FocusNode();
    _autoSaveService = AutoSaveService();
    _undoRedoService = UndoRedoService();
    _imagePasteRegistration = registerNoteImagePasteListener(
      isEnabled: () =>
          mounted &&
          !_showMarkdownPreview &&
          !_isUploadingAttachment &&
          _contentFocusNode.hasFocus,
      onImagePasted: _handlePastedImage,
    );

    _bootstrapEditor();
  }

  Future<void> _bootstrapEditor() async {
    await _loadPreferredAiModel();
    await _loadAiStylePreference();
    await _loadSlashBarExpanded();
    await _loadPromptTemplates();
    if (_currentNoteId != null) {
      await _loadNote(_currentNoteId!);
      unawaited(_loadCommentCount());
      unawaited(_loadRelatedNotes());
    }
    await _loadAttachments();
    await _restoreDraftFromLocal();
    _initializeEditorHistory();
    _attachTextListeners();
  }

  /// スラッシュコマンド欄の開閉はメモを開き直すたびにリセットされていた
  /// (= 折りたたんでも次回また 240px 占有する)。選択を端末に残す。
  Future<void> _persistSlashBarExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_slashBarExpandedKey, expanded);
  }

  Future<void> _loadSlashBarExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_slashBarExpandedKey)) return;
    final stored = prefs.getBool(_slashBarExpandedKey);
    if (stored == null || !mounted) return;
    setState(() {
      _isSlashCommandBarExpanded = stored;
    });
  }

  String _currentDraftKey() {
    return '$_draftKeyPrefix${_currentNoteId ?? 'new'}';
  }

  bool get _hasPersistableState =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _reminderDate != null ||
      _isFavorite ||
      _tags.isNotEmpty;

  bool _boolFromValue(dynamic value) => value == true;

  Future<void> _persistDraftToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final title = _titleController.text;
    final content = _contentController.text;
    if (!_hasPersistableState) {
      await prefs.remove(_currentDraftKey());
      return;
    }
    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'reminder_date': _reminderDate?.toIso8601String(),
      'is_favorite': _isFavorite,
      'tags': _tags,
      // サーバーの updated_at と比較するため UTC で保存する。
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString(_currentDraftKey(), jsonEncode(payload));
  }

  Future<void> _restoreDraftFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentDraftKey());
    if (raw == null || raw.trim().isEmpty) return;

    String title;
    String content;
    DateTime? reminderDate;
    bool isFavorite;
    List<String> tags;
    DateTime? draftSavedAt;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      title = (decoded['title'] ?? '').toString();
      content = (decoded['content'] ?? '').toString();
      reminderDate = decoded['reminder_date'] == null
          ? null
          : DateTime.tryParse(decoded['reminder_date'].toString())?.toLocal();
      isFavorite = _boolFromValue(decoded['is_favorite']);
      tags = NoteTagService.normalize(decoded['tags']);
      draftSavedAt = decoded['saved_at'] == null
          ? null
          : DateTime.tryParse(decoded['saved_at'].toString())?.toUtc();
    } catch (_) {
      return;
    }
    if (title.isEmpty &&
        content.isEmpty &&
        reminderDate == null &&
        !isFavorite &&
        tags.isEmpty) {
      return;
    }

    final hasChanges = _titleController.text != title ||
        _contentController.text != content ||
        _reminderDate?.toIso8601String() != reminderDate?.toIso8601String() ||
        _isFavorite != isFavorite ||
        !NoteTagService.equals(_tags, tags);
    if (!hasChanges) return;

    // 下書きより後にサーバー側が更新されている場合 (= 別端末での編集) は
    // 黙って上書きしない。どちらを採用するかはユーザーに決めてもらう。
    final serverUpdatedAt = _serverUpdatedAt;
    final serverIsNewer = draftSavedAt != null &&
        serverUpdatedAt != null &&
        serverUpdatedAt.isAfter(draftSavedAt);
    if (serverIsNewer) {
      if (!mounted) return;
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('未送信の下書きがあります'),
          content: const Text(
            'この端末に残っている下書きより、サーバー側のメモの方が新しく更新されています。\n'
            '別の端末で編集した可能性があります。どちらを表示しますか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('サーバー版を使う'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('下書きを復元'),
            ),
          ],
        ),
      );
      if (restore == null) {
        return;
      }
      if (!restore) {
        await _clearDraftFromLocal();
        return;
      }
    }

    _titleController.text = title;
    _contentController.text = content;
    _reminderDate = reminderDate;
    _isFavorite = isFavorite;
    _tags = tags;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ローカルの下書きを復元しました')),
      );
    }
  }

  Future<void> _clearDraftFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentDraftKey());
  }

  void _attachTextListeners() {
    _syncObservedText();
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  /// listener が「本文が変わった」と判断するための基準値を現在値に合わせる。
  /// TextEditingController はキャレット移動・選択変更でも notifyListeners する
  /// ため、この基準値と比較しないと no-op 保存が大量に走る。
  void _syncObservedText() {
    _observedTitle = _titleController.text;
    _observedContent = _contentController.text;
  }

  /// サーバーに保存済みの内容を記録し、無変更 PATCH を弾けるようにする。
  void _markStatePersisted({
    required String title,
    required String content,
    required String? reminderIso,
    required bool isFavorite,
    required List<String> tags,
  }) {
    _persistedTitle = title;
    _persistedContent = content;
    _persistedReminderIso = reminderIso;
    _persistedIsFavorite = isFavorite;
    _persistedTags = NoteTagService.normalize(tags);
  }

  /// サーバー側の内容を一度でも取得できているか。取得できていない状態で
  /// 自動保存すると、空のエディタ内容で既存メモを潰す危険がある。
  bool get _hasServerBaseline =>
      _currentNoteId == null || _persistedTitle != null;

  /// 現在の編集内容がサーバー保存済みの内容と一致するか。
  bool _matchesPersistedState({
    required String title,
    required String content,
    required String? reminderIso,
    required bool isFavorite,
    required List<String> tags,
  }) {
    return _persistedTitle == title &&
        _persistedContent == content &&
        _persistedReminderIso == reminderIso &&
        _persistedIsFavorite == isFavorite &&
        NoteTagService.equals(_persistedTags, tags);
  }

  void _detachTextListeners() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
  }

  NoteSnapshot _buildCurrentSnapshot() {
    return NoteSnapshot(
      title: _titleController.text,
      content: _contentController.text,
      categoryId: null,
      timestamp: DateTime.now(),
    );
  }

  void _initializeEditorHistory() {
    _undoRedoService.clear();
    _undoRedoService.addSnapshot(_buildCurrentSnapshot());

    final hasAnyInput = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty ||
        _reminderDate != null ||
        _isFavorite ||
        _tags.isNotEmpty;
    // ローカル下書きを復元した直後は、画面上の内容がサーバーより新しい。
    // 従来はここで無条件に markAsSaved していたため「保存済み」と表示され
    // つつサーバーには届かず、次に何か入力するまで反映されなかった。
    final matchesServer = _currentNoteId != null &&
        _matchesPersistedState(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          reminderIso: _reminderDate?.toUtc().toIso8601String(),
          isFavorite: _isFavorite,
          tags: _tags,
        );

    if (matchesServer || (_currentNoteId == null && !hasAnyInput)) {
      _autoSaveService.markAsSaved();
      return;
    }

    _autoSaveService.markAsModified();
    // 既存メモの読み込みに失敗しているとサーバー側の基準値が無い。その状態で
    // 自動保存すると空の本文で上書きしかねないので送らない。
    if (_hasServerBaseline && _currentNoteId != null) {
      _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    }
  }

  void _onTextChanged() {
    if (_isApplyingSnapshot) return;

    // キャレット移動・選択変更だけでも listener は発火する。本文が変わって
    // いないなら履歴追加も自動保存もローカル下書き書き込みも不要。
    final title = _titleController.text;
    final content = _contentController.text;
    if (title == _observedTitle && content == _observedContent) {
      return;
    }
    _observedTitle = title;
    _observedContent = content;

    _undoRedoService.addSnapshot(_buildCurrentSnapshot());
    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    _persistDraftToLocal();
  }

  void _handleReminderChanged(DateTime? reminderDate) {
    setState(() {
      _reminderDate = reminderDate?.toLocal();
    });
    _autoSaveService.markAsModified();
    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    _persistDraftToLocal();
  }

  void _handleTagsChanged(List<String> tags) {
    final normalized = NoteTagService.normalize(tags);
    if (NoteTagService.equals(_tags, normalized)) return;
    setState(() {
      _tags = normalized;
    });
    _autoSaveService.markAsModified();
    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    _persistDraftToLocal();
  }

  Future<void> _showTagsEditor() async {
    var workingTags = List<String>.from(_tags);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'タグを編集',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    NoteTagsField(
                      tags: workingTags,
                      onChanged: (tags) {
                        setSheetState(() {
                          workingTags = tags;
                        });
                        _handleTagsChanged(tags);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTasksPanel() async {
    final noteId = int.tryParse(_currentNoteId ?? '');
    if (noteId == null) {
      _showMessage('タスクを追加する前にメモを保存してください');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: NoteTasksPanel(
          noteId: noteId,
          repository: SupabaseNoteTaskRepository(_supabase),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _showUpgradeDialogIfNeeded(Object error) async {
    if (error is! AIServiceException || !error.isFreeLimitReached || !mounted) {
      return false;
    }
    return showAiFreeLimitUpgradeDialog(context, error);
  }

  Future<int?> _ensureNoteIdForAttachmentFlow() async {
    final existingNoteId = int.tryParse(_currentNoteId ?? '');
    if (existingNoteId != null) {
      return existingNoteId;
    }

    if (_hasPersistableState) {
      await _saveNoteWithoutClosing();
      final savedNoteId = int.tryParse(_currentNoteId ?? '');
      if (savedNoteId != null) {
        return savedNoteId;
      }
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Login is required.');
    }

    final dynamic inserted = await _supabase
        .from('notes')
        .insert({
          'user_id': user.id,
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'reminder_date': _reminderDate?.toUtc().toIso8601String(),
          'is_favorite': _isFavorite,
          'is_archived': false,
          'is_pinned': false,
        })
        .select('id')
        .maybeSingle();

    final createdNoteId = inserted is Map && inserted['id'] != null
        ? int.tryParse(inserted['id'].toString())
        : null;
    if (createdNoteId == null) {
      return null;
    }

    _currentNoteId = createdNoteId.toString();
    unawaited(_loadCommentCount());
    _autoSaveService.markAsSaved();
    await _clearDraftFromLocal();
    if (mounted) {
      setState(() {});
    }
    return createdNoteId;
  }

  Future<void> _loadAttachments() async {
    final noteId = int.tryParse(_currentNoteId ?? '');
    if (noteId == null) {
      if (mounted) {
        setState(() {
          _attachments = const <Attachment>[];
          _isLoadingAttachments = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAttachments = true;
      });
    }
    try {
      final attachments = await AttachmentService.getAttachments(noteId);
      if (!mounted) return;
      setState(() {
        _attachments = attachments;
      });
    } catch (e) {
      _showMessage('添付ファイルの読み込みに失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> _insertAttachmentFromPicker() async {
    try {
      final file = await AttachmentService.pickFile();
      if (file == null) return;
      await _uploadAttachmentFile(file, sourceLabel: 'ファイル');
    } catch (e) {
      _showMessage('画像の追加に失敗しました: $e');
    }
  }

  Future<void> _handlePastedImage(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final extension = _extensionForMimeType(mimeType);
    final effectiveFileName =
        fileName.trim().isEmpty ? 'pasted-image.$extension' : fileName;
    final file = PlatformFile(
      name: effectiveFileName,
      size: bytes.length,
      bytes: bytes,
    );
    await _uploadAttachmentFile(file, sourceLabel: 'クリップボード');
  }

  Future<void> _uploadAttachmentFile(
    PlatformFile file, {
    required String sourceLabel,
  }) async {
    if (_isUploadingAttachment) return;
    final noteId = await _ensureNoteIdForAttachmentFlow();
    if (noteId == null) {
      _showMessage('画像を保存できるメモを作成できませんでした');
      return;
    }

    if (mounted) {
      setState(() {
        _isUploadingAttachment = true;
      });
    }

    try {
      final attachment = await AttachmentService.uploadFile(
        noteId: noteId,
        file: file,
      );
      if (attachment == null) {
        throw StateError('添付情報を保存できませんでした');
      }

      AttachmentCacheService.clearNoteCache(noteId);
      _insertContentAtCursor(_buildAttachmentMarkdown(attachment));
      await _saveNoteWithoutClosing();
      await _loadAttachments();
      _showMessage('$sourceLabelから ${attachment.fileName} を追加しました');
    } catch (e) {
      _showMessage('$sourceLabelからの画像追加に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    try {
      await AttachmentService.deleteAttachment(attachment);
      AttachmentCacheService.clearNoteCache(attachment.noteId);
      if (!mounted) return;
      setState(() {
        _attachments = _attachments
            .where((item) => item.id != attachment.id)
            .toList(growable: false);
      });
      _showMessage('添付ファイルを削除しました');
    } catch (e) {
      _showMessage('添付ファイルの削除に失敗しました: $e');
    }
  }

  String _buildAttachmentMarkdown(Attachment attachment) {
    final url = AttachmentService.getMarkdownUrl(attachment.filePath);
    final label = _escapeMarkdownLabel(
      attachment.fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    if (attachment.isImage) {
      return '\n![$label]($url)\n';
    }
    return '\n[${_escapeMarkdownLabel(attachment.fileName)}]($url)\n';
  }

  String _escapeMarkdownLabel(String value) {
    return value.replaceAll('[', r'\[').replaceAll(']', r'\]');
  }

  String _extensionForMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }

  void _insertContentAtCursor(String text) {
    final value = _contentController.value;
    final selection = value.selection;
    final fallbackOffset = value.text.length;
    final rawStart = selection.isValid ? selection.start : fallbackOffset;
    final rawEnd = selection.isValid ? selection.end : fallbackOffset;
    final start = rawStart.clamp(0, value.text.length);
    final end = rawEnd.clamp(start, value.text.length);
    final nextText = value.text.replaceRange(start, end, text);
    final offset = start + text.length;
    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
    _contentFocusNode.requestFocus();
  }

  void _setTitleText(String value) {
    _titleController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _setContentText(String value) {
    _contentController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _prefillSlashCommand(String command) {
    _slashCommandController.value = TextEditingValue(
      text: command,
      selection: TextSelection.collapsed(offset: command.length),
    );
  }

  Future<void> _loadAiStylePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final nextStyle = _tryParseNoteEditorAiStyle(
          prefs.getString(_aiStylePreferenceKey),
        ) ??
        NoteEditorAiStyle.normal;
    if (!mounted) {
      _selectedAiStyle = nextStyle;
      return;
    }
    setState(() {
      _selectedAiStyle = nextStyle;
    });
  }

  Future<void> _loadPreferredAiModel() async {
    final preferredModel =
        await widget.modelPreferenceService.loadPreferredModel();
    if (!mounted) {
      _selectedAiModel = preferredModel;
      return;
    }
    setState(() {
      _selectedAiModel = preferredModel;
    });
  }

  Future<void> _loadPromptTemplates() async {
    final templates = await widget.promptLibraryService.loadTemplates();
    if (!mounted) {
      _savedPromptTemplates = templates;
      return;
    }
    setState(() {
      _savedPromptTemplates = templates;
    });
  }

  Future<void> _persistAiStylePreference(NoteEditorAiStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiStylePreferenceKey, style.commandValue);
  }

  Future<void> _setAiStyle(
    NoteEditorAiStyle style, {
    bool announce = true,
  }) async {
    if (mounted) {
      setState(() {
        _selectedAiStyle = style;
      });
    } else {
      _selectedAiStyle = style;
    }
    await _persistAiStylePreference(style);
    if (announce) {
      _showMessage('文章のトーン: ${style.label}');
    }
  }

  List<NotePromptTemplate> get _availablePromptTemplates =>
      <NotePromptTemplate>[
        ..._builtInPromptTemplates,
        ..._savedPromptTemplates,
      ];

  String _normalizePromptTemplateKey(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized;
  }

  String _buildPromptTemplateId(String title) {
    final base = _normalizePromptTemplateKey(title);
    if (base.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    final existingIds =
        _savedPromptTemplates.map((template) => template.id).toSet();
    if (!existingIds.contains(base)) {
      return base;
    }

    var suffix = 2;
    while (existingIds.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  NotePromptTemplate? _findPromptTemplate(String rawQuery) {
    final normalized = _normalizePromptTemplateKey(rawQuery);
    if (normalized.isEmpty) {
      return null;
    }

    for (final template in _availablePromptTemplates) {
      if (template.id == normalized) {
        return template;
      }
    }

    for (final template in _availablePromptTemplates) {
      if (_normalizePromptTemplateKey(template.title) == normalized) {
        return template;
      }
    }

    for (final template in _availablePromptTemplates) {
      final titleKey = _normalizePromptTemplateKey(template.title);
      if (titleKey.contains(normalized) || normalized.contains(titleKey)) {
        return template;
      }
    }

    return null;
  }

  String _resolvePromptTemplateVariables(String prompt) {
    final today = DateTime.now().toLocal();
    final noteTitle = _titleController.text.trim();
    final noteContent = _contentController.text.trim();
    final replacements = <String, String>{
      '{{note_title}}': noteTitle.isEmpty ? '(untitled note)' : noteTitle,
      '{{note_content}}': noteContent.isEmpty ? '(empty note)' : noteContent,
      '{{writing_style}}': _selectedAiStyle.commandValue,
      '{{today}}':
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      '{{default_model}}': _selectedAiModel ?? 'auto',
    };

    var resolved = prompt;
    for (final entry in replacements.entries) {
      resolved = resolved.replaceAll(entry.key, entry.value);
    }
    return resolved.trim();
  }

  String _buildPromptTemplateRequest(NotePromptTemplate template) {
    final noteTitle = _titleController.text.trim();
    final noteContent = _contentController.text.trim();
    final resolvedTemplate = _resolvePromptTemplateVariables(template.prompt);

    return <String>[
      'You are running a saved prompt from a Claude-style workbench.',
      'Template title: ${template.title}',
      'Selected writing style: ${_selectedAiStyle.commandValue}',
      'Current note title: ${noteTitle.isEmpty ? '(untitled note)' : noteTitle}',
      'Current note content:',
      noteContent.isEmpty ? '(empty note)' : noteContent,
      'Saved prompt:',
      resolvedTemplate,
      'Return only the final result requested by the saved prompt.',
    ].join('\n\n');
  }

  Future<void> _runPromptTemplate(NotePromptTemplate template) async {
    if (_isRunningSlashCommand) {
      return;
    }

    final hasNoteContext = _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty;
    if (!hasNoteContext) {
      _showMessage(
        'Add a note title or content before running a saved prompt.',
      );
      return;
    }

    setState(() {
      _isRunningSlashCommand = true;
    });

    try {
      final result = await _aiService.runCustomPrompt(
        _buildPromptTemplateRequest(template),
        model: _selectedAiModel,
        styleName: _selectedAiStyle.commandValue,
        styleInstruction: _selectedAiStyle.instruction,
      );
      _setContentText(result);
      _showMessage('Prompt applied: ${template.title}');
    } catch (e) {
      if (await _showUpgradeDialogIfNeeded(e)) {
        return;
      }
      _showMessage('Prompt failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSlashCommand = false;
        });
      } else {
        _isRunningSlashCommand = false;
      }
    }
  }

  Future<void> _savePromptTemplate(NotePromptTemplate template) async {
    final nextTemplates = await widget.promptLibraryService.saveTemplate(
      template,
    );
    if (!mounted) {
      _savedPromptTemplates = nextTemplates;
      return;
    }
    setState(() {
      _savedPromptTemplates = nextTemplates;
    });
    _showMessage('Saved prompt: ${template.title}');
  }

  Future<void> _deletePromptTemplate(NotePromptTemplate template) async {
    final nextTemplates = await widget.promptLibraryService.deleteTemplate(
      template.id,
    );
    if (!mounted) {
      _savedPromptTemplates = nextTemplates;
      return;
    }
    setState(() {
      _savedPromptTemplates = nextTemplates;
    });
    _showMessage('Removed prompt: ${template.title}');
  }

  Future<void> _showPromptTemplateDialog() async {
    if (!mounted) {
      return;
    }

    final titleController = TextEditingController();
    final promptController = TextEditingController(
      text:
          'Rewrite this note for a new audience.\n\nTitle: {{note_title}}\nContent:\n{{note_content}}',
    );

    final createdTemplate = await showDialog<NotePromptTemplate>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Save Prompt Template'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const Key(
                          'note_editor_prompt_template_title_field',
                        ),
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Template Name',
                          hintText: 'Board Brief',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key(
                          'note_editor_prompt_template_prompt_field',
                        ),
                        controller: promptController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Prompt',
                          hintText:
                              'Use {{note_title}}, {{note_content}}, {{writing_style}}, {{today}}, or {{default_model}}.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Variables: {{note_title}}, {{note_content}}, {{writing_style}}, {{today}}, {{default_model}}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('note_editor_prompt_template_save_button'),
                  onPressed: () {
                    final title = titleController.text.trim();
                    final prompt = promptController.text.trim();
                    if (title.isEmpty || prompt.isEmpty) {
                      setDialogState(() {
                        errorText = 'Name and prompt are both required.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      NotePromptTemplate(
                        id: _buildPromptTemplateId(title),
                        title: title,
                        prompt: prompt,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  },
                  child: const Text('Save Prompt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (createdTemplate == null) {
      return;
    }

    await _savePromptTemplate(createdTemplate);
  }

  String _formatCommandTimestamp(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  void _appendTimestampBlock() {
    final timestamp = '## ${_formatCommandTimestamp(DateTime.now().toLocal())}';
    final current = _contentController.text.trimRight();
    final nextContent = current.isEmpty ? timestamp : '$current\n\n$timestamp';
    _setContentText(nextContent);
  }

  void _appendTabsBlock() {
    const tabsTemplate = '## タブ 1\n\n（ここに内容を書く）\n\n---\n\n'
        '## タブ 2\n\n（ここに内容を書く）\n\n---\n\n'
        '## タブ 3\n\n（ここに内容を書く）';
    final current = _contentController.text.trimRight();
    final nextContent =
        current.isEmpty ? tabsTemplate : '$current\n\n$tabsTemplate';
    _setContentText(nextContent);
  }

  Future<void> _showSlashCommandHelp() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Slash Commands'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('/help Show available commands'),
            SizedBox(height: 8),
            Text('/improve Improve the current note'),
            SizedBox(height: 8),
            Text('/summarize Summarize the current note'),
            SizedBox(height: 8),
            Text('/prompt <name> Run a saved prompt template'),
            SizedBox(height: 8),
            Text('/title Suggest a title from the current note'),
            SizedBox(height: 8),
            Text('/translate en Translate the current note'),
            SizedBox(height: 8),
            Text('/favorite Toggle favorite for this note'),
            SizedBox(height: 8),
            Text('/stamp Insert the current timestamp'),
            SizedBox(height: 8),
            Text('/tabs Insert a 3-tab block template'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSlashCommand() async {
    if (_isRunningSlashCommand) return;

    final rawInput = _slashCommandController.text.trim();
    if (rawInput.isEmpty) {
      _showMessage('スラッシュコマンドを入力してください');
      return;
    }
    if (!rawInput.startsWith('/')) {
      _showMessage('コマンドは / から始めてください');
      return;
    }

    final body = rawInput.substring(1).trim();
    if (body.isEmpty) {
      _showMessage('コマンド名を入力してください');
      return;
    }

    final parts = body.split(RegExp(r'\s+'));
    final command = parts.first.toLowerCase();
    final arguments = parts.skip(1).toList(growable: false);

    switch (command) {
      case 'help':
        await _showSlashCommandHelp();
        _slashCommandController.clear();
        return;
      case 'favorite':
      case 'fav':
      case 'star':
        _toggleFavorite();
        _slashCommandController.clear();
        return;
      case 'style':
      case 'tone':
        if (arguments.isEmpty) {
          _showMessage(
            'Available AI styles: normal, concise, formal, explanatory',
          );
          return;
        }
        final nextStyle = _tryParseNoteEditorAiStyle(arguments.join(' '));
        if (nextStyle == null) {
          _showMessage(
            'Unknown AI style. Use: normal, concise, formal, explanatory',
          );
          return;
        }
        await _setAiStyle(nextStyle);
        _slashCommandController.clear();
        return;
      case 'stamp':
      case 'date':
        _appendTimestampBlock();
        _slashCommandController.clear();
        _showMessage('タイムスタンプを追加しました');
        return;
      case 'tabs':
      case 'tab':
        _appendTabsBlock();
        _slashCommandController.clear();
        _showMessage('タブブロックを追加しました');
        return;
      case 'prompt':
      case 'template':
        if (arguments.isEmpty) {
          final available = _availablePromptTemplates
              .map((template) => template.id)
              .join(', ');
          _showMessage('Available prompts: $available');
          return;
        }
        final template = _findPromptTemplate(arguments.join(' '));
        if (template == null) {
          _showMessage('Prompt not found. Try /prompt executive-brief');
          return;
        }
        _slashCommandController.clear();
        await _runPromptTemplate(template);
        return;
      case 'clear':
        _setContentText('');
        _slashCommandController.clear();
        _showMessage('本文をクリアしました');
        return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMessage('本文が空です。改善・要約・翻訳の前にメモを書いてください');
      return;
    }

    setState(() {
      _isRunningSlashCommand = true;
    });

    try {
      switch (command) {
        case 'improve':
          final improved = await _aiService.improveText(
            content,
            model: _selectedAiModel,
            styleName: _selectedAiStyle.commandValue,
            styleInstruction: _selectedAiStyle.instruction,
          );
          _setContentText(improved);
          _showMessage('本文を改善しました');
          break;
        case 'summarize':
        case 'summary':
          final summary = await _aiService.summarizeText(
            content,
            model: _selectedAiModel,
            styleName: _selectedAiStyle.commandValue,
            styleInstruction: _selectedAiStyle.instruction,
          );
          _setContentText(summary);
          _showMessage('本文を要約しました');
          break;
        case 'title':
          final suggestions = await _aiService.suggestTitles(
            content,
            model: _selectedAiModel,
          );
          if (suggestions.isEmpty) {
            _showMessage('タイトル候補を生成できませんでした');
            break;
          }
          _setTitleText(suggestions.first);
          _showMessage('タイトル候補を適用しました');
          break;
        case 'translate':
          final targetLanguage = arguments.isEmpty ? 'en' : arguments.join(' ');
          final translated = await _aiService.translateText(
            content,
            targetLanguage: targetLanguage,
            model: _selectedAiModel,
            styleName: _selectedAiStyle.commandValue,
            styleInstruction: _selectedAiStyle.instruction,
          );
          _setContentText(translated);
          _showMessage('本文を $targetLanguage に翻訳しました');
          break;
        default:
          _showMessage('未対応のコマンドです: /$command');
          return;
      }
      _slashCommandController.clear();
    } catch (e) {
      if (await _showUpgradeDialogIfNeeded(e)) {
        return;
      }
      _showMessage('コマンドの実行に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSlashCommand = false;
        });
      }
    }
  }

  Future<void> _loadNote(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('notes')
          .select(
            'title, content, reminder_date, is_favorite, tags, updated_at',
          )
          .eq('id', id)
          .single();
      _serverUpdatedAt = data['updated_at'] == null
          ? null
          : DateTime.tryParse(data['updated_at'].toString())?.toUtc();

      if (mounted) {
        setState(() {
          _titleController.text = data['title'] as String? ?? '';
          _contentController.text = data['content'] as String? ?? '';
          _reminderDate = data['reminder_date'] == null
              ? null
              : DateTime.tryParse(
                  data['reminder_date'].toString(),
                )?.toLocal();
          _isFavorite = _boolFromValue(data['is_favorite']);
          _tags = NoteTagService.normalize(data['tags']);
        });
        _markStatePersisted(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          reminderIso: _reminderDate?.toUtc().toIso8601String(),
          isFavorite: _isFavorite,
          tags: _tags,
        );
        _syncObservedText();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メモの読み込みに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRelatedNotes() async {
    final noteId = _currentNoteId;
    if (noteId == null || !mounted) return;
    final requestId = ++_relatedNotesRequestId;

    setState(() {
      _isLoadingRelatedNotes = true;
      _relatedNotesHasError = false;
    });
    try {
      final notes = await _semanticSearchService.relatedNotes(
        noteId: noteId,
        title: _titleController.text,
        content: _contentController.text,
        limit: 5,
      );
      if (!mounted ||
          requestId != _relatedNotesRequestId ||
          noteId != _currentNoteId) {
        return;
      }
      setState(() {
        _relatedNotes = notes;
        _isLoadingRelatedNotes = false;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _relatedNotesRequestId ||
          noteId != _currentNoteId) {
        return;
      }
      setState(() {
        _isLoadingRelatedNotes = false;
        _relatedNotesHasError = true;
      });
    }
  }

  Future<void> _indexAndRefreshRelatedNotes() async {
    final noteId = _currentNoteId;
    if (noteId == null) return;
    try {
      await _semanticSearchService.indexNote(noteId);
    } catch (_) {
      // Related search still provides a text fallback when vector indexing fails.
    }
    if (mounted && noteId == _currentNoteId) {
      await _loadRelatedNotes();
    }
  }

  Future<void> _openRelatedNote(NoteSearchResult note) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/note-editor'),
        builder: (_) => NoteEditorPage(
          noteId: note.id,
          supabaseClient: _supabase,
          semanticSearchService: _semanticSearchService,
          modelPreferenceService: widget.modelPreferenceService,
          promptLibraryService: widget.promptLibraryService,
        ),
      ),
    );
    if (mounted) unawaited(_loadRelatedNotes());
  }

  Future<void> _saveNoteWithoutClosing() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final reminderIso = _reminderDate?.toUtc().toIso8601String();
    final isFavorite = _isFavorite;
    final tags = NoteTagService.normalize(_tags);

    if (!_hasPersistableState && _currentNoteId == null) {
      return;
    }

    if (_currentNoteId != null && !_hasServerBaseline) {
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Login is required.');

    if (_currentNoteId != null) {
      // 保存済みの内容と完全一致するなら PATCH を送らない。
      if (_matchesPersistedState(
        title: title,
        content: content,
        reminderIso: reminderIso,
        isFavorite: isFavorite,
        tags: tags,
      )) {
        _autoSaveService.markAsSaved();
        return;
      }
      await _supabase.from('notes').update({
        'title': title,
        'content': content,
        'reminder_date': reminderIso,
        'is_favorite': isFavorite,
        'tags': tags,
        // timestamptz 列にはオフセット付きで渡す。ローカル時刻のまま送ると
        // サーバー側で UTC と解釈され JST 環境では 9 時間ずれる。
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentNoteId!);
    } else {
      final dynamic inserted = await _supabase
          .from('notes')
          .insert({
            'user_id': user.id,
            'title': title,
            'content': content,
            'reminder_date': reminderIso,
            'is_favorite': isFavorite,
            'tags': tags,
            'is_archived': false,
            'is_pinned': false,
          })
          .select('id')
          .maybeSingle();

      if (inserted is Map && inserted['id'] != null) {
        _currentNoteId = inserted['id'].toString();
        unawaited(_loadCommentCount());
        if (mounted) {
          setState(() {});
        }
      }
    }

    _markStatePersisted(
      title: title,
      content: content,
      reminderIso: reminderIso,
      isFavorite: isFavorite,
      tags: tags,
    );

    final currentMatchesSavedRequest = _matchesPersistedState(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      reminderIso: _reminderDate?.toUtc().toIso8601String(),
      isFavorite: _isFavorite,
      tags: _tags,
    );
    if (currentMatchesSavedRequest) {
      _autoSaveService.markAsSaved();
      await _clearDraftFromLocal();
    } else {
      _autoSaveService.markAsModified();
    }
  }

  Future<void> _saveManually() async {
    if (!_hasPersistableState && _currentNoteId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存する内容がありません')),
        );
      }
      return;
    }

    try {
      await _autoSaveService.saveImmediately(_saveNoteWithoutClosing);
      await _saveVersionSnapshot();
      unawaited(_indexAndRefreshRelatedNotes());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('手動保存しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _saveVersionSnapshot() async {
    final noteId = _currentNoteId;
    if (noteId == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('note_versions').insert({
        'note_id': noteId,
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // バージョン保存失敗は無視（メイン保存は成功している）
    }
  }

  Future<void> _publishNote() async {
    final noteId = _currentNoteId;
    if (noteId == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してから公開してください')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メモを公開する'),
        content: Text('「$title」を公開メモとして公開します。\n誰でも閲覧できるようになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('公開する'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final service = PublicMemoService(_supabase);
    final ok = await service.publishMemo(
      noteId: int.tryParse(noteId.toString()) ?? 0,
      userId: user.id,
      title: title,
      content: _contentController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('公開しました！ /public-memos で確認できます'),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('公開に失敗しました')),
      );
    }
  }

  Future<void> _loadCommentCount() async {
    final noteId = int.tryParse(_currentNoteId ?? '');
    if (noteId == null) return;
    try {
      final count = await _noteCommentsService.getCommentCount(noteId: noteId);
      if (!mounted) return;
      if (mounted) setState(() => _commentCount = count);
    } catch (_) {
      // silently ignore
    }
  }

  Future<void> _showComments() async {
    final noteId = int.tryParse(_currentNoteId ?? '');
    if (noteId == null) return;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => NoteCommentsSheet(
        noteId: noteId,
        service: _noteCommentsService,
        currentUserId: _supabase.auth.currentUser?.id,
        onCountChanged: (count) {
          if (mounted) setState(() => _commentCount = count);
        },
      ),
    );
  }

  Future<void> _showVersionHistory() async {
    final noteId = _currentNoteId;
    if (noteId == null) return;

    List<Map<String, dynamic>> versions = [];
    try {
      final res = await _supabase
          .from('note_versions')
          .select('id, title, saved_at, content')
          .eq('note_id', noteId)
          .order('saved_at', ascending: false)
          .limit(30);
      versions = List<Map<String, dynamic>>.from(
        (res as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('履歴の取得に失敗しました: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'バージョン履歴',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const Divider(),
            Expanded(
              child: versions.isEmpty
                  ? const Center(child: Text('保存済みバージョンがありません'))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: versions.length,
                      itemBuilder: (_, i) {
                        final v = versions[i];
                        final savedAt = DateTime.tryParse(
                          v['saved_at']?.toString() ?? '',
                        )?.toLocal();
                        final dateStr = savedAt != null
                            ? '${savedAt.year}/${savedAt.month.toString().padLeft(2, '0')}/${savedAt.day.toString().padLeft(2, '0')} ${savedAt.hour.toString().padLeft(2, '0')}:${savedAt.minute.toString().padLeft(2, '0')}'
                            : '不明';
                        final title =
                            (v['title'] as String?)?.isNotEmpty == true
                                ? v['title'] as String
                                : '無題';
                        return ListTile(
                          leading: const Icon(Icons.restore, size: 20),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          trailing: TextButton(
                            child: const Text('復元'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('バージョンを復元しますか？'),
                                  content: Text(
                                    '$dateStr 時点の内容に戻します。現在の内容は自動で新しいバージョンとして保存されます。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('キャンセル'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('復元'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted) {
                                await _saveVersionSnapshot();
                                if (!mounted) return;
                                setState(() {
                                  _titleController.text =
                                      v['title'] as String? ?? '';
                                  _contentController.text =
                                      v['content'] as String? ?? '';
                                });
                                _autoSaveService.markAsModified();
                                _autoSaveService
                                    .triggerAutoSave(_saveNoteWithoutClosing);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _applySnapshot(NoteSnapshot snapshot) {
    _isApplyingSnapshot = true;
    _titleController.value = TextEditingValue(
      text: snapshot.title,
      selection: TextSelection.collapsed(offset: snapshot.title.length),
    );
    _contentController.value = TextEditingValue(
      text: snapshot.content,
      selection: TextSelection.collapsed(offset: snapshot.content.length),
    );
    _isApplyingSnapshot = false;
    // listener を抑止したまま本文を差し替えたので基準値を追従させる。
    _syncObservedText();

    _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
  }

  void _toggleFavorite() {
    final nextValue = !_isFavorite;
    setState(() {
      _isFavorite = nextValue;
    });
    _autoSaveService.markAsModified();
    _persistDraftToLocal();
    if (_currentNoteId != null || _hasPersistableState) {
      _autoSaveService.triggerAutoSave(_saveNoteWithoutClosing);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextValue ? 'お気に入りに追加しました' : 'お気に入りを解除しました',
        ),
      ),
    );
  }

  void _undo() {
    final snapshot = _undoRedoService.undo();
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  void _redo() {
    final snapshot = _undoRedoService.redo();
    if (snapshot != null) {
      _applySnapshot(snapshot);
    }
  }

  String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatReminderDate(DateTime dateTime) =>
      '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${_formatTime(dateTime)}';

  Color _reminderColor(BuildContext context) {
    final reminderDate = _reminderDate;
    if (reminderDate == null) {
      return Theme.of(context).colorScheme.primary;
    }
    if (reminderDate.isBefore(DateTime.now())) {
      return const Color(0xFFB91C1C);
    }
    if (DateUtils.isSameDay(reminderDate, DateTime.now())) {
      return const Color(0xFFF57C00);
    }
    return const Color(0xFF0F766E);
  }

  Widget _buildReminderBanner(BuildContext context) {
    if (_reminderDate == null) {
      return const SizedBox.shrink();
    }

    final color = _reminderColor(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reminder: ${_formatReminderDate(_reminderDate!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _handleReminderChanged(null),
            child: const Text('解除'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveStateIndicator() {
    return AnimatedBuilder(
      animation: _autoSaveService,
      builder: (context, _) {
        final state = _autoSaveService.saveState;
        final lastSaved = _autoSaveService.lastSavedTime;
        switch (state) {
          case SaveState.saved:
            final suffix =
                lastSaved != null ? '  最終保存 ${_formatTime(lastSaved)}' : '';
            return Text(
              '保存済み$suffix',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0D9488),
                height: 1.5,
              ),
            );
          case SaveState.saving:
            return const Text(
              '保存中...',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6366F1),
                height: 1.5,
              ),
            );
          case SaveState.modified:
            return const Text(
              '未保存の変更があります',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFFF6B35),
                height: 1.5,
              ),
            );
          case SaveState.error:
            return const Text(
              '保存に失敗しました',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFB91C1C),
                height: 1.5,
              ),
            );
        }
      },
    );
  }

  Widget _buildSlashCommandChip(String command) {
    return ActionChip(
      label: Text(command),
      onPressed:
          _isRunningSlashCommand ? null : () => _prefillSlashCommand(command),
    );
  }

  Widget _buildAiStyleChip(NoteEditorAiStyle style) {
    return ChoiceChip(
      key: Key('note_editor_ai_style_${style.commandValue}'),
      label: Text(style.label),
      selected: _selectedAiStyle == style,
      onSelected: _isRunningSlashCommand
          ? null
          : (selected) {
              if (selected) {
                _setAiStyle(style);
              }
            },
    );
  }

  Widget _buildPreferredModelChip() {
    final model = _selectedAiModel;
    if (model == null || model.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const Key('note_editor_selected_ai_model_chip'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory_rounded, size: 14),
          const SizedBox(width: 6),
          Text(
            '既定のモデル: $model',
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptTemplateChip(
    NotePromptTemplate template, {
    bool deletable = false,
  }) {
    final key = Key('note_editor_prompt_template_chip_${template.id}');
    if (deletable) {
      return InputChip(
        key: key,
        label: Text(template.title),
        onPressed:
            _isRunningSlashCommand ? null : () => _runPromptTemplate(template),
        onDeleted: _isRunningSlashCommand
            ? null
            : () => _deletePromptTemplate(template),
      );
    }
    return ActionChip(
      key: key,
      label: Text(template.title),
      onPressed:
          _isRunningSlashCommand ? null : () => _runPromptTemplate(template),
    );
  }

  Widget _buildPromptWorkbenchSection(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('note_editor_prompt_library_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.auto_fix_high_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            'Claude Workbench-style prompts',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Save prompts you want to test repeatedly, then rerun them against the current note.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('note_editor_prompt_library_add_button'),
                onPressed:
                    _isRunningSlashCommand ? null : _showPromptTemplateDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Prompt'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Built-in prompts',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _builtInPromptTemplates
                          .map(_buildPromptTemplateChip)
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Saved prompts',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_savedPromptTemplates.isEmpty)
                      Text(
                        'No saved prompts yet. Create one with variables like {{note_content}}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _savedPromptTemplates
                            .map(
                              (template) => _buildPromptTemplateChip(
                                template,
                                deletable: true,
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlashCommandBar(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.16);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final isExpanded = _isSlashCommandBarExpanded ?? !isNarrow;

    return Container(
      key: const Key('note_editor_slash_command_bar'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: isExpanded ? 240.0 : 64.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.terminal_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'スラッシュコマンド',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('note_editor_slash_command_toggle'),
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () {
                      final next = !isExpanded;
                      setState(() {
                        _isSlashCommandBarExpanded = next;
                      });
                      unawaited(_persistSlashBarExpanded(next));
                    },
                    tooltip: isExpanded ? '折りたたむ' : '展開する',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('note_editor_slash_command_field'),
                  controller: _slashCommandController,
                  enabled: !_isRunningSlashCommand,
                  onSubmitted: (_) => _runSlashCommand(),
                  decoration: InputDecoration(
                    hintText: '/summarize や /favorite を試す',
                    prefixIcon: const Icon(Icons.code_rounded),
                    suffixIcon: _isRunningSlashCommand
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            key: const Key(
                              'note_editor_slash_command_run_button',
                            ),
                            onPressed: _runSlashCommand,
                            icon: const Icon(Icons.play_arrow_rounded),
                            tooltip: 'コマンドを実行',
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter キーか再生ボタンでコマンドを実行します。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedAiModel != null &&
                    _selectedAiModel!.isNotEmpty) ...[
                  _buildPreferredModelChip(),
                  const SizedBox(height: 8),
                ],
                Text(
                  '文章のトーン',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: NoteEditorAiStyle.values
                      .map(_buildAiStyleChip)
                      .toList(growable: false),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedAiStyle.helperText,
                  key: const Key('note_editor_ai_style_helper'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPromptWorkbenchSection(context),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _slashCommandSuggestions
                      .map(_buildSlashCommandChip)
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorSurface() {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final outerPadding =
        isNarrow ? const EdgeInsets.all(8.0) : const EdgeInsets.all(16.0);
    final titleFontSize = isNarrow ? 20.0 : 24.0;
    final String attachLabel;
    if (_isUploadingAttachment) {
      attachLabel = isNarrow ? '追加中...' : '画像を追加中...';
    } else {
      attachLabel = isNarrow ? '画像' : '画像を追加';
    }
    final String previewLabel;
    if (_showMarkdownPreview) {
      previewLabel = isNarrow ? '編集' : '編集に戻る';
    } else {
      previewLabel = 'プレビュー';
    }

    return Stack(
      children: [
        Padding(
          padding: outerPadding,
          child: Column(
            children: [
              _buildReminderBanner(context),
              _buildSlashCommandBar(context),
              TextField(
                key: const Key('note_editor_title_field'),
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'タイトル',
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const Divider(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isUploadingAttachment
                        ? null
                        : _insertAttachmentFromPicker,
                    icon: _isUploadingAttachment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(attachLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showMarkdownPreview = !_showMarkdownPreview;
                      });
                    },
                    icon: Icon(
                      _showMarkdownPreview
                          ? Icons.edit_note_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(previewLabel),
                  ),
                  OutlinedButton.icon(
                    key: const Key('note_editor_tags_button'),
                    onPressed: _showTagsEditor,
                    icon: const Icon(Icons.sell_outlined),
                    label: Text(isNarrow ? 'タグ' : 'タグ (${_tags.length})'),
                  ),
                  if (_currentNoteId != null)
                    OutlinedButton.icon(
                      key: const Key('note_editor_tasks_button'),
                      onPressed: _showTasksPanel,
                      icon: const Icon(Icons.checklist_rtl_outlined),
                      label: Text(isNarrow ? 'タスク' : 'タスクを管理'),
                    ),
                ],
              ),
              if (!isNarrow) ...[
                const SizedBox(height: 8),
                Text(
                  'Ctrl+V / Cmd+V で画像を貼り付け、または画像ファイルをドラッグ&ドロップすると自動でアップロードします。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_isLoadingAttachments) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                AttachmentListWidget(
                  attachments: _attachments,
                  onDelete: _deleteAttachment,
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: NoteImageDropZone(
                  onImageDropped: (bytes, fileName, mimeType) =>
                      _handlePastedImage(
                    Uint8List.fromList(bytes),
                    fileName,
                    mimeType,
                  ),
                  child: _showMarkdownPreview
                      ? ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _contentController,
                          builder: (context, value, _) {
                            if (value.text.trim().isEmpty) {
                              return Center(
                                child: Text(
                                  '本文や画像を追加すると、ここにプレビューが表示されます。',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return SingleChildScrollView(
                              child: MarkdownPreview(data: value.text),
                            );
                          },
                        )
                      : TextField(
                          key: const Key('note_editor_content_field'),
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Write your note here...',
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          expands: true,
                        ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AiAssistantMenu(
            contentController: _contentController,
            onApply: (text) => _contentController.text = text,
            model: _selectedAiModel,
            styleName: _selectedAiStyle.instruction == null
                ? null
                : _selectedAiStyle.commandValue,
            styleInstruction: _selectedAiStyle.instruction,
          ),
        ),
      ],
    );
  }

  Widget _buildEditorBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactRelatedNotes = constraints.maxHeight < 620;
        return Column(
          children: [
            Expanded(child: _buildEditorSurface()),
            if (_currentNoteId != null)
              RelatedNotesStrip(
                notes: _relatedNotes,
                isLoading: _isLoadingRelatedNotes,
                hasError: _relatedNotesHasError,
                compact: compactRelatedNotes,
                onRetry: () => unawaited(_loadRelatedNotes()),
                onNoteTap: (note) => unawaited(_openRelatedNote(note)),
              ),
          ],
        );
      },
    );
  }

  /// デバウンス待ち (入力後 2 秒以内) にエディタを閉じると、`dispose()` で
  /// タイマーが破棄され未保存の編集がサーバーに届かない。破棄前に確定値を
  /// 取り出して投げ切る (State には触れないので dispose 後も安全)。
  void _flushPendingSaveOnExit() {
    final noteId = _currentNoteId;
    if (noteId == null) return; // 新規メモはローカル下書きで復元される
    if (!_hasServerBaseline) return; // 読み込み失敗時は空内容で潰さない

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final reminderIso = _reminderDate?.toUtc().toIso8601String();
    final isFavorite = _isFavorite;
    final tags = NoteTagService.normalize(_tags);
    if (_matchesPersistedState(
      title: title,
      content: content,
      reminderIso: reminderIso,
      isFavorite: isFavorite,
      tags: tags,
    )) {
      return;
    }

    unawaited(
      _supabase
          .from('notes')
          .update({
            'title': title,
            'content': content,
            'reminder_date': reminderIso,
            'is_favorite': isFavorite,
            'tags': tags,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId)
          .catchError((Object _) {
            // 閉じた後なので UI 通知はできない。ローカル下書きが残るため
            // 次回このメモを開いたときに復元される。
          }),
    );
  }

  @override
  void dispose() {
    _flushPendingSaveOnExit();
    _imagePasteRegistration?.dispose();
    _contentFocusNode.dispose();
    _detachTextListeners();
    _autoSaveService.dispose();
    _undoRedoService.dispose();
    _slashCommandController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _currentNoteId != null;

    return Scaffold(
      key: const Key('note_editor_page_scaffold'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? 'メモを編集' : '新しいメモ'),
            _buildSaveStateIndicator(),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: _undoRedoService,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoRedoService.canUndo ? _undo : null,
              tooltip: '元に戻す (Ctrl+Z)',
            ),
          ),
          AnimatedBuilder(
            animation: _undoRedoService,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _undoRedoService.canRedo ? _redo : null,
              tooltip: 'やり直し (Ctrl+Y / Ctrl+Shift+Z)',
            ),
          ),
          IconButton(
            key: const Key('note_editor_page_favorite_button'),
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            color: _isFavorite ? const Color(0xFFFF6B35) : null,
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'お気に入り解除' : 'お気に入りに追加',
          ),
          IconButton(
            icon: Icon(
              _reminderDate == null
                  ? Icons.alarm_add_outlined
                  : Icons.alarm_on_outlined,
            ),
            onPressed: () => showReminderDialog(
              context: context,
              currentReminder: _reminderDate,
              onReminderSet: _handleReminderChanged,
            ),
            tooltip: 'リマインダー',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveManually,
            tooltip: '保存',
          ),
          if (_currentNoteId != null)
            IconButton(
              icon: const Icon(Icons.public),
              onPressed: _publishNote,
              tooltip: '公開する',
            ),
          if (_currentNoteId != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showVersionHistory,
              tooltip: 'バージョン履歴',
            ),
          if (_currentNoteId != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: _showComments,
                  tooltip: 'コメント',
                ),
                if (_commentCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$_commentCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                    _UndoIntent(),
                SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                    _UndoIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                  shift: true,
                ): _RedoIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                  shift: true,
                ): _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyY, control: true):
                    _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyY, meta: true):
                    _RedoIntent(),
                SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _SaveIntent(),
                SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _SaveIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _UndoIntent: CallbackAction<_UndoIntent>(
                    onInvoke: (_) {
                      _undo();
                      return null;
                    },
                  ),
                  _RedoIntent: CallbackAction<_RedoIntent>(
                    onInvoke: (_) {
                      _redo();
                      return null;
                    },
                  ),
                  _SaveIntent: CallbackAction<_SaveIntent>(
                    onInvoke: (_) {
                      _saveManually();
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: _buildEditorBody(),
                ),
              ),
            ),
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
