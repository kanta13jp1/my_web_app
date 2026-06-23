import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads the periodically-scraped CDP (立憲) prefecture local-member counts that
/// the `cdp-benchmark-update` workflow stores in
/// `assets/data/cdp_local_members.json`.
///
/// Fetching all 47 prefectures inline exceeds the page's snapshot timeout, so
/// the counts are scraped by a weekly cron and read here from the bundled asset
/// instead of on every page load.
class LocalElectionCdpBenchmark {
  static const String assetPath = 'assets/data/cdp_local_members.json';

  /// Reads the bundled benchmark asset and returns a prefecture → member-count
  /// map. Returns an empty map when the asset is missing or malformed so the
  /// caller can fall back to the seeded values.
  static Future<Map<String, int>> loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      return parse(raw);
    } catch (_) {
      return const <String, int>{};
    }
  }

  /// Parses the benchmark JSON into a prefecture → member-count map, keeping
  /// only positive counts. Exposed for testing.
  static Map<String, int> parse(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const <String, int>{};
    }
    if (decoded is! Map) {
      return const <String, int>{};
    }
    final dynamic prefectures = decoded['prefectures'];
    if (prefectures is! Map) {
      return const <String, int>{};
    }
    final result = <String, int>{};
    prefectures.forEach((key, value) {
      final name = key.toString().trim();
      final count = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      if (name.isNotEmpty && count > 0) {
        result[name] = count;
      }
    });
    return result;
  }
}
