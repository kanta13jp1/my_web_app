import 'package:flutter/foundation.dart';

import '../services/shop_service.dart';

/// 公開カタログの取得と種別フィルターだけを担当する。
class ShopCatalogViewModel extends ChangeNotifier {
  ShopCatalogViewModel({required ShopGateway gateway}) : _gateway = gateway;

  final ShopGateway _gateway;

  bool _loading = false;
  String? _error;
  List<ShopProduct> _products = const [];
  ShopProductType? _selectedType;

  bool get loading => _loading;
  String? get error => _error;
  List<ShopProduct> get products => _products;
  ShopProductType? get selectedType => _selectedType;

  List<ShopProduct> get visibleProducts {
    final selected = _selectedType;
    if (selected == null) return _products;
    return _products
        .where((product) => product.type == selected)
        .toList(growable: false);
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _gateway.fetchProducts();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectType(ShopProductType? type) {
    if (_selectedType == type) return;
    _selectedType = type;
    notifyListeners();
  }
}

/// 1商品の購入状態と非同期操作をUIから分離する。
class ShopProductViewModel extends ChangeNotifier {
  ShopProductViewModel({required ShopGateway gateway, required this.productId})
      : _gateway = gateway;

  final ShopGateway _gateway;
  final String productId;

  bool _loading = false;
  String? _loadError;
  ShopProduct? _product;
  bool _purchased = false;
  bool _working = false;
  String? _actionError;
  DownloadTicket? _lastTicket;

  bool get loading => _loading;
  String? get loadError => _loadError;
  ShopProduct? get product => _product;
  bool get purchased => _purchased;
  bool get working => _working;
  String? get actionError => _actionError;
  DownloadTicket? get lastTicket => _lastTicket;
  bool get isSignedIn => _gateway.isSignedIn;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final product = await _gateway.fetchProduct(productId);
      final purchased =
          product == null ? false : await _gateway.hasPurchased(productId);
      _product = product;
      _purchased = purchased;
    } catch (error) {
      _loadError = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CheckoutStart?> startCheckout({
    String? visitorId,
    String? source,
  }) async {
    _working = true;
    _actionError = null;
    notifyListeners();
    try {
      final start = await _gateway.startCheckout(
        productId,
        visitorId: visitorId,
        source: source,
      );
      if (start.alreadyPurchased) _purchased = true;
      return start;
    } catch (error) {
      _actionError = error.toString();
      return null;
    } finally {
      _working = false;
      notifyListeners();
    }
  }

  Future<DownloadTicket?> requestDownload() async {
    _working = true;
    _actionError = null;
    notifyListeners();
    try {
      final ticket = await _gateway.requestDownloadUrl(productId);
      _lastTicket = ticket;
      return ticket;
    } catch (error) {
      _actionError = error.toString();
      return null;
    } finally {
      _working = false;
      notifyListeners();
    }
  }
}

/// 購入済みライブラリ。本人RLSで返った購入だけを表示する。
class ShopDownloadsViewModel extends ChangeNotifier {
  ShopDownloadsViewModel({required ShopGateway gateway}) : _gateway = gateway;

  final ShopGateway _gateway;

  bool _loading = false;
  String? _error;
  List<ShopPurchase> _purchases = const [];
  String? _workingProductId;

  bool get loading => _loading;
  String? get error => _error;
  List<ShopPurchase> get purchases => _purchases;
  String? get workingProductId => _workingProductId;
  bool get isSignedIn => _gateway.isSignedIn;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _purchases = await _gateway.fetchPurchases();
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<DownloadTicket?> requestDownload(String productId) async {
    _workingProductId = productId;
    _error = null;
    notifyListeners();
    try {
      return await _gateway.requestDownloadUrl(productId);
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _workingProductId = null;
      notifyListeners();
    }
  }
}
