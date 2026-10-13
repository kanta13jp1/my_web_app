import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../catalogs/philosophy_catalog.dart';
import '../../domain/models/philosophy_reading.dart';

class ReadingBookResult {
  const ReadingBookResult(
    this.title,
    this.edition, {
    this.author = '',
    this.authorAliases = const [],
    this.workId = '',
    this.note = '',
  });
  final List<String> authorAliases;
  final String workId;
  final String note;
  final String author;
  final String title;
  final ReadingEdition edition;
}

String _searchText(String value) => value
    .replaceAll('Ⅰ', 'I')
    .toLowerCase()
    .replaceAll(RegExp(r'''[\s　・･:：'’“”"?？!！,，.。()（）\[\]「」『』-]'''), '');

bool _matchesAuthor(String query, String name, List<String> aliases) {
  final text = _searchText(query);
  if (query.trim().isNotEmpty && text.isEmpty) return false;
  return text.isEmpty ||
      name.isEmpty ||
      [name, ...aliases].any((value) => _searchText(value).contains(text));
}

String _normalizeIsbn(String value) {
  var isbn = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (RegExp(r'^\d{9}[\dX]$').hasMatch(isbn)) {
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (isbn[i] == 'X' ? 10 : int.parse(isbn[i])) * (10 - i);
    }
    if (sum % 11 != 0) return '';
    final prefix = '978${isbn.substring(0, 9)}';
    var weighted = 0;
    for (var i = 0; i < 12; i++) {
      weighted += int.parse(prefix[i]) * (i.isEven ? 1 : 3);
    }
    isbn = '$prefix${(10 - weighted % 10) % 10}';
  }
  if (!RegExp(r'^97[89]\d{10}$').hasMatch(isbn)) return '';
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    sum += int.parse(isbn[i]) * (i.isEven ? 1 : 3);
  }
  return sum % 10 == 0 ? isbn : '';
}

class ReadingBookSearch {
  const ReadingBookSearch();

  Future<List<ReadingBookResult>> search(
    String query, {
    http.Client? client,
    bool external = false,
    String author = '',
  }) async {
    final text = query.trim();
    if (text.isEmpty || text.length > 200) return [];
    final isbn = _normalizeIsbn(text);
    final isIsbn = isbn.isNotEmpty;
    // Searchable editions need not belong to the shared philosophical works.
    // This also supports books attached to existing personal reading records.
    final books = [
      ...philosophyCatalogEditions.map((book) {
        final work =
            philosophyWorks.where((work) => work.id == book.workId).firstOrNull;
        return ReadingBookResult(
          book.label,
          book.edition,
          workId: book.workId,
          author: work?.author.name ?? '',
          authorAliases: work?.author.aliases ?? const [],
          note: book.note,
        );
      }),
      const ReadingBookResult(
        '国家論・岩波文庫（スピノザ／畠中尚志訳・第16刷）',
        ReadingEdition(
          publisher: '岩波書店',
          translator: '畠中尚志',
          year: '1995',
          language: '日本語',
          volume: '岩波文庫・第16刷（第12刷改版: 1976年）',
          totalPages: 213,
          isbn: '9784003361566',
          sourceUrl:
              'https://ndlsearch.ndl.go.jp/books/R100000002-I000002440109',
          bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003361566',
        ),
        author: 'スピノザ',
      ),
      const ReadingBookResult(
        '読書について・光文社（ショーペンハウアー）',
        ReadingEdition(
          publisher: '光文社',
          translator: '鈴木芳子',
          year: '2013',
          language: '日本語',
          isbn: '9784334752712',
          sourceUrl: 'https://www.kotensinyaku.jp/books/book169/',
          bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752712',
        ),
        author: 'ショーペンハウアー',
        authorAliases: ['ショウペンハウエル', 'ショーペンハウエル', 'Arthur Schopenhauer',],
      ),
      const ReadingBookResult(
        '読書について 他二篇・岩波文庫（ショウペンハウエル）',
        ReadingEdition(
          publisher: '岩波書店',
          translator: '斎藤忍随',
          year: '1983',
          language: '日本語',
          volume: '岩波文庫 青632-2',
          totalPages: 160,
          isbn: '9784003363225',
          sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784003363225',
          bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003363225',
        ),
        author: 'ショーペンハウアー',
        authorAliases: ['ショウペンハウエル', 'ショーペンハウエル', 'Arthur Schopenhauer',],
      ),
    ];
    // A curated work identity connects alternate Japanese titles and anthologies.
    // Only exact catalog/original titles establish this relationship; label
    // substring searches remain available without inferring new work links.
    final normalized = _searchText(text);
    if (normalized.isEmpty) return [];
    final workIds = philosophyWorks
        .where(
          (work) =>
              (_searchText(work.title) == normalized ||
                  (work.originalTitle.isNotEmpty &&
                      _searchText(work.originalTitle) == normalized)) &&
              _matchesAuthor(author, work.author.name, work.author.aliases),
        )
        .map((work) => work.id)
        .toSet();
    final matches = books.where(
      (book) => isIsbn
          ? _normalizeIsbn(book.edition.isbn) == isbn
          : _matchesAuthor(author, book.author, book.authorAliases) &&
              (workIds.contains(book.workId) ||
                  _searchText(
                          '${book.title} ${book.edition.translator} ${book.edition.publisher}',
                      )
                      .contains(normalized)),
    );
    if (matches.isNotEmpty && !external) return matches.toList();
    if (!isIsbn && RegExp(r'^[0-9Xx\s-]+$').hasMatch(text)) return [];
    final ownedClient = client == null;
    final transport = client ?? http.Client();
    try {
      if (!isIsbn) {
        return await _searchTitle(text, transport, author: author.trim());
      }
      final response = await transport
          .get(Uri.https('api.openbd.jp', '/v1/get', {'isbn': isbn}))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('Book search unavailable');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty || data.first == null) return [];
      final book = readingMap(data.first);
      final summary = readingMap(book['summary']);
      final actualIsbn = summary['isbn']?.toString() ?? '';
      if (actualIsbn != isbn) return [];
      final onix = readingMap(book['onix']);
      final detail = readingMap(onix['DescriptiveDetail']);
      final contributors = detail['Contributor'];
      String namesFor(String role) {
        if (contributors is! List) return '';
        return contributors
            .map(readingMap)
            .where((person) {
              final roles = person['ContributorRole'];
              return roles is List ? roles.contains(role) : roles == role;
            })
            .map((person) {
              final name = person['PersonName'];
              return name is Map
                  ? name['content']?.toString() ?? ''
                  : name?.toString() ?? '';
            })
            .where((name) => name.isNotEmpty)
            .join('・');
      }

      int? pages;
      final extents = detail['Extent'];
      if (extents is List) {
        for (final extent in extents.map(readingMap)) {
          if (extent['ExtentUnit'] == '03') {
            pages = int.tryParse('${extent['ExtentValue']}');
          }
        }
      }
      final date = summary['pubdate']?.toString() ?? '';
      return [
        ReadingBookResult(
          summary['title']?.toString() ?? isbn,
          ReadingEdition(
            isbn: actualIsbn,
            publisher: summary['publisher']?.toString() ?? '',
            translator: namesFor('B06'),
            editor: namesFor('B01'),
            year: date.length >= 4 ? date.substring(0, 4) : '',
            language: '',
            totalPages:
                pages != null && pages > 0 && pages <= 1000000 ? pages : null,
            sourceUrl: 'https://api.openbd.jp/v1/get?isbn=$actualIsbn',
            bookUrl: Uri.https(
              'www.amazon.co.jp',
              '/s/',
              {'i': 'stripbooks', 'k': actualIsbn},
            ).toString(),
          ),
        ),
      ];
    } finally {
      if (ownedClient) transport.close();
    }
  }

  Future<List<ReadingBookResult>> _searchTitle(
    String title,
    http.Client client, {
    String author = '',
  }) async {
    final response = await client
        .get(
          Uri.https('ndlsearch.ndl.go.jp', '/api/opensearch', {
            'title': title,
            if (author.isNotEmpty) 'creator': author,
            'dpid': 'iss-ndl-opac',
            'cnt': '20',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 2000000) {
      throw const FormatException('Title search unavailable');
    }
    final text = utf8.decode(response.bodyBytes);
    if (text.contains('<!DOCTYPE')) {
      throw const FormatException('Unexpected XML declaration');
    }
    final document = XmlDocument.parse(text);
    if (document.rootElement.name.local != 'rss') {
      throw const FormatException('Unexpected title response');
    }
    const dc = 'http://purl.org/dc/elements/1.1/';
    const terms = 'http://purl.org/dc/terms/';
    const ndl = 'http://ndl.go.jp/dcndl/terms/';
    final results = <ReadingBookResult>[];
    final seen = <String>{};
    for (final item in document.findAllElements('item').take(20)) {
      String value(String name, [String? namespace]) => item
          .findElements(name, namespace: namespace)
          .map((node) => node.innerText.trim())
          .where((text) => text.isNotEmpty)
          .join('・');
      final source = value('link');
      if (!RegExp(
        r'^https://ndlsearch\.ndl\.go\.jp/books/R100000002-I[0-9A-Za-z]+$',
      ).hasMatch(source)) {
        continue;
      }
      final bookTitle = value('title', dc);
      if (bookTitle.isEmpty) continue;
      var isbn = '';
      for (final identifier in item.findElements('identifier', namespace: dc)) {
        if (identifier.attributes.any(
          (attribute) =>
              attribute.name.local == 'type' &&
              attribute.value.endsWith(':ISBN'),
        )) {
          isbn = _normalizeIsbn(identifier.innerText.trim());
          if (isbn.isNotEmpty) break;
        }
      }
      // Keep editions separate; deduplicate only the identical source record.
      if (!seen.add(source)) continue;
      final translators = <String>{};
      final editors = <String>{};
      final credits = [
        ...item
            .findElements('creator', namespace: dc)
            .map((node) => node.innerText),
        // RSS author also includes literal responsibility credits; authority
        // headings alone do not identify a translator or editor.
        ...item.findElements('author').expand(
              (node) => node.innerText.split(',').where(
                    (credit) =>
                        RegExp(r'^[ぁ-んァ-ヶ一-龯々ー・\s]+(?:編訳|翻訳|訳|編集|編)(?:・解説)?$')
                            .hasMatch(credit.trim()),
                  ),
            ),
      ];
      for (final creator in credits) {
        for (final credit in creator.split(RegExp(r'[;；]'))) {
          final match = RegExp(r'^(.+?)\s+(編訳|翻訳|訳|編集|編)(?:・解説)?$')
              .firstMatch(credit.trim());
          if (match == null) continue;
          final name = match.group(1)!.trim();
          final role = match.group(2)!;
          if (role == '訳' || role == '翻訳' || role == '編訳') {
            translators.add(name);
          }
          if (role == '編' || role == '編集' || role == '編訳') {
            editors.add(name);
          }
        }
      }
      final pageMatch =
          RegExp(r'^(\d+)\s*p\.?$').firstMatch(value('extent', dc));
      final pages = int.tryParse(pageMatch?.group(1) ?? '');
      final date = value('issued', terms);
      final year = RegExp(r'^\d{4}').firstMatch(date)?.group(0) ?? '';
      final language = value('language', dc);
      final publisher = value('publisher', dc);
      results.add(
        ReadingBookResult(
          bookTitle,
          ReadingEdition(
            publisher: publisher,
            translator: translators.join('・'),
            editor: editors.join('・'),
            isbn: isbn,
            totalPages:
                pages != null && pages > 0 && pages <= 1000000 ? pages : null,
            year: year,
            language: language == 'jpn' ? '日本語' : language,
            volume: value('volume', ndl),
            sourceUrl: source,
            bookUrl: Uri.https('www.amazon.co.jp', '/s/', {
              'i': 'stripbooks',
              'k': isbn.isNotEmpty ? isbn : '$bookTitle $publisher',
            }).toString(),
          ),
        ),
      );
    }
    return results;
  }
}
