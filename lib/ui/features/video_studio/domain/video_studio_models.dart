class VideoGenerationModelOption {
  const VideoGenerationModelOption({
    required this.key,
    required this.name,
    required this.description,
    required this.durations,
    required this.aspectRatios,
    required this.resolutions,
    required this.creditsPerSecond,
  });

  final String key;
  final String name;
  final String description;
  final List<int> durations;
  final List<String> aspectRatios;
  final List<String> resolutions;
  final int creditsPerSecond;

  factory VideoGenerationModelOption.fromJson(Map<String, dynamic> json) {
    return VideoGenerationModelOption(
      key: _string(json['key']),
      name: _string(json['name']),
      description: _string(json['description']),
      durations: _list(json['durations']).map(_integer).toList(growable: false),
      aspectRatios: _list(
        json['aspect_ratios'],
      ).map(_string).toList(growable: false),
      resolutions: _list(
        json['resolutions'],
      ).map(_string).toList(growable: false),
      creditsPerSecond: _integer(json['credits_per_second']),
    );
  }
}

class VideoCreditPackOption {
  const VideoCreditPackOption({
    required this.key,
    required this.name,
    required this.credits,
    required this.amountJpy,
  });

  final String key;
  final String name;
  final int credits;
  final int amountJpy;

  factory VideoCreditPackOption.fromJson(Map<String, dynamic> json) {
    return VideoCreditPackOption(
      key: _string(json['key']),
      name: _string(json['name']),
      credits: _integer(json['credits']),
      amountJpy: _integer(json['amount_jpy']),
    );
  }
}

class VideoStudioCatalog {
  const VideoStudioCatalog({required this.models, required this.creditPacks});

  final List<VideoGenerationModelOption> models;
  final List<VideoCreditPackOption> creditPacks;

  factory VideoStudioCatalog.fromJson(Map<String, dynamic> json) {
    return VideoStudioCatalog(
      models: _list(json['models'])
          .map((value) => VideoGenerationModelOption.fromJson(_map(value)))
          .toList(growable: false),
      creditPacks: _list(json['credit_packs'])
          .map((value) => VideoCreditPackOption.fromJson(_map(value)))
          .toList(growable: false),
    );
  }
}

class VideoCreditBalance {
  const VideoCreditBalance({
    required this.availableCredits,
    required this.reservedCredits,
    required this.creditDebt,
  });

  static const zero = VideoCreditBalance(
    availableCredits: 0,
    reservedCredits: 0,
    creditDebt: 0,
  );

  final int availableCredits;
  final int reservedCredits;
  final int creditDebt;

  factory VideoCreditBalance.fromJson(Map<String, dynamic> json) {
    return VideoCreditBalance(
      availableCredits: _integer(json['available_credits']),
      reservedCredits: _integer(json['reserved_credits']),
      creditDebt: _integer(json['credit_debt']),
    );
  }
}

class VideoGenerationJob {
  const VideoGenerationJob({
    required this.id,
    required this.modelKey,
    required this.prompt,
    required this.durationSeconds,
    required this.aspectRatio,
    required this.resolution,
    required this.status,
    required this.quotedCredits,
    required this.chargedCredits,
    required this.createdAt,
    this.errorCode,
    this.outputUrl,
    this.outputExpiresAt,
    this.completedAt,
  });

  final String id;
  final String modelKey;
  final String prompt;
  final int durationSeconds;
  final String aspectRatio;
  final String resolution;
  final String status;
  final int quotedCredits;
  final int chargedCredits;
  final String? errorCode;
  final Uri? outputUrl;
  final DateTime? outputExpiresAt;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isTerminal =>
      status == 'succeeded' || status == 'failed' || status == 'cancelled';
  bool get isSuccessful => status == 'succeeded';

  factory VideoGenerationJob.fromJson(Map<String, dynamic> json) {
    return VideoGenerationJob(
      id: _string(json['id']),
      modelKey: _string(json['model_key']),
      prompt: _string(json['prompt']),
      durationSeconds: _integer(json['duration_seconds']),
      aspectRatio: _string(json['aspect_ratio']),
      resolution: _string(json['resolution']),
      status: _string(json['status']),
      quotedCredits: _integer(json['quoted_credits']),
      chargedCredits: _integer(json['charged_credits']),
      errorCode: _nullableString(json['error_code']),
      outputUrl: _uri(json['output_url']),
      outputExpiresAt: _date(json['output_expires_at']),
      createdAt:
          _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: _date(json['completed_at']),
    );
  }
}

class VideoCreateResult {
  const VideoCreateResult({required this.job, required this.balance});

  final VideoGenerationJob job;
  final VideoCreditBalance balance;
}

Map<String, dynamic> videoStudioMap(Object? value) => _map(value);

List<dynamic> videoStudioList(Object? value) => _list(value);

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_string(value)) ?? 0;
}

DateTime? _date(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : DateTime.tryParse(text);
}

Uri? _uri(Object? value) {
  final text = _string(value);
  final uri = text.isEmpty ? null : Uri.tryParse(text);
  return uri != null && uri.hasScheme ? uri : null;
}
