import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Verdict category returned by `lifestyle-hub` `price.advise`.
enum PriceAdviceVerdict {
  buy,
  wait,
  hold;

  String get wireValue {
    switch (this) {
      case PriceAdviceVerdict.buy:
        return 'buy';
      case PriceAdviceVerdict.wait:
        return 'wait';
      case PriceAdviceVerdict.hold:
        return 'hold';
    }
  }

  String get label {
    switch (this) {
      case PriceAdviceVerdict.buy:
        return '🎯 買い時';
      case PriceAdviceVerdict.wait:
        return '⏳ 待機推奨';
      case PriceAdviceVerdict.hold:
        return '⚖️ 様子見';
    }
  }

  static PriceAdviceVerdict fromWire(Object? raw) {
    final text = raw?.toString().trim().toLowerCase() ?? '';
    if (text == 'buy' || text.contains('買い時')) {
      return PriceAdviceVerdict.buy;
    }
    if (text == 'wait' || text.contains('待機')) {
      return PriceAdviceVerdict.wait;
    }
    if (text == 'hold' || text.contains('様子見')) {
      return PriceAdviceVerdict.hold;
    }
    return PriceAdviceVerdict.hold;
  }
}

@immutable
class PriceAdviceStats {
  const PriceAdviceStats({
    required this.sampleCount,
    this.currentPrice,
    this.targetPrice,
    this.minPrice,
    this.maxPrice,
    this.avgPrice,
    this.recentDeltaPct,
    this.deltaFromAvgPct,
    this.deltaFromTargetPct,
    this.isAtOrBelowTarget = false,
  });

  final int sampleCount;
  final int? currentPrice;
  final int? targetPrice;
  final int? minPrice;
  final int? maxPrice;
  final int? avgPrice;
  final double? recentDeltaPct;
  final double? deltaFromAvgPct;
  final double? deltaFromTargetPct;
  final bool isAtOrBelowTarget;

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static double? _toDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  factory PriceAdviceStats.fromJson(Map<String, dynamic> json) {
    return PriceAdviceStats(
      sampleCount: _toInt(json['sample_count']) ?? 0,
      currentPrice: _toInt(json['current_price']),
      targetPrice: _toInt(json['target_price']),
      minPrice: _toInt(json['min_price']),
      maxPrice: _toInt(json['max_price']),
      avgPrice: _toInt(json['avg_price']),
      recentDeltaPct: _toDouble(json['recent_delta_pct']),
      deltaFromAvgPct: _toDouble(json['delta_from_avg_pct']),
      deltaFromTargetPct: _toDouble(json['delta_from_target_pct']),
      isAtOrBelowTarget: json['is_at_or_below_target'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sample_count': sampleCount,
      'current_price': currentPrice,
      'target_price': targetPrice,
      'min_price': minPrice,
      'max_price': maxPrice,
      'avg_price': avgPrice,
      'recent_delta_pct': recentDeltaPct,
      'delta_from_avg_pct': deltaFromAvgPct,
      'delta_from_target_pct': deltaFromTargetPct,
      'is_at_or_below_target': isAtOrBelowTarget,
    };
  }
}

@immutable
class PriceAdviceResult {
  const PriceAdviceResult({
    required this.productId,
    required this.verdict,
    required this.verdictLabel,
    required this.summary,
    required this.reasons,
    required this.stats,
    required this.source,
    required this.groundedOnObservedLogsOnly,
    required this.cachedAt,
    required this.fromCache,
    required this.cacheTtlHours,
    this.model,
    this.aiFallbackReason,
    this.cachedCurrentPrice,
    this.cachedTargetPrice,
  });

  final String productId;
  final PriceAdviceVerdict verdict;
  final String verdictLabel;
  final String summary;
  final List<String> reasons;
  final PriceAdviceStats stats;
  final String source;
  final bool groundedOnObservedLogsOnly;
  final DateTime cachedAt;
  final bool fromCache;
  final int cacheTtlHours;
  final String? model;
  final String? aiFallbackReason;
  final int? cachedCurrentPrice;
  final int? cachedTargetPrice;

  bool get isStatisticalFallback => source == 'statistical_fallback';

  Duration remainingCacheDuration(DateTime now, Duration ttl) {
    final expiresAt = cachedAt.add(ttl);
    final diff = expiresAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  PriceAdviceResult copyWith({
    bool? fromCache,
  }) {
    return PriceAdviceResult(
      productId: productId,
      verdict: verdict,
      verdictLabel: verdictLabel,
      summary: summary,
      reasons: reasons,
      stats: stats,
      source: source,
      groundedOnObservedLogsOnly: groundedOnObservedLogsOnly,
      cachedAt: cachedAt,
      fromCache: fromCache ?? this.fromCache,
      cacheTtlHours: cacheTtlHours,
      model: model,
      aiFallbackReason: aiFallbackReason,
      cachedCurrentPrice: cachedCurrentPrice,
      cachedTargetPrice: cachedTargetPrice,
    );
  }

  factory PriceAdviceResult.fromResponseMap({
    required String productId,
    required Map<String, dynamic> data,
    required DateTime evaluatedAt,
    int? productCurrentPrice,
    int? productTargetPrice,
  }) {
    final legacyAdvice = (data['advice'] as String?)?.trim() ?? '';
    final verdictRaw = data['verdict'] ?? data['verdict_label'] ?? legacyAdvice;
    final verdict = PriceAdviceVerdict.fromWire(verdictRaw);
    final rawLabel = (data['verdict_label'] as String?)?.trim() ?? '';
    final verdictLabel = rawLabel.isNotEmpty ? rawLabel : verdict.label;

    final rawSummary = (data['summary'] as String?)?.trim() ?? '';
    final summary = rawSummary.isNotEmpty
        ? rawSummary
        : (legacyAdvice.isNotEmpty ? legacyAdvice : '観測価格履歴をもとに評価しました。');

    final reasons = <String>[];
    final rawReasons = data['reasons'];
    if (rawReasons is List) {
      for (final item in rawReasons) {
        final line = item?.toString().trim() ?? '';
        if (line.isNotEmpty) {
          reasons.add(line);
        }
      }
    }

    final rawStats = data['stats'];
    final statsMap = rawStats is Map
        ? Map<String, dynamic>.from(rawStats)
        : <String, dynamic>{
            'current_price': productCurrentPrice,
            'target_price': productTargetPrice,
          };

    final ttlRaw = data['cache_ttl_hours'];
    final ttlHours = ttlRaw is num ? ttlRaw.round() : 24;

    return PriceAdviceResult(
      productId: productId,
      verdict: verdict,
      verdictLabel: verdictLabel,
      summary: summary,
      reasons: List<String>.unmodifiable(reasons),
      stats: PriceAdviceStats.fromJson(statsMap),
      source: (data['source'] as String?)?.trim().isNotEmpty == true
          ? (data['source'] as String).trim()
          : 'llm',
      groundedOnObservedLogsOnly:
          data['grounded_on_observed_logs_only'] != false,
      cachedAt: evaluatedAt.toUtc(),
      fromCache: false,
      cacheTtlHours: ttlHours > 0 ? ttlHours : 24,
      model: (data['model'] as String?)?.trim(),
      aiFallbackReason: (data['ai_fallback_reason'] as String?)?.trim(),
      cachedCurrentPrice: productCurrentPrice ??
          PriceAdviceStats._toInt(statsMap['current_price']),
      cachedTargetPrice: productTargetPrice ??
          PriceAdviceStats._toInt(statsMap['target_price']),
    );
  }

  factory PriceAdviceResult.fromCacheJson(Map<String, dynamic> json) {
    final cachedAtMs = PriceAdviceStats._toInt(json['cached_at_epoch_ms']) ?? 0;
    final rawStats = json['stats'];
    final statsMap = rawStats is Map
        ? Map<String, dynamic>.from(rawStats)
        : <String, dynamic>{};
    final verdict = PriceAdviceVerdict.fromWire(json['verdict']);
    final reasonsList = (json['reasons'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final ttlHours = PriceAdviceStats._toInt(json['cache_ttl_hours']) ?? 24;
    return PriceAdviceResult(
      productId: (json['product_id'] as String?) ?? '',
      verdict: verdict,
      verdictLabel:
          (json['verdict_label'] as String?)?.trim().isNotEmpty == true
              ? (json['verdict_label'] as String).trim()
              : verdict.label,
      summary: (json['summary'] as String?) ?? '',
      reasons: List<String>.unmodifiable(reasonsList),
      stats: PriceAdviceStats.fromJson(statsMap),
      source: (json['source'] as String?) ?? 'llm',
      groundedOnObservedLogsOnly:
          json['grounded_on_observed_logs_only'] != false,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(cachedAtMs, isUtc: true),
      fromCache: true,
      cacheTtlHours: ttlHours > 0 ? ttlHours : 24,
      model: json['model'] as String?,
      aiFallbackReason: json['ai_fallback_reason'] as String?,
      cachedCurrentPrice: PriceAdviceStats._toInt(json['cached_current_price']),
      cachedTargetPrice: PriceAdviceStats._toInt(json['cached_target_price']),
    );
  }

  Map<String, dynamic> toCacheJson() {
    return <String, dynamic>{
      'product_id': productId,
      'verdict': verdict.wireValue,
      'verdict_label': verdictLabel,
      'summary': summary,
      'reasons': reasons,
      'stats': stats.toJson(),
      'source': source,
      'grounded_on_observed_logs_only': groundedOnObservedLogsOnly,
      'cached_at_epoch_ms': cachedAt.toUtc().millisecondsSinceEpoch,
      'cache_ttl_hours': cacheTtlHours,
      'model': model,
      'ai_fallback_reason': aiFallbackReason,
      'cached_current_price': cachedCurrentPrice,
      'cached_target_price': cachedTargetPrice,
    };
  }
}

typedef PriceAdviceInvoker = Future<Map<String, dynamic>?> Function(
  String productId,
);

/// Caches per-product purchase advisor verdicts locally for 24h and
/// automatically invalidates the entry when tracked current or target price changes.
class PriceAdviceCacheService {
  PriceAdviceCacheService({
    Future<SharedPreferences> Function()? prefsProvider,
    PriceAdviceInvoker? invoker,
    DateTime Function()? clock,
    this.cacheTtl = const Duration(hours: 24),
  })  : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _invoker = invoker ?? _defaultInvoke,
        _clock = clock ?? DateTime.now;

  static const String cacheKeyPrefix = 'price_advice_cache_v1_';

  final Future<SharedPreferences> Function() _prefsProvider;
  final PriceAdviceInvoker _invoker;
  final DateTime Function() _clock;
  final Duration cacheTtl;

  static Future<Map<String, dynamic>?> _defaultInvoke(String productId) async {
    final resp = await Supabase.instance.client.functions.invoke(
      'lifestyle-hub',
      body: <String, dynamic>{
        'action': 'price.advise',
        'product_id': productId,
      },
    );
    final raw = resp.data;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static String storageKey(String productId) => '$cacheKeyPrefix$productId';

  static int? _priceValue(Object? raw) => PriceAdviceStats._toInt(raw);

  Future<PriceAdviceResult?> readCached(Map<String, dynamic> product) async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      return null;
    }
    try {
      final prefs = await _prefsProvider();
      final encoded = prefs.getString(storageKey(productId));
      if (encoded == null || encoded.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      final result =
          PriceAdviceResult.fromCacheJson(Map<String, dynamic>.from(decoded));
      if (result.summary.trim().isEmpty) {
        return null;
      }

      final now = _clock().toUtc();
      if (now.difference(result.cachedAt) >= cacheTtl) {
        return null;
      }

      final currentPrice = _priceValue(product['current_price']);
      final targetPrice = _priceValue(product['target_price']);
      if (result.cachedCurrentPrice != currentPrice ||
          result.cachedTargetPrice != targetPrice) {
        return null;
      }

      return result.copyWith(fromCache: true);
    } catch (_) {
      // Fail-open on storage or JSON corruption.
      return null;
    }
  }

  Future<Map<String, PriceAdviceResult>> loadCachedMap(
    Iterable<Map<String, dynamic>> products,
  ) async {
    final cached = <String, PriceAdviceResult>{};
    for (final product in products) {
      final id = product['id']?.toString().trim() ?? '';
      if (id.isEmpty) {
        continue;
      }
      final hit = await readCached(product);
      if (hit != null) {
        cached[id] = hit;
      }
    }
    return cached;
  }

  Future<PriceAdviceResult> getAdvice({
    required Map<String, dynamic> product,
    bool forceRefresh = false,
  }) async {
    final productId = product['id']?.toString().trim() ?? '';
    if (productId.isEmpty) {
      throw ArgumentError('product id is required');
    }

    if (!forceRefresh) {
      final hit = await readCached(product);
      if (hit != null) {
        return hit;
      }
    }

    final data = await _invoker(productId);
    if (data == null) {
      throw StateError('AI助言のレスポンスを取得できませんでした');
    }
    if (data['error'] != null && data['success'] != true) {
      throw StateError(data['error'].toString());
    }
    if (data['success'] == false &&
        data['summary'] == null &&
        data['verdict'] == null) {
      throw StateError(data['advice']?.toString() ?? 'AI助言取得に失敗しました');
    }

    final result = PriceAdviceResult.fromResponseMap(
      productId: productId,
      data: data,
      evaluatedAt: _clock().toUtc(),
      productCurrentPrice: _priceValue(product['current_price']),
      productTargetPrice: _priceValue(product['target_price']),
    );

    try {
      final prefs = await _prefsProvider();
      await prefs.setString(
        storageKey(productId),
        jsonEncode(result.toCacheJson()),
      );
    } catch (_) {
      // Cache persistence is best-effort and must not fail advisor output.
    }

    return result;
  }
}
