import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/diet_debate_notes.dart';
import '../services/diet_debate_search.dart';
import '../services/diet_reader_preferences.dart';
import '../widgets/diet_debate_article.dart';

class DietDebatesPage extends StatefulWidget {
  const DietDebatesPage(
      {super.key, this.searchService, this.account, this.preferences,});
  final DietDebateSearch? searchService;
  @visibleForTesting
  final ValueListenable<String?>? account;
  final DietReaderPreferences? preferences;

  @override
  State<DietDebatesPage> createState() => _DietDebatesPageState();
}

class _DietDebatesPageState extends State<DietDebatesPage> {
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;
  String? _owner;
  int _epoch = 0;

  String? _currentOwner() {
    if (widget.account != null) return widget.account!.value;
    final user = _client?.auth.currentUser;
    return user == null || user.isAnonymous ? null : user.id;
  }

  void _refreshOwner() => _switchTo(_currentOwner());

  void _switchTo(String? next) {
    if (!mounted || next == _owner) return;
    setState(() {
      _owner = next;
      _epoch++;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      widget.account!.addListener(_refreshOwner);
    } else {
      try {
        _client = Supabase.instance.client;
        _authSubscription = _client!.auth.onAuthStateChange.listen(
          (event) {
            final user = event.session?.user;
            _switchTo(user == null || user.isAnonymous ? null : user.id);
          },
          onError: (Object error, StackTrace stack) => _switchTo(null),
        );
      } catch (_) {
        _client = null;
      }
    }
    _owner = _currentOwner();
  }

  @override
  void dispose() {
    _epoch++;
    widget.account?.removeListener(_refreshOwner);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _epoch;
    final owner = _owner;
    return _DietReader(
      key: ValueKey(generation),
      owner: owner,
      searchService: widget.searchService,
      preferences: widget.preferences ?? DietReaderPreferences.shared,
      ownsReadState: () =>
          mounted &&
          generation == _epoch &&
          owner != null &&
          owner == _currentOwner(),
    );
  }
}

class _DietReader extends StatefulWidget {
  const _DietReader(
      {super.key,
      required this.owner,
      required this.ownsReadState,
      required this.searchService,
      required this.preferences,});
  final String? owner;
  final bool Function() ownsReadState;
  final DietDebateSearch? searchService;
  final DietReaderPreferences preferences;

  @override
  State<_DietReader> createState() => _DietReaderState();
}

class _DietReaderState extends State<_DietReader> {
  final _term = TextEditingController();
  final _speaker = TextEditingController();
  final _group = TextEditingController();
  final _withinPage = TextEditingController();
  bool _preferencesReady = false;
  final _read = <String>{};
  final _uncertainRead = <String>{};
  bool _fontSizeUncertain = false;
  final _saving = <String>{};
  bool _readUnavailable = false;
  bool _savingSize = false;
  DateTime? _date;
  bool _loading = false;
  double _fontSize = 16;
  bool _bySpeaker = false;
  String? _error;
  String _searched = '';
  DietSearchPage? _result;
  int _start = 1;
  ({String term, String speaker, String group, String date})? _lastQuery;

  @override
  void initState() {
    super.initState();
    _restoreRead();
  }

  Future<void> _restoreRead() async {
    try {
      final settings = await widget.preferences
          .load(widget.ownsReadState() ? widget.owner : null);
      if (!mounted) return;
      setState(() {
        _preferencesReady = true;
        _fontSize = settings.fontSize;
        _fontSizeUncertain = settings.fontSizeUncertain;
        if (widget.ownsReadState()) {
          _read.addAll(settings.readIds);
          _uncertainRead.addAll(settings.uncertainReadIds);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _readUnavailable = true);
    }
  }

  void _retrySettings() {
    if (!_readUnavailable) return;
    setState(() => _readUnavailable = false);
    _restoreRead();
  }

  Future<void> _setRead(String id, bool mark) async {
    final owner = widget.owner;
    if (owner == null ||
        !_preferencesReady ||
        !widget.ownsReadState() ||
        _saving.contains(id)) {
      return;
    }
    setState(() => _saving.add(id));
    try {
      await widget.preferences.setRead(owner, id, mark);
      if (mounted && widget.ownsReadState()) {
        setState(() {
          _uncertainRead.remove(id);
          if (mark) {
            _read.add(id);
          } else {
            _read.remove(id);
          }
        });
      }
    } catch (_) {
      if (mounted && widget.ownsReadState()) {
        setState(() => _uncertainRead.add(id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('端末への保存結果を確認できません。既読か未読かを選び直せます。')),
        );
      }
    } finally {
      if (mounted && widget.ownsReadState()) setState(() => _saving.remove(id));
    }
  }

  Widget _readButton(String id, String kind) {
    if (!widget.ownsReadState()) return Text('$kindの既読保存はログイン後に利用できます');
    final read = _read.contains(id);
    if (!_preferencesReady) {
      return Text(_readUnavailable ? '既読状態を利用できません' : '既読状態を読み込み中');
    }
    if (_uncertainRead.contains(id)) {
      return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('$kindの既読保存状態は不明です。'),
        TextButton(
            onPressed: _saving.contains(id) ? null : () => _setRead(id, true),
            child: const Text('既読に設定'),),
        TextButton(
            onPressed: _saving.contains(id) ? null : () => _setRead(id, false),
            child: const Text('未読に設定'),),
      ],);
    }
    return TextButton.icon(
      onPressed: _saving.contains(id) ? null : () => _setRead(id, !read),
      icon: Icon(read ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,),
      label: Text(read ? '$kindは既読・未読に戻す' : '$kindを既読にする'),
    );
  }

  Future<void> _setFontSize(double size) async {
    if (!_preferencesReady || _savingSize) return;
    setState(() {
      _fontSize = size;
      _savingSize = true;
    });
    try {
      await widget.preferences.setFontSize(size);
      if (mounted) setState(() => _fontSizeUncertain = false);
    } catch (_) {
      if (mounted) {
        setState(() => _fontSizeUncertain = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字サイズを変更しました。端末への保存結果は不明です。')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSize = false);
    }
  }

  @override
  void dispose() {
    _term.dispose();
    _speaker.dispose();
    _group.dispose();
    _withinPage.dispose();
    super.dispose();
  }

  String _iso(DateTime date) => date.toIso8601String().substring(0, 10);

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(1947, 5),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _search({int start = 1, bool paging = false}) async {
    if (_loading) return;
    final query = paging
        ? _lastQuery!
        : (
            term: _term.text.trim(),
            speaker: _speaker.text.trim(),
            group: _group.text.trim(),
            date: _date == null ? '' : _iso(_date!)
          );
    setState(() {
      _loading = true;
      _error = null;
      if (!paging) {
        _withinPage.clear();
        _result = null;
        _lastQuery = null;
      }
    });
    try {
      final service = widget.searchService ?? DietDebateSearch.shared;
      final page = await service.search(
        term: query.term,
        speaker: query.speaker,
        group: query.group,
        date: query.date,
        start: start,
      );
      if (!mounted) return;
      setState(() {
        _result = page;
        _start = start;
        _lastQuery = query;
        _searched = [query.term, query.speaker, query.group, query.date]
            .where((value) => value.isNotEmpty)
            .join(' / ');
      });
    } on DietSearchError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '接続またはデータの読み取りに失敗しました。時間をおいて再度検索してください。');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A platform may lack a browser handler.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出典を開けませんでした。')),
      );
    }
  }

  Widget _source(String label, Uri uri) => TextButton.icon(
        onPressed: () => _open(uri),
        icon: const Icon(Icons.open_in_new, size: 17),
        label: Text(label),
      );

  Widget _body(String text) =>
      Text(text, style: TextStyle(fontSize: _fontSize, height: 1.6));

  Widget _note(DietDebateNote note) => DietDebateArticle(
        key: ValueKey(note.articleId),
        note: note,
        fontSize: _fontSize,
        source: _source,
        readButton: _readButton('note:${note.articleId}', '要約'),
      );

  Widget _groupControl({required bool includesRespondents}) => Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
              label: const Text('テーマ別'),
              selected: !_bySpeaker,
              onSelected: (_) => setState(() => _bySpeaker = false),),
          ChoiceChip(
              label: Text(includesRespondents ? '議員・答弁者別' : '質問した議員別'),
              selected: _bySpeaker,
              onSelected: (_) => setState(() => _bySpeaker = true),),
        ],
      );

  Widget _reader() {
    final groups = <String, List<DietDebateNote>>{};
    for (final note in DietDebateNote.entries) {
      final label = _bySpeaker ? note.questioner : note.topic;
      groups.putIfAbsent(label, () => []).add(note);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _body('収録した2つの質疑を、質問と答弁に分けて読めます。'),
        _groupControl(includesRespondents: false),
        for (final entry in groups.entries) ...[
          Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
          for (final note in entry.value) _note(note),
        ],
        const Divider(),
        Text('法案メモ', style: Theme.of(context).textTheme.titleLarge),
        _body('第211回国会・閣法第51号　著作権法の一部を改正する法律案'),
        _body('2023年5月16日に参議院文教科学委員会が可決し、翌17日に参議院本会議が可決。5月26日に公布された。'),
        Align(
            alignment: Alignment.centerLeft,
            child: _source('参議院の議案審議情報', DietDebateNote.billUrl),),
      ],
    );
  }

  Widget _searchView() {
    final page = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _body('すべての会派を対象に、国立国会図書館の国会会議録から発言と会議情報を探します。開催から公開まで日数がかかります。'),
        const SizedBox(height: 14),
        TextField(
            controller: _term,
            enabled: !_loading,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: 'テーマ・キーワード',
                hintText: '例　子育て',
                counterText: '',
                border: OutlineInputBorder(),),
            onSubmitted: (_) => _search(),),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final term in DietSpeech.topicWords.keys)
            ActionChip(
                label: Text(term),
                onPressed: _loading ? null : () => _term.text = term,),
        ],),
        const SizedBox(height: 12),
        TextField(
            controller: _speaker,
            enabled: !_loading,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: '議員・答弁者の名前',
                counterText: '',
                border: OutlineInputBorder(),),
            onSubmitted: (_) => _search(),),
        const SizedBox(height: 12),
        TextField(
            controller: _group,
            enabled: !_loading,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: '会議当時の会派名（部分一致）',
                counterText: '',
                border: OutlineInputBorder(),),
            onSubmitted: (_) => _search(),),
        Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
                label: const Text('「国民民主党」を含む会派'),
                onPressed: _loading ? null : () => _group.text = '国民民主党',),),
        const Text('会派は複数の政党や無所属の議員で構成されることがあります。'),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                  onPressed: _loading ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_date == null ? '開催日を選ぶ' : _iso(_date!)),),
              if (_date != null)
                TextButton(
                    onPressed:
                        _loading ? null : () => setState(() => _date = null),
                    child: const Text('日付を外す'),),
              FilledButton.icon(
                  onPressed: _loading ? null : () => _search(),
                  icon: const Icon(Icons.search),
                  label: const Text('会議録を検索'),),
            ],),
        const SizedBox(height: 8),
        const Text('検索条件は国立国会図書館に送信されます。'),
        if (_loading) const LinearProgressIndicator(semanticsLabel: '会議録を検索中'),
        if (_error != null) Semantics(liveRegion: true, child: _body(_error!)),
        if (page != null) ...[
          const Divider(),
          Semantics(
              liveRegion: true,
              child: _body('「$_searched」の会議録API検索結果　${page.total}件'),),
          Text(
              '会議録取得　${DateFormat('yyyy-MM-dd HH:mm:ss').format(page.fetchedAt.toLocal())}（端末時刻）',),
          if (page.skipped > 0) _body('出典を確認できないデータを${page.skipped}件省略しました。'),
          if (page.total > 0)
            Text(
                'API取得開始位置　$_start件目／このページで出典を確認できた記録　${page.items.length}件',),
          if (page.total == 0)
            _body(
                '検索条件に一致する公開済みの会議録は見つかりませんでした。未収録の発言は検索結果に含まれません。開催日を外すか、検索語を変えてお試しください。',)
          else if (page.items.isNotEmpty) ...[
            const Text('以下の分類と絞り込みは、取得済みのこのページ内のみが対象です。'),
            _groupControl(includesRespondents: true),
            if (!_bySpeaker)
              const Text('テーマは発言中の語句で分類します。同じ記録が複数のテーマに入ることがあります。'),
            TextField(
                controller: _withinPage,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'このページの表示項目を検索',
                    hintText: '発言者・会派・会議名・収録した要約',
                    border: OutlineInputBorder(),),),
            ..._groupedResults(page.items),
          ],
          Wrap(spacing: 12, children: [
            if (_start > 1)
              OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _search(start: _start - 10, paging: true),
                  child: const Text('前の10件'),),
            if (page.next != null)
              OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _search(start: page.next!, paging: true),
                  child: const Text('次の10件'),),
          ],),
        ],
      ],
    );
  }

  List<Widget> _groupedResults(List<DietSpeech> items) {
    final filter = _withinPage.text.trim().toLowerCase();
    final groups = <String, List<DietSpeech>>{};
    for (final speech in items) {
      final note = DietDebateNote.forSpeech(speech.id);
      final searchable = [
        speech.date,
        speech.house,
        speech.meeting,
        speech.speaker,
        speech.group ?? '',
        ...speech.topics,
        if (note != null) ...[
          note.topic,
          note.questioner,
          note.answerer,
          note.question,
          note.answer,
        ],
      ];
      if (!searchable.any((value) => value.toLowerCase().contains(filter))) {
        continue;
      }
      final labels = speech.isMeetingInformation
          ? ['会議情報']
          : _bySpeaker
              ? [speech.speaker]
              : speech.topics.isEmpty
                  ? ['テーマ未分類']
                  : speech.topics;
      for (final label in labels) {
        groups.putIfAbsent(label, () => []).add(speech);
      }
    }
    if (groups.isEmpty) return [_body('このページ内に一致する記録はありません。')];
    return [
      for (final entry in groups.entries) ...[
        Text('${entry.key}（${entry.value.length}件）',
            style: Theme.of(context).textTheme.titleMedium,),
        for (final speech in entry.value) _speech(speech, entry.key),
      ],
    ];
  }

  Widget _speech(DietSpeech speech, String section) {
    final note = DietDebateNote.forSpeech(speech.id);
    return Card(
        key: ValueKey((section, speech.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _body(speech.isMeetingInformation ? '会議情報' : speech.speaker),
            Text('${speech.date}　${speech.house}　${speech.meeting}'),
            if (speech.group?.isNotEmpty ?? false)
              Text('会議当時の会派　${speech.group}'),
            _source(
                speech.isMeetingInformation ? '会議情報の原文' : '発言の原文', speech.url,),
            _readButton('speech:${speech.id}',
                speech.isMeetingInformation ? '会議情報' : '発言',),
            if (note != null)
              ExpansionTile(
                  title: Text(note.topic),
                  subtitle: const Text('質疑の要約を読む'),
                  children: [_note(note)],),
          ],),
        ),);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('国会の質疑を読む'),
            actions: [
              PopupMenuButton<double>(
                icon: const Icon(Icons.format_size),
                tooltip: '本文の文字サイズ',
                initialValue: _fontSize,
                enabled: _preferencesReady && !_savingSize,
                onSelected: _setFontSize,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 16, child: Text('標準')),
                  PopupMenuItem(value: 20, child: Text('大')),
                  PopupMenuItem(value: 24, child: Text('特大')),
                ],
              ),
            ],
            bottom:
                const TabBar(tabs: [Tab(text: '会議録を検索'), Tab(text: '要約・法案メモ')]),
          ),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _storageStatus(),),
              Expanded(child: TabBarView(children: [_searchView(), _reader()])),
            ],),
          ),),),
        ),
      );

  Widget _storageStatus() {
    if (_readUnavailable) {
      return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('端末設定を読み込めませんでした。文字サイズと既読の変更には再読み込みが必要です。'),
        TextButton(onPressed: _retrySettings, child: const Text('設定を読み直す')),
      ],);
    }
    if (!_preferencesReady || _saving.isNotEmpty || _savingSize) {
      return Semantics(
          liveRegion: true,
          child: Text(_preferencesReady
              ? '端末への保存中です。応答を待つ間も会議録を閲覧できます。'
              : '端末設定の読み込み待ちです。先に開始した保存があれば、その応答を待ちます。',),);
    }
    if (_fontSizeUncertain) {
      return const Text('文字サイズの保存状態は不明です。上の文字サイズメニューで選び直せます。');
    }
    return const Text('既読はログイン利用者別、文字サイズは端末共通です。別タブへの即時反映はありません。');
  }
}
