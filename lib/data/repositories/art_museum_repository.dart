import '../../domain/models/art_museum.dart';
import '../models/art_museum_model.dart';
import '../services/art_museum_catalog_service.dart';

abstract interface class ArtMuseumRepository {
  Future<ArtMuseumCatalog> getCatalog();
}

class AssetArtMuseumRepository implements ArtMuseumRepository {
  const AssetArtMuseumRepository({required this.catalogService});

  final ArtMuseumCatalogService catalogService;

  @override
  Future<ArtMuseumCatalog> getCatalog() async {
    final model = await catalogService.loadCatalog();
    final museums = model.museums.map(_toDomain).toList(growable: false);
    final prefectures = museums.map((museum) => museum.prefecture).toSet();
    final expectedPrefectures = kJapanPrefectures.toSet();
    if (!prefectures.containsAll(expectedPrefectures) ||
        !expectedPrefectures.containsAll(prefectures)) {
      throw const FormatException(
        'Museum catalog must cover exactly the 47 Japanese prefectures',
      );
    }
    return ArtMuseumCatalog(
      sourceLabel: model.sourceLabel,
      sourceUrl: _requiredHttpUri(model.sourceUrl, 'source.url'),
      downloadUrl: _requiredHttpUri(model.downloadUrl, 'source.downloadUrl'),
      asOf: model.asOf,
      museums: museums,
    );
  }

  ArtMuseum _toDomain(ArtMuseumModel model) {
    final officialUrl = Uri.tryParse(model.officialUrl);
    return ArtMuseum(
      name: model.name,
      prefecture: model.prefecture,
      municipality: model.municipality,
      registrationStatus: model.registrationStatus,
      operatorName: model.operatorName,
      officialUrl: officialUrl != null &&
              (officialUrl.scheme == 'https' || officialUrl.scheme == 'http')
          ? officialUrl
          : null,
    );
  }

  Uri _requiredHttpUri(String value, String fieldName) {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw FormatException('Museum catalog has an invalid $fieldName');
    }
    return uri;
  }
}
