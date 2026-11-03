import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/ui/features/live_commerce/data/live_commerce_gateway.dart';
import 'package:my_web_app/ui/features/live_commerce/domain/live_commerce_models.dart';
import 'package:my_web_app/ui/features/live_commerce/view_models/live_commerce_view_model.dart';

void main() {
  test('sequence gap reloads a snapshot before resubscribing', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2, 4]);
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: _FakeShopGateway(),
      roomId: 'room-1',
    );
    addTearDown(() async {
      viewModel.dispose();
      await gateway.close();
    });

    await viewModel.load();
    expect(gateway.watchAfterSequences, <int>[2]);

    gateway.add(
      LiveCommerceEvent(
        id: 'event-4',
        roomId: 'room-1',
        sequence: 4,
        type: LiveCommerceEventType.productPushed,
        occurredAt: DateTime(2026, 8, 26, 12),
        productId: 'product-1',
      ),
    );
    await _flushAsyncWork();

    expect(gateway.loadCalls, 2);
    expect(gateway.watchAfterSequences, <int>[2, 4]);
    expect(viewModel.snapshot?.lastSequence, 4);
    expect(viewModel.connectionState, LiveCommerceConnectionState.connecting);
  });

  test('late product response cannot replace the latest selection', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2]);
    final shop = _DelayedShopGateway();
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: shop,
      roomId: 'room-1',
    );
    addTearDown(() async {
      viewModel.dispose();
      await gateway.close();
    });
    await viewModel.load();
    LiveCommerceEvent event(int sequence, String productId) => LiveCommerceEvent(
          id: 'event-$sequence',
          roomId: 'room-1',
          sequence: sequence,
          type: LiveCommerceEventType.productPushed,
          occurredAt: DateTime(2026, 8, 26, 12),
          productId: productId,
        );
    gateway.add(event(3, 'product-a'));
    gateway.add(event(4, 'product-b'));
    await _flushAsyncWork();
    expect(viewModel.snapshot?.featuredProductId, 'product-b');
    expect(viewModel.featuredProduct, isNull);
    shop.pending['product-b']!.complete(shop.makeProduct('product-b'));
    await _flushAsyncWork();
    expect(viewModel.featuredProduct?.id, 'product-b');
    shop.pending['product-a']!.complete(shop.makeProduct('product-a'));
    await _flushAsyncWork();
    expect(viewModel.featuredProduct?.id, 'product-b');
  });

  test('resync prevents an old product response replacing the snapshot', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2, 4]);
    final shop = _DelayedShopGateway();
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: shop,
      roomId: 'room-1',
    );
    addTearDown(() async {
      viewModel.dispose();
      await gateway.close();
    });
    await viewModel.load();
    gateway.add(_productEvent(3, 'product-a'));
    await _flushAsyncWork();
    gateway.add(_productEvent(5, 'product-b'));
    await _flushAsyncWork();
    expect(viewModel.snapshot?.featuredProductId, 'product-1');
    shop.pending['product-a']!.complete(shop.makeProduct('product-a'));
    await _flushAsyncWork();
    expect(viewModel.featuredProduct?.id, 'product-1');
  });

  test('late product response after disposal does not notify', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2]);
    final shop = _DelayedShopGateway();
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: shop,
      roomId: 'room-1',
    );
    addTearDown(gateway.close);
    await viewModel.load();
    var notifications = 0;
    viewModel.addListener(() => notifications++);
    gateway.add(_productEvent(3, 'product-a'));
    await _flushAsyncWork();
    viewModel.dispose();
    final before = notifications;
    shop.pending['product-a']!.complete(shop.makeProduct('product-a'));
    await _flushAsyncWork();
    expect(notifications, before);
  });

  test('current product failure clears old product and reports error', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2]);
    final shop = _DelayedShopGateway();
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: shop,
      roomId: 'room-1',
    );
    addTearDown(() async {
      viewModel.dispose();
      await gateway.close();
    });
    await viewModel.load();
    gateway.add(_productEvent(3, 'product-a'));
    await _flushAsyncWork();
    shop.pending['product-a']!.completeError(StateError('unavailable'));
    await _flushAsyncWork();
    expect(viewModel.featuredProduct, isNull);
    expect(viewModel.notice, contains('商品情報を読み込めませんでした'));
    expect(viewModel.errorMessage, isNotNull);
  });

  test('stream completion leaves an honest degraded state', () async {
    final gateway = _ResyncGateway(snapshotSequences: <int>[2]);
    final viewModel = LiveCommerceViewModel(
      gateway: gateway,
      shopGateway: _FakeShopGateway(),
      roomId: 'room-1',
    );
    addTearDown(viewModel.dispose);

    await viewModel.load();
    await gateway.close();
    await _flushAsyncWork();

    expect(viewModel.connectionState, LiveCommerceConnectionState.degraded);
    expect(viewModel.notice, contains('終了'));
  });
}

LiveCommerceEvent _productEvent(int sequence, String productId) =>
    LiveCommerceEvent(
      id: 'event-$sequence',
      roomId: 'room-1',
      sequence: sequence,
      type: LiveCommerceEventType.productPushed,
      occurredAt: DateTime(2026, 8, 26, 12),
      productId: productId,
    );

Future<void> _flushAsyncWork() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ResyncGateway implements LiveCommerceGateway {
  _ResyncGateway({required this.snapshotSequences});

  final List<int> snapshotSequences;
  final StreamController<LiveCommerceEvent> _controller =
      StreamController<LiveCommerceEvent>.broadcast();
  final List<int> watchAfterSequences = <int>[];
  int loadCalls = 0;

  @override
  bool get isPreview => false;

  @override
  Future<LiveCommerceRoomSnapshot> loadRoom(
    String roomId, {
    String? preferredProductId,
  }) async {
    final index = loadCalls < snapshotSequences.length
        ? loadCalls
        : snapshotSequences.length - 1;
    final sequence = snapshotSequences[index];
    loadCalls++;
    return LiveCommerceRoomSnapshot(
      roomId: roomId,
      title: 'ライブ',
      hostName: '配信者',
      role: LiveCommerceRole.viewer,
      isLive: true,
      featuredProductId: 'product-1',
      questions: const <LiveCommerceQuestion>[],
      purchaseAnnouncements: const <String>[],
      lastSequence: sequence,
    );
  }

  @override
  Stream<LiveCommerceEvent> watchEvents(
    String roomId, {
    required int afterSequence,
  }) {
    watchAfterSequences.add(afterSequence);
    return _controller.stream;
  }

  void add(LiveCommerceEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();

  @override
  Future<LiveCommerceEvent> pushProduct({
    required String roomId,
    required String productId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LiveCommerceEvent> sendQuestion({
    required String roomId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LiveCommerceEvent> setQuestionHighlighted({
    required String roomId,
    required String questionId,
    required bool highlighted,
  }) {
    throw UnimplementedError();
  }
}

class _DelayedShopGateway extends _FakeShopGateway {
  final Map<String, Completer<ShopProduct?>> pending = {};

  ShopProduct makeProduct(String id) => ShopProduct(
        id: id,
        nameJa: id,
        summaryJa: '説明',
        priceJpy: 1200,
        version: '1.0.0',
        fileSizeBytes: 1024,
        sha256: 'abc',
        isPurchasable: true,
      );

  @override
  Future<ShopProduct?> fetchProduct(String productId) {
    if (productId == 'product-1') return Future.value(product);
    return (pending[productId] = Completer<ShopProduct?>()).future;
  }
}

class _FakeShopGateway implements ShopGateway {
  final product = const ShopProduct(
    id: 'product-1',
    nameJa: '商品',
    summaryJa: '説明',
    priceJpy: 1200,
    version: '1.0.0',
    fileSizeBytes: 1024,
    sha256: 'abc',
    isPurchasable: true,
  );

  @override
  bool get isSignedIn => true;

  @override
  Future<ShopProduct?> fetchProduct(String productId) async => product;

  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async =>
      <ShopProduct>[product];

  @override
  Future<List<ShopPurchase>> fetchPurchases() async => const <ShopPurchase>[];

  @override
  Future<bool> hasPurchased(String productId) async => false;

  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) {
    throw UnimplementedError();
  }

  @override
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  }) {
    throw UnimplementedError();
  }
}
