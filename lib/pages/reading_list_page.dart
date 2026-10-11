import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../data/catalogs/philosophy_catalog.dart';
import '../data/repositories/reading_repository.dart';
import '../domain/models/philosophy_reading.dart';
import '../ui/features/reading/view_models/reading_view_model.dart';

class ReadingListPage extends StatefulWidget {
  const ReadingListPage({super.key, this.repository});
  final ReadingRepository? repository;
  @override
  State<ReadingListPage> createState() => _ReadingListPageState();
}

class _ReadingListPageState extends State<ReadingListPage>
    with SingleTickerProviderStateMixin {
  late final ReadingViewModel _model;
  late final TabController _tabs;
  String _query = '';
  String? _century;
  String? _region;
  String? _genre;
  String? _author;
  int _filterEpoch = 0;

  @override
  void initState() {
    super.initState();
    _model = ReadingViewModel(
      widget.repository ?? SupabaseReadingRepository(Supabase.instance.client),
    );
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() => _filterEpoch++);
    });
    _model.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _model.dispose();
    super.dispose();
  }

  ReadingFilter get _filter => ReadingFilter(
        query: _query,
        century: _century,
        region: _region,
        genre: _genre,
        authorId: _author,
      );
  List<PhilosophyWork> get _filteredWorks =>
      _model.works.where(_filter.matches).toList();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _model,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('哲学書の読書管理'),
            actions: [
              IconButton(
                tooltip: '再読込',
                onPressed: _model.saving ? null : _model.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: '著者'),
                Tab(text: '著作'),
                Tab(text: '進捗'),
              ],
            ),
          ),
          body: Column(
            children: [
              if (!_model.signedIn)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('目録は閲覧できます。記録にはログインが必要です。'),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: const Text('ログイン'),
                      ),
                    ],
                  ),
                ),
              if (_model.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _model.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_model.loading || _model.saving)
                const LinearProgressIndicator(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [_authorList(), _workList(), _progress()],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _filters({bool authors = false}) {
    final centuries = (authors
            ? _model.authors.expand((a) => a.centuries)
            : _model.works.expand((w) => w.centuries))
        .toSet()
        .toList()
      ..sort();
    final regions = _model.authors.expand((a) => a.regions).toSet().toList()
      ..sort();
    final genres = _model.works.expand((w) => w.genres).toSet().toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          TextFormField(
            key: ValueKey('search-$authors-$_author-$_filterEpoch'),
            initialValue: _query,
            decoration: const InputDecoration(
              labelText: '著者・著作を検索',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterChoice(
                authors ? '活動世紀' : '成立世紀',
                _century,
                centuries,
                (v) => setState(() => _century = v),
              ),
              _filterChoice(
                '国／地域',
                _region,
                regions,
                (v) => setState(() => _region = v),
              ),
              _filterChoice(
                'ジャンル',
                _genre,
                genres,
                (v) => setState(() => _genre = v),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _query = '';
                  _century = null;
                  _region = null;
                  _genre = null;
                  _author = null;
                  _filterEpoch++;
                }),
                child: const Text('分類を解除'),
              ),
            ],
          ),
          if (_author != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _author = null),
                child: const Text('すべての著者に戻る'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChoice(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> changed,
  ) =>
      SizedBox(
        width: 140,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label-$value'),
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('すべて')),
            ...items.map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => changed(v == '' ? null : v),
        ),
      );

  Widget _authorList() {
    final authors = _model.authors
        .where(
          (a) =>
              _filter.authorMatches(a) &&
              (_genre == null ||
                  _model.works.any(
                    (w) => w.author.id == a.id && w.genres.contains(_genre),
                  )),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _filters(authors: true),
        const Text('活動世紀・国／地域から著者を探し、著作へ進めます。目録は順次拡充します。'),
        if (_model.signedIn)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _model.saving || _model.loading ? null : _addAuthor,
              icon: const Icon(Icons.person_add),
              label: const Text('著者を追加'),
            ),
          ),
        if (authors.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('条件に一致する著者はいません'),
          ),
        ...authors.map((a) {
          final progress =
              _model.progress(_model.works.where((w) => w.author.id == a.id));
          return Card(
            child: ListTile(
              title: Text(a.name),
              subtitle: Text(
                '${a.centuries.join('・')} / ${a.regions.join('・')}\n${a.traditions.join('・')}\n${progress.total == 0 ? '著作を調査中' : '収録 ${progress.total} 著作 / 読了 ${progress.completed} 著作'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _author = a.id;
                  _query = '';
                  _century = null;
                });
                _tabs.animateTo(1);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _workList() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filters(),
          Text('収録済み ${_model.works.length} 著作。版のページ数は読書開始時に登録します。'),
          if (_model.signedIn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _model.saving || _model.loading ? null : _addWork,
                icon: const Icon(Icons.add),
                label: const Text('著作を追加'),
              ),
            ),
          if (_filteredWorks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('条件に一致する著作はありません'),
            ),
          ..._filteredWorks.map(
            (work) => Card(
              child: ListTile(
                title: Text(work.title),
                subtitle: Text(
                  '${work.author.name}\n${work.centuries.join('・')} / ${work.genres.join('・')}',
                ),
                trailing: Text(
                  readingStatusLabels[
                          _model.recordFor(work.id)?.status ?? 'unread'] ??
                      '未読',
                ),
                onTap: () => _openWork(work),
              ),
            ),
          ),
        ],
      );

  Widget _progress() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '長期目標: すべての哲学書を読破する',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
              '目録 $philosophyCatalogVersion・順次拡充。世界の全哲学書に対する網羅率ではありません。',),
          _progressCard('収録済み著作全体', _model.progress(_model.works)),
          _filters(),
          _progressCard('現在の検索・分類対象', _model.progress(_filteredWorks)),
          const Text('分類別の読了数（複数分類の著作は各分類に含まれます）'),
          ..._groupProgress('成立世紀', (w) => w.centuries),
          ..._groupProgress('国／地域', (w) => w.author.regions),
          ..._groupProgress(
              'ジャンル', (w) => w.genres.isEmpty ? ['不明'] : w.genres,),
        ],
      );

  Widget _progressCard(String label, ReadingProgress progress) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(
                '読了 ${progress.completed} / ${progress.total} 著作${progress.total == 0 ? '（対象なし）' : ''}',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 8),
              Text('延べ読書量 ${progress.pages} ページ（再読を含む）'),
            ],
          ),
        ),
      );

  List<Widget> _groupProgress(
    String label,
    List<String> Function(PhilosophyWork) classify,
  ) {
    final groups = _filteredWorks.expand(classify).toSet().toList()..sort();
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      ...groups.map((name) {
        final progress = _model
            .progress(_filteredWorks.where((w) => classify(w).contains(name)));
        return ListTile(
          title: Text(name),
          trailing: Text('${progress.completed} / ${progress.total}'),
        );
      }),
    ];
  }

  Future<void> _source(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' || !await launchUrl(uri)) {
        throw StateError('unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('出典を開けませんでした')));
      }
    }
  }

  List<String> _tags(String value) => value
      .split(RegExp(r'[,;、]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _addAuthor() async {
    final id = const Uuid().v4();
    await _form('著者を追加（自分の目録）', [
      const _Field('name', '著者名', required: true),
      const _Field('aliases', '別名（カンマ区切り）'),
      const _Field('centuries', '活動世紀（例: 19世紀,20世紀）', initial: '不明'),
      const _Field('regions', '国／地域（カンマ区切り）', initial: '不明'),
      const _Field('traditions', '思想の伝統（カンマ区切り）'),
      const _Field('source', '出典URL（HTTPS）'),
      const _Field('note', '帰属・年代に関する注記', lines: 3),
    ], (values) async {
      if (values['source']!.isNotEmpty &&
          !values['source']!.startsWith('https://')) {
        return '出典URLはHTTPSで入力してください';
      }
      final author = PhilosophyAuthor(
        id: 'private:$id',
        name: values['name']!,
        aliases: _tags(values['aliases']!),
        centuries: _tags(values['centuries']!).isEmpty
            ? ['不明']
            : _tags(values['centuries']!),
        regions: _tags(values['regions']!).isEmpty
            ? ['不明']
            : _tags(values['regions']!),
        traditions: _tags(values['traditions']!),
        source: values['source']!,
        note: values['note']!,
      );
      return await _model.addAuthor(id, author)
          ? null
          : _model.error ?? '保存できませんでした';
    });
  }

  Future<void> _addWork() async {
    final id = const Uuid().v4();
    final choices = {for (final a in _model.authors) a.id: a.name};
    await _form('著作を追加（自分の目録）', [
      const _Field('title', '著作名', required: true),
      _Field(
        'author',
        '著者',
        initial: _author ?? choices.keys.first,
        choices: choices,
      ),
      const _Field('original', '原題'),
      const _Field('centuries', '成立世紀（カンマ区切り）', initial: '不明'),
      const _Field('genres', 'ジャンル（カンマ区切り）'),
      const _Field('source', '出典URL（HTTPS）'),
      const _Field('note', '帰属・成立年の注記', lines: 3),
    ], (values) async {
      if (values['source']!.isNotEmpty &&
          !values['source']!.startsWith('https://')) {
        return '出典URLはHTTPSで入力してください';
      }
      final work = PhilosophyWork(
        id: 'private:$id',
        title: values['title']!,
        author: _model.authors.firstWhere((a) => a.id == values['author']),
        originalTitle: values['original']!,
        centuries: _tags(values['centuries']!).isEmpty
            ? ['不明']
            : _tags(values['centuries']!),
        genres: _tags(values['genres']!),
        source: values['source']!,
        note: values['note']!,
      );
      return await _model.addWork(id, work)
          ? null
          : _model.error ?? '保存できませんでした';
    });
  }

  Future<void> _openWork(PhilosophyWork work) => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AnimatedBuilder(
            animation: _model,
            builder: (context, _) {
              final record = _model.recordFor(work.id);
              return Scaffold(
                appBar: AppBar(
                  title: Text(work.title),
                  actions: [
                    IconButton(
                      tooltip: '再読込',
                      onPressed: _model.saving ? null : _model.load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      work.author.name,
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(work.originalTitle),
                    Text(
                      '${work.centuries.join('・')} / ${work.genres.join('・')}',
                    ),
                    Text(work.author.regions.join('・')),
                    Text(work.note),
                    if (work.source.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _source(work.source),
                          child: const Text('書誌・帰属の出典を開く'),
                        ),
                      ),
                    if (_model.error != null)
                      Text(
                        _model.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (!_model.signedIn) const Text('記録にはログインが必要です'),
                    if (_model.loading || _model.saving)
                      const LinearProgressIndicator(),
                    FilledButton.icon(
                      onPressed:
                          !_model.signedIn || _model.saving || _model.loading
                              ? null
                              : () => _start(work),
                      icon: const Icon(Icons.menu_book),
                      label: Text(
                        record == null || record.cycles.isEmpty
                            ? '読書を始める'
                            : '別の版・再読を始める',
                      ),
                    ),
                    if (record != null && record.cycles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '既存の状態: ${readingStatusLabels[record.legacyStatus] ?? '未読'}。履歴は新しい読書回から記録できます。',
                        ),
                      ),
                    if (record != null)
                      ...record.cycles.indexed.map(
                        (item) => _cycle(record, item.$2, item.$1 + 1),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );

  List<_Field> _editionFields(ReadingEdition edition) => [
        _Field(
          'total',
          '総ページ数（不明なら空欄）',
          initial: edition.totalPages?.toString() ?? '',
          number: true,
        ),
        _Field('translator', '訳者', initial: edition.translator),
        _Field('publisher', '出版社', initial: edition.publisher),
        _Field('year', '出版年', initial: edition.year),
        _Field('language', '言語', initial: edition.language),
        _Field('isbn', 'ISBN（任意）', initial: edition.isbn),
        _Field('volume', '巻・版の名前', initial: edition.volume),
      ];
  ReadingEdition _edition(Map<String, String> values) => ReadingEdition(
        totalPages: int.tryParse(values['total']!),
        translator: values['translator']!,
        publisher: values['publisher']!,
        year: values['year']!,
        language: values['language']!,
        isbn: values['isbn']!,
        volume: values['volume']!,
      );

  Future<void> _start(PhilosophyWork work) async {
    final recordId = const Uuid().v4();
    final cycleId = const Uuid().v4();
    await _form('読む版を登録', _editionFields(const ReadingEdition()),
        (values) async {
      if (values['total']!.isNotEmpty && int.parse(values['total']!) < 1) {
        return '総ページ数は1以上です';
      }
      if (_model.recordFor(work.id) == null) {
        if (!await _model.addWork(recordId, work)) {
          return _model.error ?? '保存できませんでした';
        }
      }
      final record = _model.recordFor(work.id);
      if (record == null) {
        return '記録を再読込してから保存してください';
      }
      final cycle = ReadingCycle(
        id: cycleId,
        startedAt: DateTime.now().toIso8601String().substring(0, 10),
        edition: _edition(values),
      );
      return await _model.save(
        record.withCycles(
          [...record.cycles.where((c) => c.id != cycleId), cycle],
        ),
      )
          ? null
          : _model.error ?? '保存できませんでした';
    });
  }

  Future<bool> _replaceCycle(ReadingRecord record, ReadingCycle cycle) =>
      _model.save(
        record.withCycles(
          record.cycles.map((c) => c.id == cycle.id ? cycle : c).toList(),
        ),
      );

  Widget _cycle(ReadingRecord record, ReadingCycle cycle, int number) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '第$number回 ${cycle.startedAt}〜${cycle.finishedAt ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${cycle.edition.volume} ${cycle.edition.publisher} ${cycle.edition.translator} ${cycle.edition.language}',
              ),
              Text(
                '出版年: ${cycle.edition.year.isEmpty ? '不明' : cycle.edition.year} / ISBN: ${cycle.edition.isbn.isEmpty ? '未登録' : cycle.edition.isbn}',
              ),
              Text(
                '延べ ${cycle.pagesRead} ページ / 区間記録済み ${cycle.coveredPages} / 総 ${cycle.edition.totalPages?.toString() ?? '不明'} ページ',
              ),
              if (cycle.coverage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    value: cycle.coverage!.clamp(0, 1),
                  ),
                ),
              Text('状態: ${readingStatusLabels[cycle.status]}（読了は手動で設定）'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _model.saving || !_model.signedIn
                        ? null
                        : () => _editEdition(record, cycle),
                    child: const Text('版を編集'),
                  ),
                  TextButton.icon(
                    onPressed: _model.saving || !_model.signedIn
                        ? null
                        : () => _entry(record, cycle),
                    icon: const Icon(Icons.add),
                    label: const Text('記録を追加'),
                  ),
                  ...[
                    'reading',
                    'read',
                    'paused',
                  ].where((s) => s != cycle.status).map(
                        (status) => TextButton(
                          onPressed: _model.saving || !_model.signedIn
                              ? null
                              : () => _replaceCycle(
                                  record, cycle.copyWith(status: status),),
                          child: Text('${readingStatusLabels[status]}にする'),
                        ),
                      ),
                ],
              ),
              ...cycle.entries.map(
                (entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      '${entry.date} / ${entry.pages} ページ${entry.startPage == null ? '' : '（${entry.startPage}〜${entry.endPage}）'}',
                    ),
                    Text(
                      entry.understanding == null
                          ? '理解度: 未評価'
                          : '理解度: ${understandingLabels[entry.understanding]}',
                    ),
                    Text('感想: ${entry.impression}'),
                    Text('疑問: ${entry.questions}'),
                    Text('概念: ${entry.concepts}'),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: _model.saving || !_model.signedIn
                              ? null
                              : () => _entry(record, cycle, entry),
                          child: const Text('記録を編集'),
                        ),
                        TextButton(
                          onPressed: _model.saving || !_model.signedIn
                              ? null
                              : () => _deleteEntry(record, cycle, entry),
                          child: const Text('記録を削除'),
                        ),
                      ],
                    ),
                    if (entry.history.isNotEmpty)
                      ExpansionTile(
                        title: Text('編集前の記録（${entry.history.length}件）'),
                        children: entry.history
                            .map(
                              (snapshot) => ListTile(
                                title: Text(
                                  '${snapshot['date']} / 理解度 ${snapshot['understanding'] ?? '未評価'}',
                                ),
                                subtitle: Text(
                                  '${snapshot['impression'] ?? ''}\n疑問: ${snapshot['questions'] ?? ''}\n概念: ${snapshot['concepts'] ?? ''}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _editEdition(ReadingRecord record, ReadingCycle cycle) async {
    await _form('版を編集', _editionFields(cycle.edition), (values) async {
      if (values['total']!.isNotEmpty && int.parse(values['total']!) < 1) {
        return '総ページ数は1以上です';
      }
      final edition = _edition(values);
      if (cycle.entries
          .any((entry) => entry.validate(edition.totalPages) != null)) {
        return '既存記録と総ページ数が矛盾します。記録を確認してください';
      }
      return await _replaceCycle(record, cycle.copyWith(edition: edition))
          ? null
          : _model.error ?? '保存できませんでした';
    });
  }

  Future<void> _entry(
    ReadingRecord record,
    ReadingCycle cycle, [
    ReadingEntry? previous,
  ]) async {
    final id = previous?.id ?? const Uuid().v4();
    await _form(previous == null ? '読書記録を追加' : '読書記録を編集', [
      _Field(
        'date',
        '読書日 YYYY-MM-DD',
        initial:
            previous?.date ?? DateTime.now().toIso8601String().substring(0, 10),
        required: true,
      ),
      _Field(
        'pages',
        '今回読んだページ数（区間入力時は自動計算）',
        initial: previous?.pages.toString() ?? '',
        number: true,
      ),
      _Field(
        'start',
        '開始ページ（任意）',
        initial: previous?.startPage?.toString() ?? '',
        number: true,
      ),
      _Field(
        'end',
        '終了ページ（任意）',
        initial: previous?.endPage?.toString() ?? '',
        number: true,
      ),
      _Field(
        'understanding',
        '理解度（自己評価）',
        initial: previous?.understanding?.toString() ?? '',
        choices: {
          '': '未評価',
          for (final item in understandingLabels.entries)
            '${item.key}': item.value,
        },
      ),
      _Field(
        'impression',
        '感想（非公開）',
        initial: previous?.impression ?? '',
        lines: 3,
      ),
      _Field('questions', '疑問', initial: previous?.questions ?? '', lines: 3),
      _Field('concepts', '重要な概念', initial: previous?.concepts ?? ''),
    ], (values) async {
      final start = int.tryParse(values['start']!);
      final end = int.tryParse(values['end']!);
      final entry = ReadingEntry(
        id: id,
        date: values['date']!,
        pages: start != null && end != null
            ? end - start + 1
            : int.tryParse(values['pages']!) ?? 0,
        startPage: start,
        endPage: end,
        understanding: int.tryParse(values['understanding']!),
        impression: values['impression']!,
        questions: values['questions']!,
        concepts: values['concepts']!,
        history: previous?.history ?? [],
      );
      final error = entry.validate(cycle.edition.totalPages);
      if (error != null) return error;
      final entries = [...cycle.entries];
      final index = entries.indexWhere((e) => e.id == id);
      if (index < 0) {
        entries.add(entry);
      } else {
        entries[index] = entry;
      }
      return await _replaceCycle(record, cycle.copyWith(entries: entries))
          ? null
          : _model.error ?? '保存できませんでした';
    });
  }

  Future<void> _deleteEntry(
    ReadingRecord record,
    ReadingCycle cycle,
    ReadingEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この読書記録を削除しますか？'),
        content: const Text('感想と編集履歴も削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _replaceCycle(
        record,
        cycle.copyWith(
          entries: cycle.entries.where((e) => e.id != entry.id).toList(),
        ),
      );
    }
  }

  Future<void> _form(
    String title,
    List<_Field> fields,
    Future<String?> Function(Map<String, String>) submit,
  ) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ReadingForm(title: title, fields: fields, submit: submit),
      );
}

class _Field {
  const _Field(
    this.id,
    this.label, {
    this.initial = '',
    this.required = false,
    this.number = false,
    this.lines = 1,
    this.choices,
  });
  final String id;
  final String label;
  final String initial;
  final bool required;
  final bool number;
  final int lines;
  final Map<String, String>? choices;
}

class _ReadingForm extends StatefulWidget {
  const _ReadingForm({
    required this.title,
    required this.fields,
    required this.submit,
  });
  final String title;
  final List<_Field> fields;
  final Future<String?> Function(Map<String, String>) submit;
  @override
  State<_ReadingForm> createState() => _ReadingFormState();
}

class _ReadingFormState extends State<_ReadingForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.id: TextEditingController(text: field.initial),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final error = await widget.submit({
        for (final item in _controllers.entries)
          item.key: item.value.text.trim(),
      });
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context);
      } else {
        setState(() => _error = error);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存できませんでした。入力を保持しています。再試行してください');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          insetPadding: const EdgeInsets.all(12),
          title: Text(widget.title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: _key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ...widget.fields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: field.choices != null
                            ? DropdownButtonFormField<String>(
                                initialValue: field.initial,
                                isExpanded: true,
                                decoration:
                                    InputDecoration(labelText: field.label),
                                items: field.choices!.entries
                                    .map(
                                      (item) => DropdownMenuItem(
                                        value: item.key,
                                        child: Text(
                                          item.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (value) => _controllers[field.id]!.text =
                                        value ?? '',
                              )
                            : TextFormField(
                                key: ValueKey('reading-field-${field.id}'),
                                controller: _controllers[field.id],
                                enabled: !_saving,
                                maxLines: field.lines,
                                keyboardType:
                                    field.number ? TextInputType.number : null,
                                decoration:
                                    InputDecoration(labelText: field.label),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (field.required && text.isEmpty) {
                                    return '入力してください';
                                  }
                                  if (field.number &&
                                      text.isNotEmpty &&
                                      (!RegExp(r'^\d+$').hasMatch(text) ||
                                          int.tryParse(text) == null ||
                                          int.parse(text) > 1000000)) {
                                    return '0〜1000000の整数を入力してください';
                                  }
                                  return null;
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      );
}
