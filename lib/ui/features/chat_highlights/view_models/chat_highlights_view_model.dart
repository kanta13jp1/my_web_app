import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/chat_highlight_export_gateway.dart';
import '../data/chat_highlight_gateway.dart';
import '../domain/chat_highlight_models.dart';
import '../domain/detect_chat_highlights.dart';

enum ChatHighlightsLoadStatus { initial, loading, ready, failure }

class ChatHighlightsViewModel extends ChangeNotifier {
  ChatHighlightsViewModel({
    required ChatHighlightGateway gateway,
    required ChatHighlightExportGateway exportGateway,
    DetectChatHighlights detector = const DetectChatHighlights(),
    DateTime Function()? now,
  })  : _gateway = gateway,
        _exportGateway = exportGateway,
        _detector = detector,
        _now = now ?? DateTime.now;

  static const maximumEvents = 500;

  final ChatHighlightGateway _gateway;
  final ChatHighlightExportGateway _exportGateway;
  final DetectChatHighlights _detector;
  final DateTime Function() _now;

  ChatHighlightsLoadStatus loadStatus = ChatHighlightsLoadStatus.initial;
  ChatHighlightSnapshot snapshot = const ChatHighlightSnapshot();
  List<ChatHighlightCandidate> candidates = const <ChatHighlightCandidate>[];
  String? errorMessage;
  String? noticeMessage;
  Future<void> _saveTail = Future<void>.value();
  var _idSequence = 0;
  var _disposed = false;

  Future<void> load() async {
    loadStatus = ChatHighlightsLoadStatus.loading;
    _notify();
    try {
      snapshot = await _gateway.load();
      _sortAndAnalyze();
      loadStatus = ChatHighlightsLoadStatus.ready;
    } catch (error) {
      errorMessage = '保存済みチャットを読み込めませんでした: $error';
      loadStatus = ChatHighlightsLoadStatus.failure;
    }
    _notify();
  }

  Future<bool> updateSource({
    required String title,
    required String url,
  }) async {
    final parsed = url.trim().isEmpty ? null : Uri.tryParse(url.trim());
    if (parsed != null && parsed.scheme != 'https' && parsed.scheme != 'http') {
      _setError('動画URLは http:// または https:// で入力してください。');
      return false;
    }
    snapshot = snapshot.copyWith(
      sourceTitle: title.trim(),
      sourceVideoUrl: url.trim(),
    );
    return _persist('配信情報を保存しました。');
  }

  Future<bool> updateSettings(ChatHighlightSettings settings) async {
    if (settings.windowSeconds <= 0 ||
        settings.minimumComments <= 0 ||
        settings.minimumKeywordEvents <= 0 ||
        settings.preRollSeconds < 0 ||
        settings.postRollSeconds < 0) {
      _setError('集計窓と閾値は1以上、前後余白は0以上で指定してください。');
      return false;
    }
    final keywords = settings.keywords
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toSet()
        .toList(growable: false);
    snapshot = snapshot.copyWith(
      settings: settings.copyWith(keywords: keywords),
    );
    _sortAndAnalyze();
    return _persist('判定条件を更新し、候補を再計算しました。');
  }

  Future<bool> addEvent({
    required Duration offset,
    required String author,
    required String message,
  }) async {
    if (offset < Duration.zero) {
      _setError('時刻は0秒以上で入力してください。');
      return false;
    }
    if (message.trim().isEmpty) {
      _setError('コメント本文を入力してください。');
      return false;
    }
    final event = ChatHighlightEvent(
      id: '${_now().microsecondsSinceEpoch}-${_idSequence++}',
      offset: offset,
      author: author.trim().isEmpty ? '匿名' : author.trim(),
      message: message.trim(),
    );
    final events = <ChatHighlightEvent>[...snapshot.events, event]
      ..sort((left, right) {
        final order = left.offset.compareTo(right.offset);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
    if (events.length > maximumEvents) {
      events.removeRange(0, events.length - maximumEvents);
    }
    snapshot = snapshot.copyWith(events: events);
    _sortAndAnalyze();
    return _persist('コメントを時系列へ追加しました。');
  }

  Future<void> addDemoEvents() async {
    final base = _now().microsecondsSinceEpoch;
    final sequence = _idSequence++;
    final demo = <ChatHighlightEvent>[
      ChatHighlightEvent(
        id: '$base-$sequence-demo-1',
        offset: const Duration(minutes: 1, seconds: 2),
        author: 'viewer_a',
        message: 'ここすごい！',
      ),
      ChatHighlightEvent(
        id: '$base-$sequence-demo-2',
        offset: const Duration(minutes: 1, seconds: 8),
        author: 'viewer_b',
        message: '神展開',
      ),
      ChatHighlightEvent(
        id: '$base-$sequence-demo-3',
        offset: const Duration(minutes: 1, seconds: 13),
        author: 'viewer_c',
        message: '笑笑',
      ),
      ChatHighlightEvent(
        id: '$base-$sequence-demo-4',
        offset: const Duration(minutes: 1, seconds: 17),
        author: 'viewer_d',
        message: 'もう一回見たい',
      ),
    ];
    snapshot = snapshot.copyWith(
      events: <ChatHighlightEvent>[...snapshot.events, ...demo],
    );
    _sortAndAnalyze();
    await _persist('デモコメント4件を追加しました。');
  }

  Future<void> removeEvent(String id) async {
    snapshot = snapshot.copyWith(
      events: snapshot.events.where((event) => event.id != id).toList(),
    );
    _sortAndAnalyze();
    await _persist('コメントを削除しました。');
  }

  Future<void> clearEvents() async {
    snapshot = snapshot.copyWith(events: const <ChatHighlightEvent>[]);
    _sortAndAnalyze();
    await _persist('チャット履歴を消去しました。');
  }

  Future<bool> exportManifest() async {
    if (candidates.isEmpty) {
      _setError('出力できるハイライト候補がありません。');
      return false;
    }
    final uri = Uri.tryParse(snapshot.sourceVideoUrl);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      _setError('編集元となる有効な動画URLを保存してください。');
      return false;
    }
    try {
      await _exportGateway.export(snapshot: snapshot, candidates: candidates);
      errorMessage = null;
      noticeMessage = '編集用クリップ指示書（JSON）を出力しました。';
      _notify();
      return true;
    } catch (error) {
      _setError('クリップ指示書を出力できませんでした: $error');
      return false;
    }
  }

  void _sortAndAnalyze() {
    final sorted = snapshot.events.toList()
      ..sort((left, right) {
        final order = left.offset.compareTo(right.offset);
        return order != 0 ? order : left.id.compareTo(right.id);
      });
    snapshot = snapshot.copyWith(events: sorted);
    candidates = _detector(sorted, snapshot.settings);
  }

  Future<bool> _persist(String notice) async {
    errorMessage = null;
    noticeMessage = notice;
    final value = snapshot;
    _saveTail =
        _saveTail.catchError((Object _) {}).then((_) => _gateway.save(value));
    try {
      await _saveTail;
      _notify();
      return true;
    } catch (error) {
      _setError('変更を端末へ保存できませんでした: $error');
      return false;
    }
  }

  void _setError(String message) {
    errorMessage = message;
    noticeMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
