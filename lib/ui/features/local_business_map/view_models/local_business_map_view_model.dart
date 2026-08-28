import 'package:flutter/foundation.dart';

import '../../../../data/repositories/local_business_reference_repository.dart';
import '../../../../data/repositories/statistical_area_boundary_repository.dart';
import '../../../../data/services/local_business_reference_service.dart';
import '../../../../domain/models/local_business_reference.dart';
import '../../../../domain/models/statistical_area_boundary.dart';

enum LocalBusinessMapStatus { initial, loading, ready, failure }

enum StatisticalAreaCatalogStatus { initial, loading, ready, failure }

class LocalBusinessMapViewModel extends ChangeNotifier {
  LocalBusinessMapViewModel({
    required LocalBusinessReferenceRepository repository,
    required LocalBusinessReferenceLinkService linkService,
    StatisticalAreaBoundaryRepository? boundaryRepository,
  })  : _repository = repository,
        _linkService = linkService,
        _boundaryRepository = boundaryRepository;

  final LocalBusinessReferenceRepository _repository;
  final LocalBusinessReferenceLinkService _linkService;
  final StatisticalAreaBoundaryRepository? _boundaryRepository;

  LocalBusinessMapStatus _status = LocalBusinessMapStatus.initial;
  StatisticalAreaCatalogStatus _boundaryStatus =
      StatisticalAreaCatalogStatus.initial;
  LocalBusinessReferenceSnapshot _referenceSnapshot =
      LocalBusinessReferenceSnapshot.initial;
  StatisticalAreaBoundaryCatalog _boundaryCatalog =
      StatisticalAreaBoundaryCatalog.fuchuFallback;
  StatisticalBoundaryScope _selectedScope = StatisticalBoundaryScope.fuchuCity;
  final Map<StatisticalBoundaryScope, StatisticalAreaBoundaryCatalog>
      _loadedCatalogs =
      <StatisticalBoundaryScope, StatisticalAreaBoundaryCatalog>{};
  String _selectedAreaCode = '13206021001';
  int _boundaryRequestId = 0;
  String? _selectedBusinessId;
  String? _errorMessage;
  String? _boundaryErrorMessage;

  LocalBusinessMapStatus get status => _status;
  StatisticalAreaCatalogStatus get boundaryStatus => _boundaryStatus;
  LocalBusinessReferenceSnapshot get snapshot => _displaySnapshot;
  StatisticalAreaBoundaryCatalog get boundaryCatalog => _boundaryCatalog;
  StatisticalBoundaryScope get selectedScope => _selectedScope;
  List<StatisticalBoundaryScope> get availableScopes =>
      StatisticalBoundaryScope.values;
  List<StatisticalAreaBoundary> get availableAreas => _boundaryCatalog.areas;
  String get selectedAreaCode => _selectedAreaCode;
  StatisticalAreaBoundary get selectedArea =>
      _boundaryCatalog.findByCode(_selectedAreaCode) ??
      _boundaryCatalog.areas.first;
  bool get hasOfficialAggregateForSelectedArea =>
      _selectedScope == StatisticalBoundaryScope.fuchuCity &&
      _selectedAreaCode == '13206021001';
  bool get hasCompleteBoundaryCatalog {
    final minimumCount = switch (_selectedScope) {
      StatisticalBoundaryScope.fuchuCity => 100,
      StatisticalBoundaryScope.tokyo => 60,
      StatisticalBoundaryScope.kanto => 7,
      StatisticalBoundaryScope.japan => 47,
    };
    return _boundaryCatalog.areas.length >= minimumCount;
  }

  String get selectedRegionHeading =>
      '${_selectedScope.regionLabel} ${selectedArea.name}';
  String get boundaryCountLabel => switch (_selectedScope) {
        StatisticalBoundaryScope.fuchuCity => '府中市内 ${availableAreas.length}町丁',
        StatisticalBoundaryScope.tokyo => '東京都内 ${availableAreas.length}市区町村',
        StatisticalBoundaryScope.kanto => '関東 ${availableAreas.length}都県',
        StatisticalBoundaryScope.japan => '全国 ${availableAreas.length}都道府県',
      };
  String? get selectedBusinessId => _selectedBusinessId;
  String? get errorMessage {
    if (_errorMessage == null) return null;
    return hasOfficialAggregateForSelectedArea
        ? _errorMessage
        : '公開参考情報を取得できませんでした。選択中の町丁境界は引き続き確認できます。';
  }

  String? get boundaryErrorMessage => _boundaryErrorMessage;
  bool get isLoading => _status == LocalBusinessMapStatus.loading;
  bool get isBoundaryLoading =>
      _boundaryStatus == StatisticalAreaCatalogStatus.loading;

  PublicBusinessReference? get selectedBusiness {
    final selectedId = _selectedBusinessId;
    if (selectedId == null) return null;
    for (final business in snapshot.businesses) {
      if (business.id == selectedId) return business;
    }
    return null;
  }

  Future<void> load() async {
    _status = LocalBusinessMapStatus.loading;
    _errorMessage = null;
    if (_boundaryRepository != null) {
      _boundaryStatus = StatisticalAreaCatalogStatus.loading;
      _boundaryErrorMessage = null;
    }
    notifyListeners();
    final requestId = ++_boundaryRequestId;
    await Future.wait(<Future<void>>[
      _loadReferences(),
      if (_boundaryRepository != null)
        _loadBoundaries(_selectedScope, requestId),
    ]);
    notifyListeners();
  }

  Future<void> _loadReferences() async {
    try {
      _referenceSnapshot = await _repository.load();
      _status = LocalBusinessMapStatus.ready;
      if (_selectedBusinessId != null && selectedBusiness == null) {
        _selectedBusinessId = null;
      }
    } catch (_) {
      _status = LocalBusinessMapStatus.failure;
      _errorMessage = '公開参考情報を取得できませんでした。公式集計値は引き続き確認できます。';
    }
  }

  Future<void> _loadBoundaries(
    StatisticalBoundaryScope scope,
    int requestId,
  ) async {
    try {
      final catalog = await _boundaryRepository!.loadCatalog(scope);
      _loadedCatalogs[scope] = catalog;
      if (_selectedScope != scope || _boundaryRequestId != requestId) return;
      _boundaryCatalog = catalog;
      if (_boundaryCatalog.findByCode(_selectedAreaCode) == null) {
        _selectedAreaCode = _boundaryCatalog.areas.first.code;
      }
      _boundaryStatus = StatisticalAreaCatalogStatus.ready;
    } catch (_) {
      if (_selectedScope != scope || _boundaryRequestId != requestId) return;
      _boundaryCatalog = StatisticalAreaBoundaryCatalog.fallbackFor(scope);
      _selectedAreaCode = scope.defaultAreaCode;
      _boundaryStatus = StatisticalAreaCatalogStatus.failure;
      _boundaryErrorMessage = scope == StatisticalBoundaryScope.fuchuCity
          ? '府中市全域の境界を取得できないため、読み込み済みの周辺町丁のみ表示しています。'
          : '${scope.label}の行政区域境界を取得できませんでした。統計や事業者情報は推測せず、既定地域のみ表示しています。';
    }
  }

  Future<void> selectScope(StatisticalBoundaryScope scope) async {
    if (_selectedScope == scope) return;
    _selectedScope = scope;
    _selectedAreaCode = scope.defaultAreaCode;
    _selectedBusinessId = null;
    _boundaryErrorMessage = null;
    final cached = _loadedCatalogs[scope];
    _boundaryCatalog =
        cached ?? StatisticalAreaBoundaryCatalog.fallbackFor(scope);
    if (_boundaryCatalog.findByCode(_selectedAreaCode) == null) {
      _selectedAreaCode = _boundaryCatalog.areas.first.code;
    }
    if (cached != null || _boundaryRepository == null) {
      _boundaryStatus = cached == null
          ? StatisticalAreaCatalogStatus.initial
          : StatisticalAreaCatalogStatus.ready;
      notifyListeners();
      return;
    }
    _boundaryStatus = StatisticalAreaCatalogStatus.loading;
    final requestId = ++_boundaryRequestId;
    notifyListeners();
    await _loadBoundaries(scope, requestId);
    if (_selectedScope == scope && _boundaryRequestId == requestId) {
      notifyListeners();
    }
  }

  void selectArea(String areaCode) {
    if (_selectedAreaCode == areaCode) return;
    if (_boundaryCatalog.findByCode(areaCode) == null) return;
    _selectedAreaCode = areaCode;
    _selectedBusinessId = null;
    notifyListeners();
  }

  void selectBusiness(String businessId) {
    if (_selectedBusinessId == businessId) return;
    if (!snapshot.businesses.any((business) => business.id == businessId)) {
      return;
    }
    _selectedBusinessId = businessId;
    notifyListeners();
  }

  Future<bool> openOfficialSource() =>
      _open(_referenceSnapshot.officialAggregate.sourceUrl);

  Future<bool> openPublicSource() => _open(_referenceSnapshot.publicSourceUrl);

  Future<bool> openBoundarySource() => _open(
        _boundaryCatalog.select(selectedArea.code).sourceUrl,
      );

  Future<bool> openBusinessSource(String businessId) {
    for (final business in snapshot.businesses) {
      if (business.id == businessId) return _open(business.sourceUrl);
    }
    return Future<bool>.value(false);
  }

  LocalBusinessReferenceSnapshot get _displaySnapshot {
    final area = selectedArea;
    final isDefaultArea = hasOfficialAggregateForSelectedArea;
    return LocalBusinessReferenceSnapshot(
      officialAggregate: _referenceSnapshot.officialAggregate,
      businesses: isDefaultArea
          ? _referenceSnapshot.businesses
          : const <PublicBusinessReference>[],
      centerLatitude: isDefaultArea
          ? _referenceSnapshot.centerLatitude
          : area.mapCenterLatitude,
      centerLongitude: isDefaultArea
          ? _referenceSnapshot.centerLongitude
          : area.mapCenterLongitude,
      radiusMeters: isDefaultArea ? _referenceSnapshot.radiusMeters : 0,
      coverageNote: isDefaultArea
          ? _referenceSnapshot.coverageNote
          : '${area.name}の事業所統計・公開参考一覧は未連携です。境界だけを表示し、件数は推測しません。',
      ownershipNote: _referenceSnapshot.ownershipNote,
      publicSourceLabel: _referenceSnapshot.publicSourceLabel,
      publicSourceUrl: _referenceSnapshot.publicSourceUrl,
      license: _referenceSnapshot.license,
      fetchedAt: _referenceSnapshot.fetchedAt,
      statisticalBoundarySet: _boundaryCatalog.select(area.code),
    );
  }

  Future<bool> _open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    try {
      return await _linkService.open(uri);
    } catch (_) {
      return false;
    }
  }
}
