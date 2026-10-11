typedef ReadingJson = Map<String, dynamic>;

ReadingJson readingMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> readingStrings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

class PhilosophyAuthor {
  const PhilosophyAuthor({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.centuries = const ['不明'],
    this.regions = const ['不明'],
    this.traditions = const [],
    this.source = '',
    this.note = '',
  });

  factory PhilosophyAuthor.fromJson(ReadingJson json) => PhilosophyAuthor(
        id: json['id'] as String,
        name: json['name'] as String,
        aliases: readingStrings(json['aliases']),
        centuries: readingStrings(json['centuries']),
        regions: readingStrings(json['regions']),
        traditions: readingStrings(json['traditions']),
        source: json['source'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );

  final String id;
  final String name;
  final List<String> aliases;
  final List<String> centuries;
  final List<String> regions;
  final List<String> traditions;
  final String source;
  final String note;

  ReadingJson toJson() => {
        'id': id,
        'name': name,
        'aliases': aliases,
        'centuries': centuries,
        'regions': regions,
        'traditions': traditions,
        'source': source,
        'note': note,
      };
}

class PhilosophyWork {
  const PhilosophyWork({
    required this.id,
    required this.title,
    required this.author,
    this.originalTitle = '',
    this.centuries = const ['不明'],
    this.genres = const [],
    this.note = '',
    this.source = '',
  });

  factory PhilosophyWork.fromJson(ReadingJson json) => PhilosophyWork(
        id: json['id'] as String,
        title: json['title'] as String,
        author: PhilosophyAuthor.fromJson(readingMap(json['author_info'])),
        originalTitle: json['original_title'] as String? ?? '',
        centuries: readingStrings(json['centuries']),
        genres: readingStrings(json['genres']),
        note: json['note'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );

  final String id;
  final String title;
  final PhilosophyAuthor author;
  final String originalTitle;
  final List<String> centuries;
  final List<String> genres;
  final String note;
  final String source;

  ReadingJson toJson() => {
        'id': id,
        'title': title,
        'author_info': author.toJson(),
        'original_title': originalTitle,
        'centuries': centuries,
        'genres': genres,
        'note': note,
        'source': source,
      };
}

class ReadingEdition {
  const ReadingEdition({
    this.translator = '',
    this.publisher = '',
    this.year = '',
    this.language = '日本語',
    this.isbn = '',
    this.volume = '',
    this.totalPages,
  });

  factory ReadingEdition.fromJson(ReadingJson json) => ReadingEdition(
        translator: json['translator'] as String? ?? '',
        publisher: json['publisher'] as String? ?? '',
        year: json['year'] as String? ?? '',
        language: json['language'] as String? ?? '日本語',
        isbn: json['isbn'] as String? ?? '',
        volume: json['volume'] as String? ?? '',
        totalPages: json['total_pages'] as int?,
      );

  final String translator;
  final String publisher;
  final String year;
  final String language;
  final String isbn;
  final String volume;
  final int? totalPages;

  ReadingJson toJson() => {
        'translator': translator,
        'publisher': publisher,
        'year': year,
        'language': language,
        'isbn': isbn,
        'volume': volume,
        'total_pages': totalPages,
      };
}

class ReadingEntry {
  const ReadingEntry({
    required this.id,
    required this.date,
    required this.pages,
    this.startPage,
    this.endPage,
    this.understanding,
    this.impression = '',
    this.questions = '',
    this.concepts = '',
    this.history = const [],
  });

  factory ReadingEntry.fromJson(ReadingJson json) => ReadingEntry(
        id: json['id'] as String,
        date: json['date'] as String,
        pages: json['pages'] as int,
        startPage: json['start_page'] as int?,
        endPage: json['end_page'] as int?,
        understanding: json['understanding'] as int?,
        impression: json['impression'] as String? ?? '',
        questions: json['questions'] as String? ?? '',
        concepts: json['concepts'] as String? ?? '',
        history: (json['history'] as List? ?? []).map(readingMap).toList(),
      );

  final String id;
  final String date;
  final int pages;
  final int? startPage;
  final int? endPage;
  final int? understanding;
  final String impression;
  final String questions;
  final String concepts;
  final List<ReadingJson> history;

  String? validate(int? totalPages) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date) {
      return '日付を YYYY-MM-DD で入力してください';
    }
    if (pages < 0 || pages > 1000000) return 'ページ数は0〜1000000の整数です';
    if ((startPage == null) != (endPage == null)) return '開始と終了を両方入力してください';
    if (startPage != null && endPage != null) {
      if (startPage! < 1 || endPage! < startPage!) return 'ページ区間を確認してください';
      if (pages != endPage! - startPage! + 1) return 'ページ数と区間が一致しません';
      if (totalPages != null && endPage! > totalPages) return '総ページ数を超えています';
    }
    if (totalPages != null && pages > totalPages) return '総ページ数を超えています';
    if (understanding != null && (understanding! < 1 || understanding! > 5)) {
      return '理解度は1〜5です';
    }
    return null;
  }

  ReadingJson toJson() => {
        'id': id,
        'date': date,
        'pages': pages,
        'start_page': startPage,
        'end_page': endPage,
        'understanding': understanding,
        'impression': impression,
        'questions': questions,
        'concepts': concepts,
        'history': history,
      };
}

class ReadingCycle {
  const ReadingCycle({
    required this.id,
    required this.startedAt,
    this.status = 'reading',
    this.finishedAt,
    this.edition = const ReadingEdition(),
    this.entries = const [],
  });

  factory ReadingCycle.fromJson(ReadingJson json) => ReadingCycle(
        id: json['id'] as String,
        startedAt: json['started_at'] as String,
        status: json['status'] as String? ?? 'reading',
        finishedAt: json['finished_at'] as String?,
        edition: ReadingEdition.fromJson(readingMap(json['edition'])),
        entries: (json['entries'] as List? ?? [])
            .map((e) => ReadingEntry.fromJson(readingMap(e)))
            .toList(),
      );

  final String id;
  final String startedAt;
  final String status;
  final String? finishedAt;
  final ReadingEdition edition;
  final List<ReadingEntry> entries;

  int get pagesRead => entries.fold(0, (total, entry) => total + entry.pages);

  // Unique page coverage is calculated within one edition and one reading cycle.
  int get coveredPages {
    final ranges = entries
        .where((e) => e.startPage != null && e.endPage != null)
        .map((e) => (e.startPage!, e.endPage!))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    var total = 0;
    var end = 0;
    for (final range in ranges) {
      final start = range.$1 > end ? range.$1 : end + 1;
      if (range.$2 >= start) total += range.$2 - start + 1;
      if (range.$2 > end) end = range.$2;
    }
    return total;
  }

  double? get coverage =>
      edition.totalPages == null ? null : coveredPages / edition.totalPages!;

  ReadingCycle copyWith({
    String? status,
    ReadingEdition? edition,
    List<ReadingEntry>? entries,
  }) =>
      ReadingCycle(
        id: id,
        startedAt: startedAt,
        status: status ?? this.status,
        finishedAt: status == null
            ? finishedAt
            : status == 'read'
                ? DateTime.now().toIso8601String().substring(0, 10)
                : null,
        edition: edition ?? this.edition,
        entries: entries ?? this.entries,
      );

  ReadingJson toJson() => {
        'id': id,
        'started_at': startedAt,
        'status': status,
        'finished_at': finishedAt,
        'edition': edition.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}

class ReadingRecord {
  const ReadingRecord({
    required this.id,
    required this.work,
    this.revision = 0,
    this.cycles = const [],
    this.legacyStatus = 'unread',
  });

  factory ReadingRecord.fromHub(ReadingJson json) {
    final meta = readingMap(json['metadata']);
    final id = json['id'] as String;
    final workData = readingMap(meta['work']);
    final work = workData.isNotEmpty
        ? PhilosophyWork.fromJson(workData)
        : PhilosophyWork(
            id: 'legacy:$id',
            title: meta['title'] as String? ?? 'タイトルなし',
            author: PhilosophyAuthor(
              id: 'legacy-author:$id',
              name: meta['author'] as String? ?? '著者不明',
              note: '既存記録。著者名だけで共通目録に自動統合しません',
            ),
          );
    return ReadingRecord(
      id: id,
      work: work,
      revision: meta['reading_revision'] as int? ?? 0,
      legacyStatus: meta['reading_legacy_read'] == true
          ? 'read'
          : (meta['cycles'] is List && (meta['cycles'] as List).isNotEmpty)
              ? 'unread'
              : meta['status'] as String? ?? 'unread',
      cycles: (meta['cycles'] as List? ?? [])
          .map((c) => ReadingCycle.fromJson(readingMap(c)))
          .toList(),
    );
  }

  final String id;
  final PhilosophyWork work;
  final int revision;
  final List<ReadingCycle> cycles;
  final String legacyStatus;

  bool get isRead =>
      legacyStatus == 'read' || cycles.any((c) => c.status == 'read');
  String get status => cycles.isEmpty ? legacyStatus : cycles.last.status;
  int get pagesRead =>
      cycles.fold(0, (total, cycle) => total + cycle.pagesRead);

  ReadingRecord withCycles(List<ReadingCycle> cycles) => ReadingRecord(
        id: id,
        work: work,
        revision: revision,
        cycles: cycles,
        legacyStatus: legacyStatus,
      );

  ReadingJson savePayload() => {
        'id': id,
        'revision': revision,
        'work': work.toJson(),
        'cycles': cycles.map((c) => c.toJson()).toList(),
      };
}

class ReadingFilter {
  const ReadingFilter(
      {this.query = '', this.century, this.region, this.genre, this.authorId});

  final String query;
  final String? century;
  final String? region;
  final String? genre;
  final String? authorId;

  bool authorMatches(PhilosophyAuthor author) =>
      (century == null || author.centuries.contains(century)) &&
      (region == null || author.regions.contains(region)) &&
      [author.name, ...author.aliases]
          .join(' ')
          .toLowerCase()
          .contains(query.toLowerCase());

  bool matches(PhilosophyWork work) =>
      (authorId == null || work.author.id == authorId) &&
      (century == null || work.centuries.contains(century)) &&
      (region == null || work.author.regions.contains(region)) &&
      (genre == null || work.genres.contains(genre)) &&
      [work.title, work.originalTitle, work.author.name, ...work.author.aliases]
          .join(' ')
          .toLowerCase()
          .contains(query.toLowerCase());
}

class ReadingProgress {
  ReadingProgress(
      Iterable<PhilosophyWork> works, Iterable<ReadingRecord> records) {
    final ids = works.map((w) => w.id).toSet();
    total = ids.length;
    completed = records
        .where((r) => r.isRead && ids.contains(r.work.id))
        .map((r) => r.work.id)
        .toSet()
        .length;
    pages = records
        .where((r) => ids.contains(r.work.id))
        .fold(0, (total, record) => total + record.pagesRead);
  }

  late final int total;
  late final int completed;
  late final int pages;
  double get fraction => total == 0 ? 0 : completed / total;
}

const readingStatusLabels = {
  'unread': '未読',
  'reading': '読書中',
  'read': '読了',
  'paused': '中断',
};

const understandingLabels = {
  1: '1 ほとんど理解できなかった',
  2: '2 一部を理解した',
  3: '3 要点を理解した',
  4: '4 自分の言葉で説明できる',
  5: '5 他の思想と比較して説明できる',
};
