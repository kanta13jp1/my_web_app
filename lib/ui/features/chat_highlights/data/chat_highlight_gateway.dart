import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/chat_highlight_models.dart';

abstract class ChatHighlightGateway {
  Future<ChatHighlightSnapshot> load();

  Future<void> save(ChatHighlightSnapshot snapshot);
}

class SharedPreferencesChatHighlightGateway implements ChatHighlightGateway {
  SharedPreferencesChatHighlightGateway({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'chat_highlight_snapshot_v1';
  final SharedPreferences? _preferences;

  @override
  Future<ChatHighlightSnapshot> load() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const ChatHighlightSnapshot();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ChatHighlightSnapshot();
      return ChatHighlightSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return const ChatHighlightSnapshot();
    }
  }

  @override
  Future<void> save(ChatHighlightSnapshot snapshot) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) throw StateError('チャットデータの端末内保存に失敗しました。');
  }
}
