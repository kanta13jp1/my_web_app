import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/voice_audio_downloader.dart';

class VoiceDubbingLanguage {
  final String code;
  final String label;

  const VoiceDubbingLanguage(this.code, this.label);
}

class VoiceDubbingModel {
  final String id;
  final String label;
  final String description;
  final int maxCharacters;
  final Set<String>? supportedLanguageCodes;

  const VoiceDubbingModel({
    required this.id,
    required this.label,
    required this.description,
    required this.maxCharacters,
    this.supportedLanguageCodes,
  });

  bool supports(VoiceDubbingLanguage language) =>
      supportedLanguageCodes == null ||
      supportedLanguageCodes!.contains(language.code);
}

const voiceDubbingLanguages = <VoiceDubbingLanguage>[
  VoiceDubbingLanguage('af', 'アフリカーンス語'),
  VoiceDubbingLanguage('ar', 'アラビア語'),
  VoiceDubbingLanguage('hy', 'アルメニア語'),
  VoiceDubbingLanguage('as', 'アッサム語'),
  VoiceDubbingLanguage('az', 'アゼルバイジャン語'),
  VoiceDubbingLanguage('be', 'ベラルーシ語'),
  VoiceDubbingLanguage('bn', 'ベンガル語'),
  VoiceDubbingLanguage('bs', 'ボスニア語'),
  VoiceDubbingLanguage('bg', 'ブルガリア語'),
  VoiceDubbingLanguage('ca', 'カタルーニャ語'),
  VoiceDubbingLanguage('ceb', 'セブアノ語'),
  VoiceDubbingLanguage('ny', 'チェワ語'),
  VoiceDubbingLanguage('zh', '中国語'),
  VoiceDubbingLanguage('hr', 'クロアチア語'),
  VoiceDubbingLanguage('cs', 'チェコ語'),
  VoiceDubbingLanguage('da', 'デンマーク語'),
  VoiceDubbingLanguage('nl', 'オランダ語'),
  VoiceDubbingLanguage('en', '英語'),
  VoiceDubbingLanguage('et', 'エストニア語'),
  VoiceDubbingLanguage('fil', 'フィリピン語'),
  VoiceDubbingLanguage('fi', 'フィンランド語'),
  VoiceDubbingLanguage('fr', 'フランス語'),
  VoiceDubbingLanguage('gl', 'ガリシア語'),
  VoiceDubbingLanguage('ka', 'ジョージア語'),
  VoiceDubbingLanguage('de', 'ドイツ語'),
  VoiceDubbingLanguage('el', 'ギリシャ語'),
  VoiceDubbingLanguage('gu', 'グジャラート語'),
  VoiceDubbingLanguage('ha', 'ハウサ語'),
  VoiceDubbingLanguage('he', 'ヘブライ語'),
  VoiceDubbingLanguage('hi', 'ヒンディー語'),
  VoiceDubbingLanguage('hu', 'ハンガリー語'),
  VoiceDubbingLanguage('is', 'アイスランド語'),
  VoiceDubbingLanguage('id', 'インドネシア語'),
  VoiceDubbingLanguage('ga', 'アイルランド語'),
  VoiceDubbingLanguage('it', 'イタリア語'),
  VoiceDubbingLanguage('ja', '日本語'),
  VoiceDubbingLanguage('jv', 'ジャワ語'),
  VoiceDubbingLanguage('kn', 'カンナダ語'),
  VoiceDubbingLanguage('kk', 'カザフ語'),
  VoiceDubbingLanguage('ky', 'キルギス語'),
  VoiceDubbingLanguage('ko', '韓国語'),
  VoiceDubbingLanguage('lv', 'ラトビア語'),
  VoiceDubbingLanguage('ln', 'リンガラ語'),
  VoiceDubbingLanguage('lt', 'リトアニア語'),
  VoiceDubbingLanguage('lb', 'ルクセンブルク語'),
  VoiceDubbingLanguage('mk', 'マケドニア語'),
  VoiceDubbingLanguage('ms', 'マレー語'),
  VoiceDubbingLanguage('ml', 'マラヤーラム語'),
  VoiceDubbingLanguage('mr', 'マラーティー語'),
  VoiceDubbingLanguage('ne', 'ネパール語'),
  VoiceDubbingLanguage('no', 'ノルウェー語'),
  VoiceDubbingLanguage('ps', 'パシュトー語'),
  VoiceDubbingLanguage('fa', 'ペルシャ語'),
  VoiceDubbingLanguage('pl', 'ポーランド語'),
  VoiceDubbingLanguage('pt', 'ポルトガル語'),
  VoiceDubbingLanguage('pa', 'パンジャーブ語'),
  VoiceDubbingLanguage('ro', 'ルーマニア語'),
  VoiceDubbingLanguage('ru', 'ロシア語'),
  VoiceDubbingLanguage('sr', 'セルビア語'),
  VoiceDubbingLanguage('sd', 'シンド語'),
  VoiceDubbingLanguage('sk', 'スロバキア語'),
  VoiceDubbingLanguage('sl', 'スロベニア語'),
  VoiceDubbingLanguage('so', 'ソマリ語'),
  VoiceDubbingLanguage('es', 'スペイン語'),
  VoiceDubbingLanguage('sw', 'スワヒリ語'),
  VoiceDubbingLanguage('sv', 'スウェーデン語'),
  VoiceDubbingLanguage('ta', 'タミル語'),
  VoiceDubbingLanguage('te', 'テルグ語'),
  VoiceDubbingLanguage('th', 'タイ語'),
  VoiceDubbingLanguage('tr', 'トルコ語'),
  VoiceDubbingLanguage('uk', 'ウクライナ語'),
  VoiceDubbingLanguage('ur', 'ウルドゥー語'),
  VoiceDubbingLanguage('vi', 'ベトナム語'),
  VoiceDubbingLanguage('cy', 'ウェールズ語'),
];

const _multilingualLanguageCodes = <String>{
  'ar',
  'bg',
  'zh',
  'hr',
  'cs',
  'da',
  'nl',
  'en',
  'fil',
  'fi',
  'fr',
  'de',
  'el',
  'hi',
  'id',
  'it',
  'ja',
  'ko',
  'ms',
  'pl',
  'pt',
  'ro',
  'ru',
  'sk',
  'es',
  'sv',
  'ta',
  'tr',
  'uk',
};

const voiceDubbingModels = <VoiceDubbingModel>[
  VoiceDubbingModel(
    id: 'eleven_v3',
    label: 'Expressive 70+',
    description: '70以上の言語と豊かな感情表現。1回15,000文字まで。',
    maxCharacters: 15000,
  ),
  VoiceDubbingModel(
    id: 'eleven_multilingual_v2',
    label: 'Long-form Quality',
    description: '長文の声質と抑揚が安定。29言語、1回30,000文字まで。',
    maxCharacters: 30000,
    supportedLanguageCodes: _multilingualLanguageCodes,
  ),
  VoiceDubbingModel(
    id: 'eleven_flash_v2_5',
    label: 'Fast Long-form',
    description: '高速・低コスト。32言語、1回40,000文字まで。',
    maxCharacters: 40000,
    supportedLanguageCodes: {..._multilingualLanguageCodes, 'hu', 'no', 'vi'},
  ),
];

class VoiceOption {
  final String id;
  final String name;
  final String category;
  final String description;
  final String previewUrl;
  final String publicOwnerId;
  final Map<String, String> labels;

  const VoiceOption({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.previewUrl,
    required this.labels,
    this.publicOwnerId = '',
  });

  factory VoiceOption.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final labels = <String, String>{};
    if (rawLabels is Map) {
      for (final entry in rawLabels.entries) {
        labels[entry.key.toString()] = entry.value.toString();
      }
    }
    return VoiceOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Voice',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      previewUrl: json['preview_url']?.toString() ?? '',
      publicOwnerId: json['public_owner_id']?.toString() ?? '',
      labels: labels,
    );
  }
}

class VoiceCatalogPage {
  final List<VoiceOption> voices;
  final bool hasMore;
  final String? nextPageToken;
  final int totalCount;

  const VoiceCatalogPage({
    required this.voices,
    required this.hasMore,
    required this.nextPageToken,
    required this.totalCount,
  });
}

class VoiceUsage {
  final String tier;
  final int used;
  final int limit;
  final int remaining;
  final int generationCount;
  final int generationLimit;

  const VoiceUsage({
    required this.tier,
    required this.used,
    required this.limit,
    required this.remaining,
    this.generationCount = 0,
    this.generationLimit = 0,
  });

  factory VoiceUsage.fromJson(Map<String, dynamic> json) => VoiceUsage(
        tier: json['tier']?.toString() ?? 'free',
        used: _asInt(json['used']),
        limit: _asInt(json['limit']),
        remaining: _asInt(json['remaining']),
        generationCount: _asInt(json['generation_count']),
        generationLimit: _asInt(json['generation_limit']),
      );
}

class VoiceDubbingRequest {
  final String idempotencyKey;
  final String text;
  final String fileName;
  final VoiceDubbingModel model;
  final VoiceDubbingLanguage language;
  final VoiceOption voice;
  final double stability;
  final double similarityBoost;
  final double style;
  final double speed;
  final bool speakerBoost;

  VoiceDubbingRequest({
    String? idempotencyKey,
    required this.text,
    required this.fileName,
    required this.model,
    required this.language,
    required this.voice,
    required this.stability,
    required this.similarityBoost,
    required this.style,
    required this.speed,
    required this.speakerBoost,
  }) : idempotencyKey = idempotencyKey ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'action': 'voice.dubbing.generate',
        'idempotency_key': idempotencyKey,
        'text': text,
        'file_name': fileName,
        'model_id': model.id,
        'language': language.code,
        'voice_id': voice.id,
        'voice_settings': {
          'stability': stability,
          'similarity_boost': similarityBoost,
          'style': style,
          'speed': speed,
          'use_speaker_boost': speakerBoost,
        },
      };
}

class VoiceDubbingResult {
  final String audioUrl;
  final String storagePath;
  final String fileName;
  final int characterCount;
  final int chunkCount;
  final DateTime? expiresAt;
  final VoiceUsage usage;

  const VoiceDubbingResult({
    required this.audioUrl,
    required this.storagePath,
    required this.fileName,
    required this.characterCount,
    required this.chunkCount,
    required this.expiresAt,
    required this.usage,
  });

  factory VoiceDubbingResult.fromJson(Map<String, dynamic> json) =>
      VoiceDubbingResult(
        audioUrl: json['audio_url']?.toString() ?? '',
        storagePath: json['storage_path']?.toString() ?? '',
        fileName: json['file_name']?.toString() ?? 'multilingual-dubbing.mp3',
        characterCount: _asInt(json['character_count']),
        chunkCount: _asInt(json['chunk_count']),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
        usage: VoiceUsage.fromJson(
          Map<String, dynamic>.from(json['usage'] as Map? ?? const {}),
        ),
      );
}

abstract interface class VoiceDubbingApi {
  Future<VoiceCatalogPage> loadVoices({String search, String? pageToken});
  Future<VoiceUsage> loadUsage();
  Future<VoiceDubbingResult> generate(VoiceDubbingRequest request);
  Future<void> previewVoice(VoiceOption voice);
  Future<void> preview(VoiceDubbingResult result);
  Future<void> download(VoiceDubbingResult result);
  Future<void> dispose();
}

class SupabaseVoiceDubbingService implements VoiceDubbingApi {
  final SupabaseClient _client;
  final AudioPlayer _audioPlayer;

  SupabaseVoiceDubbingService({
    SupabaseClient? client,
    AudioPlayer? audioPlayer,
  })  : _client = client ?? Supabase.instance.client,
        _audioPlayer = audioPlayer ?? AudioPlayer();

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('ai-hub', body: body);
    if (response.data is! Map) throw StateError('Invalid ai-hub response');
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<VoiceCatalogPage> loadVoices({
    String search = '',
    String? pageToken,
  }) async {
    final data = await _invoke({
      'action': 'voice.catalog',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (pageToken != null && pageToken.isNotEmpty) 'page_token': pageToken,
    });
    final voices = (data['voices'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => VoiceOption.fromJson(Map<String, dynamic>.from(item)))
        .where((voice) => voice.id.isNotEmpty)
        .toList();
    return VoiceCatalogPage(
      voices: voices,
      hasMore: data['has_more'] == true,
      nextPageToken: data['next_page_token']?.toString(),
      totalCount: _asInt(data['total_count']),
    );
  }

  @override
  Future<VoiceUsage> loadUsage() async {
    final data = await _invoke({'action': 'voice.usage'});
    return VoiceUsage.fromJson(
      Map<String, dynamic>.from(data['usage'] as Map? ?? const {}),
    );
  }

  @override
  Future<VoiceDubbingResult> generate(VoiceDubbingRequest request) async {
    final data = await _invoke(request.toJson());
    return VoiceDubbingResult.fromJson(data);
  }

  @override
  Future<void> preview(VoiceDubbingResult result) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(result.audioUrl));
  }

  @override
  Future<void> previewVoice(VoiceOption voice) async {
    if (voice.previewUrl.isEmpty) return;
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(voice.previewUrl));
  }

  @override
  Future<void> download(VoiceDubbingResult result) async {
    final Uint8List bytes = await _client.storage
        .from('voice-dubbing')
        .download(result.storagePath);
    downloadVoiceAudio(bytes, result.fileName);
  }

  @override
  Future<void> dispose() => _audioPlayer.dispose();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
