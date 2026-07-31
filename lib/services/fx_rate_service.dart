import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 為替レート (1 通貨 = 円) と取得時刻。
@immutable
class FxRate {
  const FxRate({
    required this.jpyPerUnit,
    required this.fetchedAt,
    required this.asOf,
  });

  /// 1 単位 (例: 1 USD) あたりの円。
  final double jpyPerUnit;

  /// 端末がこのレートを取得/読込した時刻 (鮮度判定用)。
  final DateTime fetchedAt;

  /// レート提供元が示す基準日 (例: ECB/銀行の更新日)。表示用。
  final DateTime asOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'jpyPerUnit': jpyPerUnit,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'asOf': asOf.toUtc().toIso8601String(),
      };

  static FxRate? fromJson(Map<String, dynamic> json) {
    final rate = (json['jpyPerUnit'] as num?)?.toDouble();
    final fetchedAt = DateTime.tryParse(json['fetchedAt']?.toString() ?? '');
    final asOf = DateTime.tryParse(json['asOf']?.toString() ?? '');
    if (rate == null || rate <= 0 || fetchedAt == null) {
      return null;
    }
    return FxRate(
      jpyPerUnit: rate,
      fetchedAt: fetchedAt,
      asOf: asOf ?? fetchedAt,
    );
  }
}

/// USD/JPY 為替レートを自動取得し端末にキャッシュするサービス。
///
/// 取得元は open.er-api.com (無料・APIキー不要・CORS 対応)。鮮度 [ttl] 内なら
/// キャッシュを返し、超過時に再取得する。取得失敗時は**最後に取得できたレートに
/// フォールバック**する (古くても 0 円換算に落とさない)。一度も取得できていなければ
/// null を返し、呼び出し側は前回換算済みの円額を据え置く。
///
/// 注意: 提供元は銀行間/参照レートのため、カード会社の請求レート (手数料上乗せ
/// ~1.6-3%) とは差が出る。あくまで見込み額の推定に使う。
class FxRateService {
  FxRateService({
    http.Client? client,
    Future<SharedPreferences> Function()? prefsProvider,
    DateTime Function()? now,
    Duration ttl = const Duration(hours: 12),
    Uri? endpoint,
  })  : _client = client ?? http.Client(),
        _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now,
        _ttl = ttl,
        _endpoint =
            endpoint ?? Uri.parse('https://open.er-api.com/v6/latest/USD');

  static const String _prefsKey = 'fx_rate_usd_jpy_v1';

  final http.Client _client;
  final Future<SharedPreferences> Function() _prefsProvider;
  final DateTime Function() _now;
  final Duration _ttl;
  final Uri _endpoint;

  FxRate? _memory;
  Future<FxRate?>? _inFlight;

  /// USD/JPY レートを返す。鮮度内はキャッシュ、超過時は再取得。
  /// 取得失敗時は最後のレートにフォールバックし、無ければ null。
  /// [forceRefresh] で TTL を無視して再取得する (手動更新)。
  Future<FxRate?> getUsdJpy({bool forceRefresh = false}) async {
    final cached = _memory ?? await _readCache();
    if (!forceRefresh && cached != null && _isFresh(cached)) {
      return cached;
    }
    // 同時多発呼び出しを 1 リクエストに束ねる。
    _inFlight ??= _refresh(fallback: cached).whenComplete(() {
      _inFlight = null;
    });
    return _inFlight;
  }

  /// キャッシュがあれば即座に返す (ネットワーク往復なし)。UI の初期表示用。
  Future<FxRate?> cachedUsdJpy() async => _memory ?? await _readCache();

  bool _isFresh(FxRate rate) => _now().difference(rate.fetchedAt) < _ttl;

  Future<FxRate?> _refresh({FxRate? fallback}) async {
    try {
      final resp =
          await _client.get(_endpoint).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        return fallback;
      }
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) {
        return fallback;
      }
      if (body['result'] != null && body['result'] != 'success') {
        return fallback;
      }
      final rates = body['rates'];
      final jpy = rates is Map ? (rates['JPY'] as num?)?.toDouble() : null;
      if (jpy == null || jpy <= 0) {
        return fallback;
      }
      final asOfUnix = (body['time_last_update_unix'] as num?)?.toInt();
      final asOf = asOfUnix != null
          ? DateTime.fromMillisecondsSinceEpoch(asOfUnix * 1000, isUtc: true)
          : _now();
      final rate = FxRate(jpyPerUnit: jpy, fetchedAt: _now(), asOf: asOf);
      _memory = rate;
      await _writeCache(rate);
      return rate;
    } catch (_) {
      // ネットワーク/タイムアウト/パース失敗はフォールバックへ。
      return fallback;
    }
  }

  Future<FxRate?> _readCache() async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final rate = FxRate.fromJson(decoded);
      _memory = rate;
      return rate;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(FxRate rate) async {
    try {
      final prefs = await _prefsProvider();
      await prefs.setString(_prefsKey, jsonEncode(rate.toJson()));
    } catch (_) {
      // 永続化失敗はメモリキャッシュで継続 (致命ではない)。
    }
  }
}
