import 'dart:convert';
import 'package:http/http.dart' as http;
import '../catalogs/philosophy_catalog.dart';
import '../../domain/models/philosophy_reading.dart';

class ReadingBookResult {
  const ReadingBookResult(this.title, this.edition);
  final String title;
  final ReadingEdition edition;
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
  }) async {
    final text = query.trim();
    if (text.isEmpty) return [];
    final isbn = _normalizeIsbn(text);
    final isIsbn = isbn.isNotEmpty;
    final matches = philosophyCatalogEditions.where(
      (book) => isIsbn
          ? book.edition.isbn == isbn
          : '${book.label} ${book.edition.translator} ${book.edition.publisher}'
              .toLowerCase()
              .contains(text.toLowerCase()),
    );
    if (matches.isNotEmpty) {
      return matches
          .map((book) => ReadingBookResult(book.label, book.edition))
          .toList();
    }
    if (!isIsbn) return [];
    final ownedClient = client == null;
    final transport = client ?? http.Client();
    try {
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
}
