import 'package:flutter/foundation.dart';

import '../data/repositories/art_museum_repository.dart';
import '../domain/models/art_museum.dart';

enum ArtMuseumDirectoryStatus { initial, loading, ready, error }

class ArtMuseumDirectoryViewModel extends ChangeNotifier {
  ArtMuseumDirectoryViewModel({required ArtMuseumRepository repository})
      : _repository = repository;

  final ArtMuseumRepository _repository;

  ArtMuseumDirectoryStatus _status = ArtMuseumDirectoryStatus.initial;
  ArtMuseumCatalog? _catalog;
  String _query = '';
  JapanRegion _selectedRegion = JapanRegion.all;
  String? _selectedPrefecture;
  String? _errorMessage;
  bool _disposed = false;

  ArtMuseumDirectoryStatus get status => _status;
  ArtMuseumCatalog? get catalog => _catalog;
  String get query => _query;
  JapanRegion get selectedRegion => _selectedRegion;
  String? get selectedPrefecture => _selectedPrefecture;
  String? get errorMessage => _errorMessage;
  bool get hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _selectedRegion != JapanRegion.all ||
      _selectedPrefecture != null;

  List<String> get availablePrefectures => _selectedRegion.prefectures;

  List<ArtMuseum> get visibleMuseums {
    final museums = _catalog?.museums ?? const <ArtMuseum>[];
    final terms = _query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[\s　]+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);

    return museums.where((museum) {
      if (!_selectedRegion.contains(museum.prefecture)) return false;
      if (_selectedPrefecture != null &&
          museum.prefecture != _selectedPrefecture) {
        return false;
      }
      if (terms.isEmpty) return true;
      final searchable = <String>[
        museum.name,
        museum.prefecture,
        museum.municipality,
        museum.registrationStatus,
        museum.operatorName,
      ].join(' ').toLowerCase();
      return terms.every(searchable.contains);
    }).toList(growable: false);
  }

  Future<void> load() async {
    if (_disposed || _status == ArtMuseumDirectoryStatus.loading) return;
    _status = ArtMuseumDirectoryStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final catalog = await _repository.getCatalog();
      if (_disposed) return;
      _catalog = catalog;
      _status = ArtMuseumDirectoryStatus.ready;
    } catch (error) {
      if (_disposed) return;
      _status = ArtMuseumDirectoryStatus.error;
      _errorMessage = '美術館データを読み込めませんでした。もう一度お試しください。';
      debugPrint('Failed to load art museum catalog: $error');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void updateQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void selectRegion(JapanRegion region) {
    if (_selectedRegion == region) return;
    _selectedRegion = region;
    if (_selectedPrefecture != null && !region.contains(_selectedPrefecture!)) {
      _selectedPrefecture = null;
    }
    notifyListeners();
  }

  void selectPrefecture(String? prefecture) {
    final normalized = prefecture?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (next != null && !_selectedRegion.contains(next)) return;
    if (_selectedPrefecture == next) return;
    _selectedPrefecture = next;
    notifyListeners();
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _query = '';
    _selectedRegion = JapanRegion.all;
    _selectedPrefecture = null;
    notifyListeners();
  }
}
