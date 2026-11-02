import 'dart:convert';

class HedraVideoVariant {
  const HedraVideoVariant({
    required this.id,
    required this.status,
    required this.videoUrl,
    required this.previewUrl,
    required this.reason,
  });

  final String? id;
  final String status;
  final String? videoUrl;
  final String? previewUrl;
  final String? reason;

  bool get isPending {
    if (videoUrl != null) return false;
    return !const {
      'complete',
      'completed',
      'failed',
      'error',
      'canceled',
      'cancelled',
    }.contains(status.toLowerCase());
  }

  factory HedraVideoVariant.fromJson(Map<String, dynamic> json) {
    return HedraVideoVariant(
      id: _text(json['id'] ?? json['generation_id']),
      status: _text(json['status']) ?? 'submitted',
      videoUrl: _text(
        json['videoUrl'] ??
            json['video_url'] ??
            json['url'] ??
            json['downloadUrl'] ??
            json['download_url'],
      ),
      previewUrl: _text(json['previewUrl'] ?? json['preview_url']),
      reason: _text(json['reason'] ?? json['error'] ?? json['error_message']),
    );
  }
}

class HedraVideoBatch {
  const HedraVideoBatch({
    required this.batchGenerationId,
    required this.requestedSize,
    required this.variants,
  });

  final String? batchGenerationId;
  final int requestedSize;
  final List<HedraVideoVariant> variants;

  bool get isBatch => requestedSize > 1 || variants.length > 1;
  bool get isPending => variants.any((variant) => variant.isPending);
  List<String> get generationIds => variants
      .map((variant) => variant.id)
      .whereType<String>()
      .toSet()
      .toList(growable: false);
  List<String> get videoUrls => variants
      .map((variant) => variant.videoUrl)
      .whereType<String>()
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList(growable: false);

  factory HedraVideoBatch.fromMap(Map<String, dynamic> map) {
    final rawResults = _list(
      map['hedraBatchResults'] ?? map['batch_results'],
    );
    final variants = rawResults
        .whereType<Map>()
        .map(
          (item) => HedraVideoVariant.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: true);

    final primaryUrl = _text(
      map['generatedVideoUrl'] ?? map['generated_video_url'],
    );
    final primaryId = _text(
      map['hedraGenerationId'] ?? map['hedra_generation_id'],
    );
    if (variants.isEmpty && (primaryUrl != null || primaryId != null)) {
      variants.add(
        HedraVideoVariant(
          id: primaryId,
          status: _text(map['videoStatus'] ?? map['video_status']) ??
              (primaryUrl == null ? 'processing' : 'completed'),
          videoUrl: primaryUrl,
          previewUrl: _text(
            map['generatedPreviewUrl'] ?? map['generated_preview_url'],
          ),
          reason: _text(map['videoReason'] ?? map['video_reason']),
        ),
      );
    }

    final declaredSize = _integer(map['hedraBatchSize'] ?? map['batch_size']);
    final rawSize = declaredSize ?? variants.length;
    final normalizedSize = rawSize < 1 ? 1 : (rawSize > 8 ? 8 : rawSize);
    return HedraVideoBatch(
      batchGenerationId: _text(
        map['hedraBatchGenerationId'] ?? map['batch_generation_id'],
      ),
      requestedSize: normalizedSize,
      variants: List.unmodifiable(variants),
    );
  }

  static List<dynamic> _list(Object? value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } on FormatException {
        return const [];
      }
    }
    return const [];
  }
}

String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _integer(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
