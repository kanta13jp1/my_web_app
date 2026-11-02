import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/art_museum_model.dart';

typedef ArtMuseumAssetLoader = Future<String> Function(String assetPath);

class ArtMuseumCatalogService {
  ArtMuseumCatalogService({
    this.assetPath = defaultAssetPath,
    ArtMuseumAssetLoader? assetLoader,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString;

  static const String defaultAssetPath = 'assets/data/art_museums_japan.json';

  final String assetPath;
  final ArtMuseumAssetLoader _assetLoader;

  Future<ArtMuseumCatalogModel> loadCatalog() async {
    final raw = await _assetLoader(assetPath);
    return parse(raw);
  }

  static ArtMuseumCatalogModel parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Museum catalog must be a JSON object');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported museum catalog schema');
    }

    final source = decoded['source'];
    final rawMuseums = decoded['museums'];
    if (source is! Map<String, dynamic> || rawMuseums is! List<dynamic>) {
      throw const FormatException(
        'Museum catalog is missing source or museums',
      );
    }

    final museums = <ArtMuseumModel>[];
    for (final rawMuseum in rawMuseums) {
      if (rawMuseum is! Map<String, dynamic>) {
        throw const FormatException('Museum catalog contains a non-object row');
      }
      final museum = ArtMuseumModel.fromJson(rawMuseum);
      if (museum.name.isEmpty || museum.prefecture.isEmpty) {
        throw const FormatException(
          'Museum catalog contains a row without a name or prefecture',
        );
      }
      museums.add(museum);
    }
    if (museums.isEmpty) {
      throw const FormatException('Museum catalog does not contain museums');
    }

    return ArtMuseumCatalogModel(
      schemaVersion: 1,
      sourceLabel: (source['label'] as String? ?? '').trim(),
      sourceUrl: (source['url'] as String? ?? '').trim(),
      downloadUrl: (source['downloadUrl'] as String? ?? '').trim(),
      asOf: (source['asOf'] as String? ?? '').trim(),
      museums: museums,
    );
  }
}
