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
  String _selectedAreaCode = '13206021001';
  String? _selectedBusinessId;
  String? _errorMessage;
  String? _boundaryErrorMessage;

  LocalBusinessMapStatus get status => _status;
  StatisticalAreaCatalogStatus get boundaryStatus => _boundaryStatus;
  LocalBusinessReferenceSnapshot get snapshot => _displaySnapshot;
  StatisticalAreaBoundaryCatalog get boundaryCatalog => _boundaryCatalog;
  List<StatisticalAreaBoundary> get availableAreas => _boundaryCatalog.areas;
  String get selectedAreaCode => _selectedAreaCode;
  StatisticalAreaBoundary get selectedArea =>
      _boundaryCatalog.findByCode(_selectedAreaCode) ??
      _boundaryCatalog.areas.first;
  bool get hasOfficialAggregateForSelectedArea =>
      _selectedAreaCode == '13206021001';
  bool get hasCompleteBoundaryCatalog => _boundaryCatalog.areas.length >= 100;
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
    await Future.wait(<Future<void>>[
      _loadReferences(),
      if (_boundaryRepository != null) _loadBoundaries(),
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

  Future<void> _loadBoundaries() async {
    try {
      _boundaryCatalog = await _boundaryRepository!.loadFuchuCatalog();
      if (_boundaryCatalog.findByCode(_selectedAreaCode) == null) {
        _selectedAreaCode = _boundaryCatalog.areas.first.code;
      }
      _boundaryStatus = StatisticalAreaCatalogStatus.ready;
    } catch (_) {
      _boundaryStatus = StatisticalAreaCatalogStatus.failure;
      _boundaryErrorMessage = '府中市全域の境界を取得できないため、読み込み済みの周辺町丁のみ表示しています。';
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
        'https://geoshape.ex.nii.ac.jp/ka/resource/13/${selectedArea.code}.html',
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
          : '${area.name}の公開参考一覧は未連携です。現在は町丁境界のみ切り替えて確認できます。',
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
