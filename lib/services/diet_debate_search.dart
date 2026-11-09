import 'dart:convert';

import 'package:http/http.dart' as http;

class DietSpeech {
  const DietSpeech(
    this.id,
    this.speaker,
    this.date,
    this.house,
    this.meeting,
    this.url,
    this.group,
    this.topics,
  );

  final String id;
  final String speaker;
  final String date;
  final String house;
  final String meeting;
  final Uri url;
  final String? group;
  final List<String> topics;
  static const topicWords = {
    '子育て': ['子育て', '育児', '保育'],
    '物価': ['物価', '値上げ'],
    '生成AI': ['生成AI', '生成ＡＩ', '対話型AI', '対話型ＡＩ'],
    '著作権': ['著作権'],
  };
  bool get isMeetingInformation => id.endsWith('_000');

  factory DietSpeech.fromJson(Map<String, dynamic> row) {
    final id = row['speechID'];
    final issue = row['issueID'];
    final order = row['speechOrder'];
    if (id is! String ||
        issue is! String ||
        !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(issue) ||
        order is! int ||
        order < 0 ||
        id != "${issue}_${order.toString().padLeft(3, '0')}") {
      throw const FormatException('Invalid speech identity');
    }
    final url = Uri.https('kokkai.ndl.go.jp', '/txt/$issue/$order');
    if (row['speechURL'] != url.toString()) {
      throw const FormatException('Invalid speech URL');
    }
    final speechText = row['speech'];
    final topics = [
      if (speechText is String)
        for (final topic in topicWords.entries)
          if (topic.value.any((word) => speechText.contains(word))) topic.key,
    ];
    return DietSpeech(
      id,
      row['speaker'] as String,
      row['date'] as String,
      row['nameOfHouse'] as String,
      row['nameOfMeeting'] as String,
      url,
      row['speakerGroup'] as String?,
      List.unmodifiable(topics),
    );
  }
}

class DietSearchPage {
  const DietSearchPage(
    this.items,
    this.total,
    this.next,
    this.skipped,
    this.fetchedAt,
  );
  final List<DietSpeech> items;
  final int total;
  final int? next;
  final int skipped;
  final DateTime fetchedAt;
}

class DietSearchError implements Exception {
  const DietSearchError(this.message);
  final String message;
}

class DietDebateSearch {
  DietDebateSearch({
    http.Client Function()? createClient,
    DateTime Function()? now,
  })  : _createClient = createClient ?? http.Client.new,
        _now = now ?? DateTime.now;

  static final shared = DietDebateSearch();
  final http.Client Function() _createClient;
  final DateTime Function() _now;
  final _cache = <Uri, ({DateTime expires, DietSearchPage page})>{};
  DateTime? _lastFinished;
  bool _busy = false;

  Future<DietSearchPage> search({
    String term = '',
    String speaker = '',
    String group = '',
    String date = '',
    int start = 1,
  }) async {
    final params = <String, String>{
      if (term.trim().isNotEmpty) 'any': term.trim(),
      if (speaker.trim().isNotEmpty) 'speaker': speaker.trim(),
      if (group.trim().isNotEmpty) 'speakerGroup': group.trim(),
      if (date.isNotEmpty) 'from': date,
      if (date.isNotEmpty) 'until': date,
    };
    if (params.isEmpty) {
      throw const DietSearchError('テーマ、発言者、会派、開催日のいずれかを指定してください。');
    }
    if (start < 1 ||
        [term, speaker, group].any((value) => value.trim().length > 100)) {
      throw const DietSearchError('検索条件を確認してください。');
    }
    final uri = Uri.https('kokkai.ndl.go.jp', '/api/speech', {
      ...params,
      'maximumRecords': '10',
      'startRecord': '$start',
      'recordPacking': 'json',
    });
    final now = _now();
    _cache.removeWhere((_, entry) => !now.isBefore(entry.expires));
    final cached = _cache[uri];
    if (cached != null) return cached.page;
    if (_busy) throw const DietSearchError('先の検索が終わってから検索してください。');
    final last = _lastFinished;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      throw const DietSearchError('会議録へのアクセス間隔を空けています。5秒後にもう一度お試しください。');
    }

    final client = _createClient();
    _busy = true;
    try {
      final response =
          await client.get(uri).timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) {
        throw const DietSearchError('会議録を取得できませんでした。時間をおいて再度お試しください。');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final total = data['numberOfRecords'];
      final rows = data['speechRecord'];
      if (data.containsKey('message') ||
          total is! int ||
          total < 0 ||
          (rows is! List && !(total == 0 && rows == null))) {
        throw const DietSearchError('会議録APIの応答を読み取れませんでした。検索条件をご確認ください。');
      }
      final items = <DietSpeech>[];
      var skipped = 0;
      for (final row in (rows as List? ?? const [])) {
        try {
          items.add(DietSpeech.fromJson(row as Map<String, dynamic>));
        } on FormatException {
          skipped++;
        } on TypeError {
          skipped++;
        }
      }
      final next = data['nextRecordPosition'];
      final fetchedAt = _now();
      final page = DietSearchPage(
        List.unmodifiable(items),
        total,
        next is int && next > start && next <= total ? next : null,
        skipped,
        fetchedAt,
      );
      if (_cache.length >= 12) _cache.remove(_cache.keys.first);
      _cache[uri] =
          (expires: fetchedAt.add(const Duration(minutes: 10)), page: page);
      return page;
    } finally {
      client.close();
      _lastFinished = _now();
      _busy = false;
    }
  }
}
