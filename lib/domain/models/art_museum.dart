const List<String> kJapanPrefectures = <String>[
  '北海道',
  '青森県',
  '岩手県',
  '宮城県',
  '秋田県',
  '山形県',
  '福島県',
  '茨城県',
  '栃木県',
  '群馬県',
  '埼玉県',
  '千葉県',
  '東京都',
  '神奈川県',
  '新潟県',
  '富山県',
  '石川県',
  '福井県',
  '山梨県',
  '長野県',
  '岐阜県',
  '静岡県',
  '愛知県',
  '三重県',
  '滋賀県',
  '京都府',
  '大阪府',
  '兵庫県',
  '奈良県',
  '和歌山県',
  '鳥取県',
  '島根県',
  '岡山県',
  '広島県',
  '山口県',
  '徳島県',
  '香川県',
  '愛媛県',
  '高知県',
  '福岡県',
  '佐賀県',
  '長崎県',
  '熊本県',
  '大分県',
  '宮崎県',
  '鹿児島県',
  '沖縄県',
];

enum JapanRegion {
  all('全国', kJapanPrefectures),
  hokkaido('北海道', <String>['北海道']),
  tohoku('東北', <String>['青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県']),
  kanto('関東', <String>['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県']),
  hokurikuKoshinetsu('北陸・甲信越', <String>[
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
  ]),
  tokai('東海', <String>['岐阜県', '静岡県', '愛知県', '三重県']),
  kinki('近畿', <String>['滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県']),
  chugoku('中国', <String>['鳥取県', '島根県', '岡山県', '広島県', '山口県']),
  shikoku('四国', <String>['徳島県', '香川県', '愛媛県', '高知県']),
  kyushuOkinawa('九州・沖縄', <String>[
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県',
  ]);

  const JapanRegion(this.label, this.prefectures);

  final String label;
  final List<String> prefectures;

  bool contains(String prefecture) => prefectures.contains(prefecture);

  static JapanRegion forPrefecture(String prefecture) {
    return JapanRegion.values.skip(1).firstWhere(
          (region) => region.contains(prefecture),
          orElse: () => JapanRegion.all,
        );
  }
}

class ArtMuseum {
  const ArtMuseum({
    required this.name,
    required this.prefecture,
    required this.municipality,
    required this.registrationStatus,
    required this.operatorName,
    this.officialUrl,
  });

  final String name;
  final String prefecture;
  final String municipality;
  final String registrationStatus;
  final String operatorName;
  final Uri? officialUrl;

  JapanRegion get region => JapanRegion.forPrefecture(prefecture);

  String get locationLabel =>
      municipality.isEmpty ? prefecture : '$prefecture $municipality';
}

class ArtMuseumCatalog {
  ArtMuseumCatalog({
    required this.sourceLabel,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.asOf,
    required List<ArtMuseum> museums,
  }) : museums = List<ArtMuseum>.unmodifiable(museums);

  final String sourceLabel;
  final Uri sourceUrl;
  final Uri downloadUrl;
  final String asOf;
  final List<ArtMuseum> museums;

  int get prefectureCount =>
      museums.map((museum) => museum.prefecture).toSet().length;
}
