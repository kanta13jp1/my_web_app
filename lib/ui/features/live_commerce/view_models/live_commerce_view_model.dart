import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../services/shop_service.dart';
import '../data/live_commerce_gateway.dart';
import '../domain/live_commerce_models.dart';

enum LiveCommerceLoadStatus { initial, loading, ready, failure }

class LiveCommerceViewModel extends ChangeNotifier {
  LiveCommerceViewModel({
    required LiveCommerceGateway gateway,
    required ShopGateway shopGateway,
    required this.roomId,
    this.preferredProductId,
  })  : _gateway = gateway,
        _shopGateway = shopGateway;

  final LiveCommerceGateway _gateway;
  final ShopGateway _shopGateway;
  final String roomId;
  final String? preferredProductId;

  StreamSubscription<LiveCommerceEvent>? _subscription;
  LiveCommerceLoadStatus _loadStatus = LiveCommerceLoadStatus.initial;
  LiveCommerceConnectionState _connectionState =
      LiveCommerceConnectionState.preview;
  LiveCommerceRoomSnapshot? _snapshot;
  ShopProduct? _featuredProduct;
  String _questionDraft = '';
  bool _isSendingQuestion = false;
  bool _isHostActionRunning = false;
  bool _isResyncing = false;
  bool _disposed = false;
  int _connectionGeneration = 0;
  String? _notice;
  String? _errorMessage;

  LiveCommerceLoadStatus get loadStatus => _loadStatus;
  LiveCommerceConnectionState get connectionState => _connectionState;
  LiveCommerceRoomSnapshot? get snapshot => _snapshot;
  ShopProduct? get featuredProduct => _featuredProduct;
  String get questionDraft => _questionDraft;
  bool get isSendingQuestion => _isSendingQuestion;
  bool get isHostActionRunning => _isHostActionRunning;
  String? get notice => _notice;
  String? get errorMessage => _errorMessage;
  bool get canSendQuestion =>
      !_isSendingQuestion && _questionDraft.trim().isNotEmpty;

  Future<void> load() async {
    _loadStatus = LiveCommerceLoadStatus.loading;
    _errorMessage = null;
    _safeNotify();
    try {
      final room = await _gateway.loadRoom(
        roomId,
        preferredProductId: preferredProductId,
      );
      _snapshot = room;
      await _loadFeaturedProduct(room.featuredProductId);
      if (_disposed) return;
      _loadStatus = LiveCommerceLoadStatus.ready;
      await connectRealtime();
    } catch (error) {
      if (_disposed) return;
      _loadStatus = LiveCommerceLoadStatus.failure;
      _errorMessage = _friendlyError(error);
      _safeNotify();
    }
  }

  Future<void> connectRealtime() async {
    final generation = ++_connectionGeneration;
    await _subscription?.cancel();
    if (_disposed || generation != _connectionGeneration) return;
    final current = _snapshot;
    if (current == null) return;
    if (_gateway.isPreview) {
      _connectionState = LiveCommerceConnectionState.preview;
      _safeNotify();
      return;
    }
    _connectionState = LiveCommerceConnectionState.connecting;
    _notice = null;
    _safeNotify();
    _subscription = _gateway
        .watchEvents(roomId, afterSequence: current.lastSequence)
        .listen(
      (event) {
        if (generation != _connectionGeneration || _disposed) return;
        unawaited(_applyEvent(event, connectionGeneration: generation));
      },
      onError: (_) {
        if (generation != _connectionGeneration || _disposed) return;
        _connectionState = LiveCommerceConnectionState.degraded;
        _notice = 'ライブ更新が一時停止しています。表示内容は最後の同期時点です。';
        _safeNotify();
      },
      onDone: () {
        if (generation != _connectionGeneration || _disposed) return;
        _connectionState = LiveCommerceConnectionState.degraded;
        _notice = 'ライブ更新が終了しました。再接続してください。';
        _safeNotify();
      },
    );
  }

  Future<void> reconnect() async {
    if (_gateway.isPreview) {
      await connectRealtime();
      return;
    }
    await _resyncSnapshot();
  }

  void setQuestionDraft(String value) {
    if (_questionDraft == value) return;
    _questionDraft = String.fromCharCodes(value.runes.take(280));
    _safeNotify();
  }

  Future<bool> sendQuestion() async {
    if (!canSendQuestion || _snapshot == null) return false;
    _isSendingQuestion = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final event = await _gateway.sendQuestion(
        roomId: roomId,
        body: _questionDraft.trim(),
      );
      await _applyEvent(event);
      _questionDraft = '';
      _notice =
          _gateway.isPreview ? 'プレビュー内に質問を追加しました。本番には送信されていません。' : '質問を送信しました。';
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSendingQuestion = false;
      _safeNotify();
    }
  }

  Future<void> setQuestionHighlighted(LiveCommerceQuestion question) async {
    if (_snapshot?.role != LiveCommerceRole.host || _isHostActionRunning) {
      return;
    }
    _isHostActionRunning = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final event = await _gateway.setQuestionHighlighted(
        roomId: roomId,
        questionId: question.id,
        highlighted: !question.isHighlighted,
      );
      await _applyEvent(event);
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isHostActionRunning = false;
      _safeNotify();
    }
  }

  Future<void> pushFeaturedProduct() async {
    final product = _featuredProduct;
    if (_snapshot?.role != LiveCommerceRole.host ||
        _isHostActionRunning ||
        product == null) {
      return;
    }
    _isHostActionRunning = true;
    _errorMessage = null;
    _safeNotify();
    try {
      final event = await _gateway.pushProduct(
        roomId: roomId,
        productId: product.id,
      );
      await _applyEvent(event);
      _notice = '商品紹介を更新しました。';
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isHostActionRunning = false;
      _safeNotify();
    }
  }

  Future<void> _applyEvent(
    LiveCommerceEvent event, {
    int? connectionGeneration,
  }) async {
    if (_disposed ||
        (connectionGeneration != null &&
            connectionGeneration != _connectionGeneration)) {
      return;
    }
    final current = _snapshot;
    if (current == null) return;
    final next = LiveCommerceEventReducer.apply(current, event);
    _snapshot = next;
    if (next.needsResync) {
      _connectionState = LiveCommerceConnectionState.syncing;
      _notice = next.syncMessage;
    } else if (!_gateway.isPreview) {
      _connectionState = LiveCommerceConnectionState.connected;
    }
    if (next.featuredProductId != current.featuredProductId) {
      await _loadFeaturedProduct(next.featuredProductId);
    }
    _safeNotify();
    if (next.needsResync) unawaited(_resyncSnapshot());
  }

  Future<void> _resyncSnapshot() async {
    if (_disposed || _isResyncing || _gateway.isPreview) return;
    _isResyncing = true;
    ++_connectionGeneration;
    await _subscription?.cancel();
    if (_disposed) return;
    _connectionState = LiveCommerceConnectionState.syncing;
    _notice = '最新のライブ情報を再同期しています。';
    _safeNotify();
    try {
      final room = await _gateway.loadRoom(
        roomId,
        preferredProductId: preferredProductId,
      );
      if (_disposed) return;
      _snapshot = room;
      await _loadFeaturedProduct(room.featuredProductId);
      if (_disposed) return;
      _isResyncing = false;
      await connectRealtime();
    } catch (error) {
      if (_disposed) return;
      _connectionState = LiveCommerceConnectionState.degraded;
      _errorMessage = _friendlyError(error);
      _notice = '再同期できませんでした。表示内容は最後の同期時点です。';
      _safeNotify();
    } finally {
      _isResyncing = false;
    }
  }

  Future<void> _loadFeaturedProduct(String? productId) async {
    if (productId == null || productId.trim().isEmpty) {
      _featuredProduct = null;
      return;
    }
    final product = await _shopGateway.fetchProduct(productId);
    if (!_disposed) _featuredProduct = product;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is LiveCommerceException) return error.message;
    if (error is ShopException) return error.message;
    return 'ライブコマースを更新できませんでした。接続を確認して再試行してください。';
  }

  @override
  void dispose() {
    _disposed = true;
    ++_connectionGeneration;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
