import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ChatIncrementalBufferUnit { word, paragraph }

enum ChatIncrementalAnimationStyle { fade, blur, none }

class ChatIncrementalRenderingConfig {
  static const String prefsKey = 'chat_incremental_rendering_config_v1';

  final bool enabled;
  final ChatIncrementalAnimationStyle animationStyle;
  final ChatIncrementalBufferUnit bufferUnit;
  final int chunkDelayMs;

  const ChatIncrementalRenderingConfig({
    this.enabled = true,
    this.animationStyle = ChatIncrementalAnimationStyle.fade,
    this.bufferUnit = ChatIncrementalBufferUnit.word,
    this.chunkDelayMs = 40,
  });

  ChatIncrementalRenderingConfig copyWith({
    bool? enabled,
    ChatIncrementalAnimationStyle? animationStyle,
    ChatIncrementalBufferUnit? bufferUnit,
    int? chunkDelayMs,
  }) {
    return ChatIncrementalRenderingConfig(
      enabled: enabled ?? this.enabled,
      animationStyle: animationStyle ?? this.animationStyle,
      bufferUnit: bufferUnit ?? this.bufferUnit,
      chunkDelayMs: chunkDelayMs ?? this.chunkDelayMs,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'animation_style': animationStyle.name,
      'buffer_unit': bufferUnit.name,
      'chunk_delay_ms': chunkDelayMs,
    };
  }

  factory ChatIncrementalRenderingConfig.fromJson(Map<String, dynamic> json) {
    final styleName = json['animation_style']?.toString() ?? 'fade';
    final unitName = json['buffer_unit']?.toString() ?? 'word';
    final style = ChatIncrementalAnimationStyle.values.firstWhere(
      (item) => item.name == styleName,
      orElse: () => ChatIncrementalAnimationStyle.fade,
    );
    final unit = ChatIncrementalBufferUnit.values.firstWhere(
      (item) => item.name == unitName,
      orElse: () => ChatIncrementalBufferUnit.word,
    );
    final delay = ((json['chunk_delay_ms'] as num?)?.toInt() ?? 40).clamp(
      10,
      2000,
    );
    return ChatIncrementalRenderingConfig(
      enabled: json['enabled'] != false,
      animationStyle: style,
      bufferUnit: unit,
      chunkDelayMs: delay,
    );
  }

  static Future<ChatIncrementalRenderingConfig> loadFromPrefs({
    String key = prefsKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return const ChatIncrementalRenderingConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ChatIncrementalRenderingConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return ChatIncrementalRenderingConfig.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
      return const ChatIncrementalRenderingConfig();
    } catch (_) {
      return const ChatIncrementalRenderingConfig();
    }
  }

  static Future<void> saveToPrefs(
    ChatIncrementalRenderingConfig config, {
    String key = prefsKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(config.toJson()));
  }
}

List<String> splitIncrementalBlocks(
  String text,
  ChatIncrementalBufferUnit unit,
) {
  if (text.isEmpty) {
    return const <String>[];
  }
  switch (unit) {
    case ChatIncrementalBufferUnit.paragraph:
      final matches = RegExp(r'[^\n]+(?:\n+|$)').allMatches(text);
      final chunks = matches
          .map((match) => match.group(0) ?? '')
          .where((chunk) => chunk.isNotEmpty)
          .toList(growable: false);
      return chunks.isEmpty ? <String>[text] : chunks;
    case ChatIncrementalBufferUnit.word:
      // Split ASCII/Latin words with trailing whitespace OR CJK runs in 4-char
      // chunks so Japanese replies stream smoothly without single-char jitter.
      final pattern = RegExp(
        r'[A-Za-z0-9_.,!?:;/\\-]+(?:\s+|$)|\s+|[\u3000-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]{1,4}|.',
      );
      final chunks = pattern
          .allMatches(text)
          .map((match) => match.group(0) ?? '')
          .where((chunk) => chunk.isNotEmpty)
          .toList(growable: false);
      return chunks.isEmpty ? <String>[text] : chunks;
  }
}
