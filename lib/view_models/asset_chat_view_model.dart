import 'package:flutter/foundation.dart';

import '../models/asset_chat.dart';
import '../services/ai_hub_chat_service.dart';

class AssetChatViewModel extends ChangeNotifier {
  AssetChatViewModel({required AiHubChatService service}) : _service = service;

  final AiHubChatService _service;
  final List<AssetChatMessage> _messages = <AssetChatMessage>[];

  String? _threadId;
  String? _threadTitle;
  String? _errorMessage;
  bool _isSending = false;

  List<AssetChatMessage> get messages =>
      List<AssetChatMessage>.unmodifiable(_messages);
  String? get threadId => _threadId;
  String? get threadTitle => _threadTitle;
  String? get errorMessage => _errorMessage;
  bool get isSending => _isSending;

  Future<bool> sendMessage(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty || _isSending) {
      return false;
    }

    _messages.add(
      AssetChatMessage(role: AssetChatMessageRole.user, text: normalized),
    );
    _errorMessage = null;
    _isSending = true;
    notifyListeners();

    try {
      final response = await _service.sendAssetChat(
        message: normalized,
        threadId: _threadId,
      );
      _threadId = response.threadId;
      _threadTitle = response.threadTitle;
      _messages.add(
        AssetChatMessage(
          role: AssetChatMessageRole.assistant,
          text: response.reply,
          usage: response.usage,
        ),
      );
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final detail = error.toString().toLowerCase();
    if (detail.contains('login_required') ||
        detail.contains('unauthorized') ||
        detail.contains('jwt')) {
      return 'このAIチャットを使うにはログインしてください。';
    }
    if (detail.contains('quota') ||
        detail.contains('rate limit') ||
        detail.contains('429')) {
      return 'AIが混み合っています。1分ほど待ってからもう一度お試しください。';
    }
    if (detail.contains('offline')) {
      return 'オフライン保護設定によりAI送信が停止されています。設定を確認してください。';
    }
    return 'AIとの通信に失敗しました。時間をおいてもう一度お試しください。';
  }
}
