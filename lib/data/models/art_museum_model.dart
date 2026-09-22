class ArtMuseumModel {
  const ArtMuseumModel({
    required this.name,
    required this.prefecture,
    required this.municipality,
    required this.registrationStatus,
    required this.operatorName,
    required this.officialUrl,
  });

  factory ArtMuseumModel.fromJson(Map<String, dynamic> json) {
    return ArtMuseumModel(
      name: (json['name'] as String? ?? '').trim(),
      prefecture: (json['prefecture'] as String? ?? '').trim(),
      municipality: (json['municipality'] as String? ?? '').trim(),
      registrationStatus: (json['registrationStatus'] as String? ?? '').trim(),
      operatorName: (json['operator'] as String? ?? '').trim(),
      officialUrl: (json['officialUrl'] as String? ?? '').trim(),
    );
  }

  final String name;
  final String prefecture;
  final String municipality;
  final String registrationStatus;
  final String operatorName;
  final String officialUrl;
}

class ArtMuseumCatalogModel {
  ArtMuseumCatalogModel({
    required this.schemaVersion,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.asOf,
    required List<ArtMuseumModel> museums,
  }) : museums = List<ArtMuseumModel>.unmodifiable(museums);

  final int schemaVersion;
  final String sourceLabel;
  final String sourceUrl;
  final String downloadUrl;
  final String asOf;
  final List<ArtMuseumModel> museums;
}
