import 'statistical_area_boundary.dart';

class OfficialBusinessAggregate {
  const OfficialBusinessAggregate({
    required this.surveyName,
    required this.surveyDate,
    required this.areaName,
    required this.totalEstablishments,
    required this.totalEmployees,
    required this.soleProprietorEstablishments,
    required this.soleProprietorEmployees,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.disclosureNote,
  });

  static const fuchuHonmachi1 = OfficialBusinessAggregate(
    surveyName: '令和3年経済センサス－活動調査 町丁・大字別集計',
    surveyDate: '2021-06-01',
    areaName: '東京都府中市 本町1丁目',
    totalEstablishments: 86,
    totalEmployees: 991,
    soleProprietorEstablishments: 20,
    soleProprietorEmployees: 79,
    sourceLabel: '政府統計の総合窓口 e-Stat',
    sourceUrl:
        'https://www.e-stat.go.jp/help/data-definition-information/about-recorded-data',
    disclosureNote: '町丁・大字別の集計値です。個々の事業所名や個人経営者名は公表されていません。',
  );

  final String surveyName;
  final String surveyDate;
  final String areaName;
  final int totalEstablishments;
  final int totalEmployees;
  final int soleProprietorEstablishments;
  final int soleProprietorEmployees;
  final String sourceLabel;
  final String sourceUrl;
  final String disclosureNote;

  factory OfficialBusinessAggregate.fromJson(Map<String, dynamic> json) {
    return OfficialBusinessAggregate(
      surveyName: _text(json['surveyName'], fuchuHonmachi1.surveyName),
      surveyDate: _text(json['surveyDate'], fuchuHonmachi1.surveyDate),
      areaName: _text(json['areaName'], fuchuHonmachi1.areaName),
      totalEstablishments: _integer(
        json['totalEstablishments'],
        fuchuHonmachi1.totalEstablishments,
      ),
      totalEmployees: _integer(
        json['totalEmployees'],
        fuchuHonmachi1.totalEmployees,
      ),
      soleProprietorEstablishments: _integer(
        json['soleProprietorEstablishments'],
        fuchuHonmachi1.soleProprietorEstablishments,
      ),
      soleProprietorEmployees: _integer(
        json['soleProprietorEmployees'],
        fuchuHonmachi1.soleProprietorEmployees,
      ),
      sourceLabel: _text(json['sourceLabel'], fuchuHonmachi1.sourceLabel),
      sourceUrl: _text(json['sourceUrl'], fuchuHonmachi1.sourceUrl),
      disclosureNote: _text(
        json['disclosureNote'],
        fuchuHonmachi1.disclosureNote,
      ),
    );
  }
}

class PublicBusinessReference {
  const PublicBusinessReference({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryCode,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.address,
    required this.ownershipLabel,
    required this.sourceLabel,
    required this.sourceUrl,
  });

  final String id;
  final String name;
  final String category;
  final String categoryCode;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final String address;
  final String ownershipLabel;
  final String sourceLabel;
  final String sourceUrl;

  factory PublicBusinessReference.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id']);
    final name = _text(json['name']);
    final sourceUrl = _text(json['sourceUrl']);
    if (id.isEmpty || name.isEmpty || sourceUrl.isEmpty) {
      throw const FormatException('Public business reference is incomplete.');
    }
    return PublicBusinessReference(
      id: id,
      name: name,
      category: _text(json['category'], '施設・サービス'),
      categoryCode: _text(json['categoryCode']),
      latitude: _number(json['latitude']),
      longitude: _number(json['longitude']),
      distanceMeters: _integer(json['distanceMeters'], 0),
      address: _text(json['address'], '住所情報はOSM未登録'),
      ownershipLabel: _text(json['ownershipLabel'], '経営形態未確認'),
      sourceLabel: _text(json['sourceLabel'], 'OpenStreetMap'),
      sourceUrl: sourceUrl,
    );
  }
}

class LocalBusinessReferenceSnapshot {
  const LocalBusinessReferenceSnapshot({
    required this.officialAggregate,
    required this.businesses,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.coverageNote,
    required this.ownershipNote,
    required this.publicSourceLabel,
    required this.publicSourceUrl,
    required this.license,
    required this.fetchedAt,
    this.statisticalBoundarySet = StatisticalAreaBoundarySet.fuchuHonmachi1,
  });

  static const initial = LocalBusinessReferenceSnapshot(
    officialAggregate: OfficialBusinessAggregate.fuchuHonmachi1,
    businesses: <PublicBusinessReference>[],
    centerLatitude: 35.666471,
    centerLongitude: 139.477994,
    radiusMeters: 300,
    coverageNote: '本町一丁目の公開参考情報を読み込んでいます。',
    ownershipNote: '個人経営かどうかを推測・判定しません。',
    publicSourceLabel: 'OpenStreetMap via Overpass API',
    publicSourceUrl: 'https://www.openstreetmap.org/copyright',
    license: 'ODbL 1.0',
    fetchedAt: null,
  );

  final OfficialBusinessAggregate officialAggregate;
  final List<PublicBusinessReference> businesses;
  final double centerLatitude;
  final double centerLongitude;
  final int radiusMeters;
  final String coverageNote;
  final String ownershipNote;
  final String publicSourceLabel;
  final String publicSourceUrl;
  final String license;
  final DateTime? fetchedAt;
  final StatisticalAreaBoundarySet statisticalBoundarySet;

  factory LocalBusinessReferenceSnapshot.fromJson(Map<String, dynamic> json) {
    final target = _map(json['target']);
    final center = _map(target['center']);
    final official = _map(json['officialAggregate']);
    final publicReference = _map(json['publicReference']);
    final rows = publicReference['businesses'];
    final businesses = <PublicBusinessReference>[];
    if (rows is List) {
      for (final row in rows) {
        try {
          businesses.add(PublicBusinessReference.fromJson(_map(row)));
        } on FormatException {
          continue;
        }
      }
    }
    final fetchedAtText = _text(publicReference['fetchedAt']);
    return LocalBusinessReferenceSnapshot(
      officialAggregate: official.isEmpty
          ? OfficialBusinessAggregate.fuchuHonmachi1
          : OfficialBusinessAggregate.fromJson(official),
      businesses: List<PublicBusinessReference>.unmodifiable(businesses),
      centerLatitude: _number(
        center['latitude'],
        fallback: initial.centerLatitude,
      ),
      centerLongitude: _number(
        center['longitude'],
        fallback: initial.centerLongitude,
      ),
      radiusMeters: _integer(target['radiusMeters'], initial.radiusMeters),
      coverageNote: _text(
        publicReference['coverageNote'],
        initial.coverageNote,
      ),
      ownershipNote: _text(
        publicReference['ownershipNote'],
        initial.ownershipNote,
      ),
      publicSourceLabel: _text(
        publicReference['sourceLabel'],
        initial.publicSourceLabel,
      ),
      publicSourceUrl: _text(
        publicReference['sourceUrl'],
        initial.publicSourceUrl,
      ),
      license: _text(publicReference['license'], initial.license),
      fetchedAt:
          fetchedAtText.isEmpty ? null : DateTime.tryParse(fetchedAtText),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _text(dynamic value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(dynamic value, int fallback) {
  if (value is num && value.isFinite) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _number(dynamic value, {double fallback = 0}) {
  if (value is num && value.isFinite) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
