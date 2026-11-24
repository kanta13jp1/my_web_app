import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic client-side context estimator mirroring server validation
/// inside `ai-hub/context_limits.ts` (#2701).
class ContextBudgetEstimator {
  const ContextBudgetEstimator._();

  static const int defaultMaxContextUnits = 1000000;

  static int estimateTextUnits(String text) {
    if (text.isEmpty) return 0;
    var asciiCount = 0;
    var nonAsciiCount = 0;
    for (final rune in text.runes) {
      if (rune <= 0x7f) {
        asciiCount += 1;
      } else {
        nonAsciiCount += 1;
      }
    }
    final asciiUnits = (asciiCount + 3) ~/ 4;
    final nonAsciiUnits = ((nonAsciiCount * 2) + 2) ~/ 3;
    return asciiUnits + nonAsciiUnits;
  }

  static int estimatePayloadUnits({
    required String text,
    List<int> attachedFileByteSizes = const <int>[],
  }) {
    var total = estimateTextUnits(text);
    for (final bytes in attachedFileByteSizes) {
      if (bytes <= 0) continue;
      // Approximate UTF-8 payload density at ~3 bytes per unit.
      total += (bytes + 2) ~/ 3;
    }
    return total;
  }
}

@immutable
class CustomDataSourceItem {
  const CustomDataSourceItem({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.estimatedUnits,
    this.createdAt,
  });

  final String id;
  final String name;
  final String sourceType;
  final int estimatedUnits;
  final DateTime? createdAt;

  factory CustomDataSourceItem.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString().trim();
    final rawUnits = json['estimated_units'];
    final units = rawUnits is num
        ? rawUnits.toInt()
        : int.tryParse(rawUnits?.toString() ?? '') ?? 0;
    return CustomDataSourceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? 'text',
      estimatedUnits: units < 0 ? 0 : units,
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw),
    );
  }
}

@immutable
class CustomDataSourceLimitStatus {
  const CustomDataSourceLimitStatus({
    required this.plan,
    required this.used,
    required this.maxSources,
    required this.remaining,
    required this.maxContextUnits,
    required this.limitReached,
    required this.items,
  });

  final String plan;
  final int used;
  final int maxSources;
  final int remaining;
  final int maxContextUnits;
  final bool limitReached;
  final List<CustomDataSourceItem> items;

  factory CustomDataSourceLimitStatus.fromJson(Map<String, dynamic> json) {
    int parseCount(Object? raw, int fallback) {
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    final maxSources = parseCount(json['max_sources'], 20);
    final used = parseCount(json['used'], 0);
    final remaining = parseCount(
      json['remaining'],
      (maxSources - used).clamp(0, maxSources),
    );
    final maxContextUnits = parseCount(
      json['max_context_units'],
      ContextBudgetEstimator.defaultMaxContextUnits,
    );
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => CustomDataSourceItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <CustomDataSourceItem>[];

    return CustomDataSourceLimitStatus(
      plan: (json['plan']?.toString().trim().isNotEmpty == true)
          ? json['plan'].toString().trim().toLowerCase()
          : 'free',
      used: used < 0 ? 0 : used,
      maxSources: maxSources <= 0 ? 20 : maxSources,
      remaining: remaining < 0 ? 0 : remaining,
      maxContextUnits: maxContextUnits <= 0
          ? ContextBudgetEstimator.defaultMaxContextUnits
          : maxContextUnits,
      limitReached: json['limit_reached'] == true || used >= maxSources,
      items: items,
    );
  }
}

abstract class CustomDataSourceRepository {
  Future<CustomDataSourceLimitStatus> fetchStatus();

  Future<CustomDataSourceLimitStatus> registerSource({
    required String name,
    required String sourceType,
    required String sampleText,
  });
}

typedef AiHubClientResolver = SupabaseClient Function();

class SupabaseCustomDataSourceRepository implements CustomDataSourceRepository {
  SupabaseCustomDataSourceRepository({AiHubClientResolver? clientResolver})
      : _clientResolver = clientResolver ?? _defaultClientResolver;

  final AiHubClientResolver _clientResolver;

  static SupabaseClient _defaultClientResolver() => Supabase.instance.client;

  static Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  @override
  Future<CustomDataSourceLimitStatus> fetchStatus() async {
    final res = await _clientResolver().functions.invoke(
      'ai-hub',
      body: const <String, dynamic>{'action': 'data_sources.status'},
    );
    return CustomDataSourceLimitStatus.fromJson(_asMap(res.data));
  }

  @override
  Future<CustomDataSourceLimitStatus> registerSource({
    required String name,
    required String sourceType,
    required String sampleText,
  }) async {
    final res = await _clientResolver().functions.invoke(
      'ai-hub',
      body: <String, dynamic>{
        'action': 'data_sources.register',
        'name': name.trim(),
        'source_type': sourceType,
        'sample_text': sampleText,
        'estimated_units': ContextBudgetEstimator.estimateTextUnits(sampleText),
      },
    );
    final map = _asMap(res.data);
    if (map['limit_reached'] == true && res.status >= 400) {
      throw StateError('カスタムデータソースの登録上限に達しています');
    }
    return fetchStatus();
  }
}
