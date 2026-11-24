import 'package:supabase_flutter/supabase_flutter.dart';

/// 外部 URL の Markdown / 構造化 JSON 抽出方式 (#2639)。
enum ExternalExtractorMode {
  stdlibHtml('stdlib_html', '標準HTMLパーサー'),
  firecrawlV1('firecrawl_v1', 'Firecrawl v1');

  const ExternalExtractorMode(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static ExternalExtractorMode parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final value in ExternalExtractorMode.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ExternalExtractorMode.stdlibHtml;
  }
}

/// 抽出ジョブの処理状態 (#2639)。
enum ExternalExtractionStatus {
  queued('queued', '処理待ち'),
  completed('completed', '抽出完了'),
  failed('failed', '失敗'),
  blocked('blocked', 'SSRFブロック');

  const ExternalExtractionStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static ExternalExtractionStatus parse(Object? raw) {
    final normalized = raw?.toString().trim().toLowerCase() ?? '';
    for (final value in ExternalExtractionStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return ExternalExtractionStatus.queued;
  }
}

/// クライアント側 SSRF・スキーム検証 (#2639)。
String? validateExternalHttpsUrl(String rawUrl) {
  final cleaned = rawUrl.trim();
  if (cleaned.isEmpty) {
    return '抽出対象の https:// URL を入力してください。';
  }
  if (RegExp(r'\s').hasMatch(cleaned)) {
    return 'URL に空白や改行を含めることはできません。';
  }
  final uri = Uri.tryParse(cleaned);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    return '有効な https:// URL を入力してください。';
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return 'セキュリティ要件により https:// スキームのみ許可されています。';
  }
  if (uri.userInfo.isNotEmpty || uri.authority.contains('@')) {
    return '認証情報（user:pass@）を含む URL は指定できません。';
  }
  final host = uri.host.trim().toLowerCase();
  if (_isBlockedHost(host)) {
    return '内部ネットワーク・ローカルホスト宛の URL ($host) は指定できません。';
  }
  return null;
}

bool _isBlockedHost(String host) {
  final cleanHost = host.startsWith('[') && host.endsWith(']')
      ? host.substring(1, host.length - 1)
      : host;
  if (cleanHost == 'localhost' ||
      cleanHost.endsWith('.localhost') ||
      cleanHost.endsWith('.local') ||
      cleanHost.endsWith('.internal') ||
      cleanHost.endsWith('.arpa')) {
    return true;
  }
  if (cleanHost == '::1' ||
      cleanHost == '::' ||
      cleanHost.startsWith('fe80:') ||
      cleanHost.startsWith('fc') ||
      cleanHost.startsWith('fd') ||
      cleanHost.startsWith('::ffff:127.') ||
      cleanHost.startsWith('::ffff:10.') ||
      cleanHost.startsWith('::ffff:192.168.') ||
      cleanHost.startsWith('::ffff:169.254.')) {
    return true;
  }
  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
      .firstMatch(cleanHost);
  if (ipv4 != null) {
    final a = int.parse(ipv4.group(1)!);
    final b = int.parse(ipv4.group(2)!);
    if (a == 127 ||
        a == 10 ||
        a == 0 ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 100 && b >= 64 && b <= 127) ||
        a >= 224) {
      return true;
    }
  }
  return false;
}

/// 抽出結果内の安全リンク表現 (#2639)。
class ExtractedLinkItem {
  const ExtractedLinkItem({
    required this.text,
    required this.url,
  });

  factory ExtractedLinkItem.fromJson(Map<String, Object?> json) {
    return ExtractedLinkItem(
      text: json['text']?.toString().trim() ?? '',
      url: json['url']?.toString().trim() ?? '',
    );
  }

  final String text;
  final String url;
}

/// バックエンド構造化 JSON ペイロード (#2639)。
class StructuredExtractionPayload {
  const StructuredExtractionPayload({
    required this.title,
    required this.description,
    required this.headings,
    required this.links,
    required this.keyPoints,
    required this.wordCount,
    required this.extractorMode,
    required this.fetchedAt,
  });

  factory StructuredExtractionPayload.fromJson(Map<String, Object?> json) {
    final headingsRaw = json['headings'];
    final headings = <String>[];
    if (headingsRaw is List<Object?>) {
      for (final item in headingsRaw) {
        if (item is Map<Object?, Object?>) {
          final text = item['text']?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            headings.add(text);
          }
        } else if (item != null && item.toString().trim().isNotEmpty) {
          headings.add(item.toString().trim());
        }
      }
    }

    final linksRaw = json['links'];
    final links = <ExtractedLinkItem>[];
    if (linksRaw is List<Object?>) {
      for (final item in linksRaw) {
        if (item is Map<Object?, Object?>) {
          final parsed = ExtractedLinkItem.fromJson(_asStringMap(item));
          if (parsed.url.startsWith('https://') ||
              parsed.url.startsWith('http://')) {
            links.add(parsed);
          }
        }
      }
    }

    final pointsRaw = json['key_points'];
    final keyPoints = <String>[];
    if (pointsRaw is List<Object?>) {
      for (final item in pointsRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          keyPoints.add(text);
        }
      }
    }

    final rawWords = json['word_count'];
    final wordCount = switch (rawWords) {
      final int v => v,
      final num v => v.toInt(),
      _ => int.tryParse(rawWords?.toString() ?? '') ?? 0,
    };

    return StructuredExtractionPayload(
      title: json['title']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      headings: List<String>.unmodifiable(headings),
      links: List<ExtractedLinkItem>.unmodifiable(links),
      keyPoints: List<String>.unmodifiable(keyPoints),
      wordCount: wordCount < 0 ? 0 : wordCount,
      extractorMode: ExternalExtractorMode.parse(json['extractor_mode']),
      fetchedAt: _parseUtcDate(json['fetched_at']),
    );
  }

  final String title;
  final String description;
  final List<String> headings;
  final List<ExtractedLinkItem> links;
  final List<String> keyPoints;
  final int wordCount;
  final ExternalExtractorMode extractorMode;
  final DateTime? fetchedAt;
}

/// `external_markdown_extractions` テーブルの 1 レコード (#2639)。
class ExternalMarkdownExtractionRecord {
  const ExternalMarkdownExtractionRecord({
    required this.id,
    required this.userId,
    required this.sourceUrl,
    required this.sourceTitle,
    required this.markdownContent,
    required this.structuredPayload,
    required this.extractorMode,
    required this.status,
    required this.errorCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExternalMarkdownExtractionRecord.fromJson(Map<String, Object?> json) {
    return ExternalMarkdownExtractionRecord(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sourceUrl: json['source_url']?.toString() ?? '',
      sourceTitle: json['source_title']?.toString() ?? '',
      markdownContent: json['markdown_content']?.toString() ?? '',
      structuredPayload: StructuredExtractionPayload.fromJson(
        _asStringMap(json['structured_payload']),
      ),
      extractorMode: ExternalExtractorMode.parse(json['extractor_mode']),
      status: ExternalExtractionStatus.parse(json['status']),
      errorCode: json['error_code']?.toString(),
      createdAt: _parseUtcDate(json['created_at']),
      updatedAt: _parseUtcDate(json['updated_at']),
    );
  }

  final String id;
  final String userId;
  final String sourceUrl;
  final String sourceTitle;
  final String markdownContent;
  final StructuredExtractionPayload structuredPayload;
  final ExternalExtractorMode extractorMode;
  final ExternalExtractionStatus status;
  final String? errorCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

abstract class ExternalMarkdownExtractionRepository {
  Future<List<ExternalMarkdownExtractionRecord>> listExtractions({
    int limit = 30,
  });

  Future<ExternalMarkdownExtractionRecord> submitExtraction({
    required String url,
    ExternalExtractorMode mode = ExternalExtractorMode.stdlibHtml,
  });
}

typedef ExternalMarkdownClientResolver = SupabaseClient Function();

/// `external_markdown_extractions` 遅延解決リポジトリ (#2639)。
class SupabaseExternalMarkdownExtractionRepository
    implements ExternalMarkdownExtractionRepository {
  SupabaseExternalMarkdownExtractionRepository({
    SupabaseClient? client,
    ExternalMarkdownClientResolver? clientResolver,
  })  : _client = client,
        _clientResolver = clientResolver;

  final SupabaseClient? _client;
  final ExternalMarkdownClientResolver? _clientResolver;

  SupabaseClient get _resolvedClient =>
      _client ??
      (_clientResolver != null ? _clientResolver() : Supabase.instance.client);

  @override
  Future<List<ExternalMarkdownExtractionRecord>> listExtractions({
    int limit = 30,
  }) async {
    final rows = await _resolvedClient
        .from('external_markdown_extractions')
        .select(
          'id, user_id, source_url, source_title, markdown_content, '
          'structured_payload, extractor_mode, status, error_code, '
          'created_at, updated_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return _extractRows(rows)
        .map(ExternalMarkdownExtractionRecord.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ExternalMarkdownExtractionRecord> submitExtraction({
    required String url,
    ExternalExtractorMode mode = ExternalExtractorMode.stdlibHtml,
  }) async {
    final validationError = validateExternalHttpsUrl(url);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    final userId = _resolvedClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('外部URL抽出の実行にはログインが必要です。');
    }
    final cleanUrl = url.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final inserted = await _resolvedClient
        .from('external_markdown_extractions')
        .insert(<String, Object?>{
          'user_id': userId,
          'source_url': cleanUrl,
          'source_title': cleanUrl,
          'markdown_content': '',
          'structured_payload': <String, Object?>{
            'source_url': cleanUrl,
            'extractor_mode': mode.wireValue,
          },
          'extractor_mode': mode.wireValue,
          'status': ExternalExtractionStatus.queued.wireValue,
          'updated_at': nowIso,
        })
        .select()
        .single();
    return ExternalMarkdownExtractionRecord.fromJson(_asStringMap(inserted));
  }
}

List<Map<String, Object?>> _extractRows(Object? raw) {
  if (raw is! List<Object?>) {
    return const <Map<String, Object?>>[];
  }
  return raw
      .whereType<Map<Object?, Object?>>()
      .map(_asStringMap)
      .toList(growable: false);
}

Map<String, Object?> _asStringMap(Object? raw) {
  final result = <String, Object?>{};
  if (raw is Map<Object?, Object?>) {
    raw.forEach((key, value) {
      result[key.toString()] = value;
    });
  }
  return result;
}

DateTime? _parseUtcDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}
