/// A latitude/longitude point in a statistical-area boundary.
class StatisticalAreaBoundaryPoint {
  const StatisticalAreaBoundaryPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

enum StatisticalBoundaryScope {
  fuchuCity('府中市', '府中市の町丁を選択', '東京都府中市', '13206021001'),
  tokyo('東京都', '東京都の市区町村を選択', '東京都', '13206'),
  kanto('関東', '関東の都県を選択', '関東地方', '13'),
  japan('日本', '都道府県を選択', '日本', '13');

  const StatisticalBoundaryScope(
    this.label,
    this.selectorLabel,
    this.regionLabel,
    this.defaultAreaCode,
  );

  final String label;
  final String selectorLabel;
  final String regionLabel;
  final String defaultAreaCode;
}

/// A single town/chome polygon rendered on the local-business map.
class StatisticalAreaBoundary {
  const StatisticalAreaBoundary({
    required this.code,
    required this.name,
    required this.isTarget,
    required this.points,
    this.additionalPolygons = const <List<StatisticalAreaBoundaryPoint>>[],
    this.centerLatitude,
    this.centerLongitude,
  });

  final String code;
  final String name;
  final bool isTarget;
  final List<StatisticalAreaBoundaryPoint> points;
  final List<List<StatisticalAreaBoundaryPoint>> additionalPolygons;
  final double? centerLatitude;
  final double? centerLongitude;

  double get mapCenterLatitude =>
      centerLatitude ?? _boundsCenter(isLatitude: true);

  double get mapCenterLongitude =>
      centerLongitude ?? _boundsCenter(isLatitude: false);

  bool get hasGeometry => points.length >= 3;

  Iterable<StatisticalAreaBoundaryPoint> get allPoints sync* {
    yield* points;
    for (final polygon in additionalPolygons) {
      yield* polygon;
    }
  }

  StatisticalAreaBoundary copyWithTarget(bool value) {
    return StatisticalAreaBoundary(
      code: code,
      name: name,
      isTarget: value,
      points: points,
      additionalPolygons: additionalPolygons,
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );
  }

  double _boundsCenter({required bool isLatitude}) {
    final source = allPoints.toList(growable: false);
    if (source.isEmpty) return 0;
    var minimum = isLatitude ? source.first.latitude : source.first.longitude;
    var maximum = minimum;
    for (final point in source.skip(1)) {
      final value = isLatitude ? point.latitude : point.longitude;
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }
    return (minimum + maximum) / 2;
  }
}

/// All town/chome boundaries available for a municipality.
class StatisticalAreaBoundaryCatalog {
  const StatisticalAreaBoundaryCatalog({
    this.scope = StatisticalBoundaryScope.fuchuCity,
    required this.municipalityName,
    required this.datasetLabel,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.license,
    required this.boundaryNote,
    required this.simplificationNote,
    required this.areas,
  });

  static final fuchuFallback = StatisticalAreaBoundaryCatalog(
    scope: StatisticalBoundaryScope.fuchuCity,
    municipalityName: '東京都府中市',
    datasetLabel: StatisticalAreaBoundarySet.fuchuHonmachi1.datasetLabel,
    sourceLabel: StatisticalAreaBoundarySet.fuchuHonmachi1.sourceLabel,
    sourceUrl:
        'https://geoshape.ex.nii.ac.jp/ka/topojson/2020/13/r2ka13206.topojson',
    license: StatisticalAreaBoundarySet.fuchuHonmachi1.license,
    boundaryNote: StatisticalAreaBoundarySet.fuchuHonmachi1.boundaryNote,
    simplificationNote:
        StatisticalAreaBoundarySet.fuchuHonmachi1.simplificationNote,
    areas: StatisticalAreaBoundarySet.fuchuHonmachi1.areas,
  );

  static StatisticalAreaBoundaryCatalog fallbackFor(
    StatisticalBoundaryScope scope,
  ) {
    if (scope == StatisticalBoundaryScope.fuchuCity) return fuchuFallback;
    final isTokyo = scope == StatisticalBoundaryScope.tokyo;
    final area = StatisticalAreaBoundary(
      code: scope.defaultAreaCode,
      name: isTokyo ? '府中市' : '東京都',
      isTarget: true,
      points: const <StatisticalAreaBoundaryPoint>[],
      centerLatitude: isTokyo ? 35.6689 : 35.6762,
      centerLongitude: isTokyo ? 139.4777 : 139.6503,
    );
    return StatisticalAreaBoundaryCatalog(
      scope: scope,
      municipalityName: scope.regionLabel,
      datasetLabel: '歴史的行政区域データセットβ版（2023年行政区域）',
      sourceLabel: 'CODH 歴史的行政区域データセットβ版',
      sourceUrl: scope == StatisticalBoundaryScope.tokyo
          ? 'https://geoshape.ex.nii.ac.jp/city/choropleth/13_city.html'
          : 'https://geoshape.ex.nii.ac.jp/city/choropleth/jp_pref.html',
      license: 'CC BY 4.0',
      boundaryNote: '行政区域境界の取得に失敗したため、選択用の既定地域のみ表示しています。',
      simplificationNote: '再読み込みすると公開境界データの取得を再試行します。',
      areas: <StatisticalAreaBoundary>[area],
    );
  }

  final StatisticalBoundaryScope scope;
  final String municipalityName;
  final String datasetLabel;
  final String sourceLabel;
  final String sourceUrl;
  final String license;
  final String boundaryNote;
  final String simplificationNote;
  final List<StatisticalAreaBoundary> areas;

  StatisticalAreaBoundary? findByCode(String code) {
    for (final area in areas) {
      if (area.code == code) return area;
    }
    return null;
  }

  StatisticalAreaBoundarySet select(String selectedCode) {
    final selected = findByCode(selectedCode) ?? areas.first;
    return StatisticalAreaBoundarySet(
      scope: scope,
      datasetLabel: datasetLabel,
      sourceLabel: sourceLabel,
      sourceUrl: scope == StatisticalBoundaryScope.fuchuCity
          ? 'https://geoshape.ex.nii.ac.jp/ka/resource/13/${selected.code}.html'
          : sourceUrl,
      license: license,
      boundaryNote: boundaryNote,
      simplificationNote: simplificationNote,
      areas: List<StatisticalAreaBoundary>.unmodifiable(
        areas.map((area) => area.copyWithTarget(area.code == selected.code)),
      ),
    );
  }
}

/// Boundary dataset metadata and the target plus its touching neighbours.
class StatisticalAreaBoundarySet {
  const StatisticalAreaBoundarySet({
    this.scope = StatisticalBoundaryScope.fuchuCity,
    required this.datasetLabel,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.license,
    required this.boundaryNote,
    required this.simplificationNote,
    required this.areas,
  });

  /// Generated from CODH Geoshape's e-Stat 2020 town-boundary derivative.
  /// Coordinates are simplified to approximately two-metre tolerance.
  static const fuchuHonmachi1 = StatisticalAreaBoundarySet(
    datasetLabel: '令和2年国勢調査 町丁・字等別境界データ',
    sourceLabel: 'CODH 国勢調査町丁・字等別境界データセット',
    sourceUrl: 'https://geoshape.ex.nii.ac.jp/ka/resource/13/13206021001.html',
    license: 'CC BY 4.0',
    boundaryNote: '統計調査区を基にした境界で、住居表示などの実際の町丁境界と一致しない場合があります。',
    simplificationNote: '画面表示用に約2m精度で簡略化しています。',
    areas: <StatisticalAreaBoundary>[
      StatisticalAreaBoundary(
        code: '13206021001',
        name: '本町一丁目',
        isTarget: true,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.668841, 139.476918),
          StatisticalAreaBoundaryPoint(35.668639, 139.476958),
          StatisticalAreaBoundaryPoint(35.668733, 139.477686),
          StatisticalAreaBoundaryPoint(35.668736, 139.478412),
          StatisticalAreaBoundaryPoint(35.668266, 139.478404),
          StatisticalAreaBoundaryPoint(35.668272, 139.47824),
          StatisticalAreaBoundaryPoint(35.667116, 139.478418),
          StatisticalAreaBoundaryPoint(35.666758, 139.4786),
          StatisticalAreaBoundaryPoint(35.666788, 139.478729),
          StatisticalAreaBoundaryPoint(35.666328, 139.479068),
          StatisticalAreaBoundaryPoint(35.666432, 139.479423),
          StatisticalAreaBoundaryPoint(35.666199, 139.479516),
          StatisticalAreaBoundaryPoint(35.666189, 139.479558),
          StatisticalAreaBoundaryPoint(35.66635, 139.479864),
          StatisticalAreaBoundaryPoint(35.666252, 139.479926),
          StatisticalAreaBoundaryPoint(35.666326, 139.480175),
          StatisticalAreaBoundaryPoint(35.666515, 139.480516),
          StatisticalAreaBoundaryPoint(35.666613, 139.480762),
          StatisticalAreaBoundaryPoint(35.666446, 139.480776),
          StatisticalAreaBoundaryPoint(35.666439, 139.480991),
          StatisticalAreaBoundaryPoint(35.666485, 139.48109),
          StatisticalAreaBoundaryPoint(35.665208, 139.481171),
          StatisticalAreaBoundaryPoint(35.664826, 139.480923),
          StatisticalAreaBoundaryPoint(35.664779, 139.480842),
          StatisticalAreaBoundaryPoint(35.664758, 139.480668),
          StatisticalAreaBoundaryPoint(35.664805, 139.480007),
          StatisticalAreaBoundaryPoint(35.664956, 139.479148),
          StatisticalAreaBoundaryPoint(35.664792, 139.478979),
          StatisticalAreaBoundaryPoint(35.66468, 139.479007),
          StatisticalAreaBoundaryPoint(35.664407, 139.478972),
          StatisticalAreaBoundaryPoint(35.664089, 139.477586),
          StatisticalAreaBoundaryPoint(35.664955, 139.477297),
          StatisticalAreaBoundaryPoint(35.665273, 139.47716),
          StatisticalAreaBoundaryPoint(35.665371, 139.477049),
          StatisticalAreaBoundaryPoint(35.666333, 139.476726),
          StatisticalAreaBoundaryPoint(35.666656, 139.476675),
          StatisticalAreaBoundaryPoint(35.666729, 139.47701),
          StatisticalAreaBoundaryPoint(35.667092, 139.476907),
          StatisticalAreaBoundaryPoint(35.667196, 139.476804),
          StatisticalAreaBoundaryPoint(35.667337, 139.476732),
          StatisticalAreaBoundaryPoint(35.667228, 139.47648),
          StatisticalAreaBoundaryPoint(35.667434, 139.476338),
          StatisticalAreaBoundaryPoint(35.667963, 139.475786),
          StatisticalAreaBoundaryPoint(35.668299, 139.475142),
          StatisticalAreaBoundaryPoint(35.668436, 139.474782),
          StatisticalAreaBoundaryPoint(35.668669, 139.474884),
          StatisticalAreaBoundaryPoint(35.668515, 139.475299),
          StatisticalAreaBoundaryPoint(35.668781, 139.475826),
          StatisticalAreaBoundaryPoint(35.668841, 139.476918),
        ],
      ),
      StatisticalAreaBoundary(
        code: '13206014003',
        name: '宮町三丁目',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.670039, 139.47906),
          StatisticalAreaBoundaryPoint(35.669995, 139.479072),
          StatisticalAreaBoundaryPoint(35.669992, 139.479726),
          StatisticalAreaBoundaryPoint(35.668297, 139.479725),
          StatisticalAreaBoundaryPoint(35.668392, 139.481397),
          StatisticalAreaBoundaryPoint(35.668178, 139.483246),
          StatisticalAreaBoundaryPoint(35.667981, 139.484477),
          StatisticalAreaBoundaryPoint(35.667817, 139.48451),
          StatisticalAreaBoundaryPoint(35.667055, 139.484224),
          StatisticalAreaBoundaryPoint(35.66693, 139.484275),
          StatisticalAreaBoundaryPoint(35.666867, 139.483528),
          StatisticalAreaBoundaryPoint(35.666937, 139.483001),
          StatisticalAreaBoundaryPoint(35.666913, 139.482486),
          StatisticalAreaBoundaryPoint(35.666597, 139.481599),
          StatisticalAreaBoundaryPoint(35.666559, 139.481162),
          StatisticalAreaBoundaryPoint(35.666443, 139.48102),
          StatisticalAreaBoundaryPoint(35.666446, 139.480776),
          StatisticalAreaBoundaryPoint(35.666613, 139.480762),
          StatisticalAreaBoundaryPoint(35.666515, 139.480516),
          StatisticalAreaBoundaryPoint(35.666326, 139.480175),
          StatisticalAreaBoundaryPoint(35.666252, 139.479926),
          StatisticalAreaBoundaryPoint(35.66635, 139.479864),
          StatisticalAreaBoundaryPoint(35.666189, 139.479558),
          StatisticalAreaBoundaryPoint(35.666199, 139.479516),
          StatisticalAreaBoundaryPoint(35.666432, 139.479423),
          StatisticalAreaBoundaryPoint(35.666328, 139.479068),
          StatisticalAreaBoundaryPoint(35.666788, 139.478729),
          StatisticalAreaBoundaryPoint(35.666758, 139.4786),
          StatisticalAreaBoundaryPoint(35.667116, 139.478418),
          StatisticalAreaBoundaryPoint(35.668272, 139.47824),
          StatisticalAreaBoundaryPoint(35.668266, 139.478404),
          StatisticalAreaBoundaryPoint(35.670023, 139.478479),
          StatisticalAreaBoundaryPoint(35.670039, 139.47906),
        ],
      ),
      StatisticalAreaBoundary(
        code: '13206023002',
        name: '宮西町二丁目',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.670889, 139.479094),
          StatisticalAreaBoundaryPoint(35.670039, 139.47906),
          StatisticalAreaBoundaryPoint(35.670023, 139.478479),
          StatisticalAreaBoundaryPoint(35.668736, 139.478412),
          StatisticalAreaBoundaryPoint(35.668733, 139.477686),
          StatisticalAreaBoundaryPoint(35.668639, 139.476958),
          StatisticalAreaBoundaryPoint(35.669117, 139.476872),
          StatisticalAreaBoundaryPoint(35.669913, 139.476809),
          StatisticalAreaBoundaryPoint(35.66991, 139.476949),
          StatisticalAreaBoundaryPoint(35.670063, 139.476746),
          StatisticalAreaBoundaryPoint(35.670813, 139.476649),
          StatisticalAreaBoundaryPoint(35.670735, 139.478159),
          StatisticalAreaBoundaryPoint(35.67087, 139.478766),
          StatisticalAreaBoundaryPoint(35.670889, 139.479094),
        ],
      ),
      StatisticalAreaBoundary(
        code: '13206023005',
        name: '宮西町五丁目',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.669913, 139.476809),
          StatisticalAreaBoundaryPoint(35.668841, 139.476918),
          StatisticalAreaBoundaryPoint(35.668781, 139.475826),
          StatisticalAreaBoundaryPoint(35.668515, 139.475299),
          StatisticalAreaBoundaryPoint(35.668669, 139.474884),
          StatisticalAreaBoundaryPoint(35.668552, 139.474828),
          StatisticalAreaBoundaryPoint(35.668662, 139.474296),
          StatisticalAreaBoundaryPoint(35.668726, 139.473583),
          StatisticalAreaBoundaryPoint(35.669928, 139.473662),
          StatisticalAreaBoundaryPoint(35.669913, 139.476809),
        ],
      ),
      StatisticalAreaBoundary(
        code: '13206021002',
        name: '本町二丁目',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.664089, 139.477586),
          StatisticalAreaBoundaryPoint(35.664, 139.477623),
          StatisticalAreaBoundaryPoint(35.663644, 139.476171),
          StatisticalAreaBoundaryPoint(35.663577, 139.475817),
          StatisticalAreaBoundaryPoint(35.663564, 139.475459),
          StatisticalAreaBoundaryPoint(35.663592, 139.474996),
          StatisticalAreaBoundaryPoint(35.663696, 139.474539),
          StatisticalAreaBoundaryPoint(35.663891, 139.474113),
          StatisticalAreaBoundaryPoint(35.663952, 139.474067),
          StatisticalAreaBoundaryPoint(35.664034, 139.473916),
          StatisticalAreaBoundaryPoint(35.664037, 139.473951),
          StatisticalAreaBoundaryPoint(35.664092, 139.473908),
          StatisticalAreaBoundaryPoint(35.66417, 139.473432),
          StatisticalAreaBoundaryPoint(35.666741, 139.473574),
          StatisticalAreaBoundaryPoint(35.66679, 139.473338),
          StatisticalAreaBoundaryPoint(35.666901, 139.473049),
          StatisticalAreaBoundaryPoint(35.666965, 139.473587),
          StatisticalAreaBoundaryPoint(35.667542, 139.47362),
          StatisticalAreaBoundaryPoint(35.667567, 139.473577),
          StatisticalAreaBoundaryPoint(35.667696, 139.47355),
          StatisticalAreaBoundaryPoint(35.668154, 139.473554),
          StatisticalAreaBoundaryPoint(35.668566, 139.473574),
          StatisticalAreaBoundaryPoint(35.668613, 139.473621),
          StatisticalAreaBoundaryPoint(35.668726, 139.473583),
          StatisticalAreaBoundaryPoint(35.668662, 139.474296),
          StatisticalAreaBoundaryPoint(35.668552, 139.474828),
          StatisticalAreaBoundaryPoint(35.668436, 139.474782),
          StatisticalAreaBoundaryPoint(35.668299, 139.475142),
          StatisticalAreaBoundaryPoint(35.667963, 139.475786),
          StatisticalAreaBoundaryPoint(35.667434, 139.476338),
          StatisticalAreaBoundaryPoint(35.667228, 139.47648),
          StatisticalAreaBoundaryPoint(35.667337, 139.476732),
          StatisticalAreaBoundaryPoint(35.667196, 139.476804),
          StatisticalAreaBoundaryPoint(35.667092, 139.476907),
          StatisticalAreaBoundaryPoint(35.666729, 139.47701),
          StatisticalAreaBoundaryPoint(35.666656, 139.476675),
          StatisticalAreaBoundaryPoint(35.666333, 139.476726),
          StatisticalAreaBoundaryPoint(35.665371, 139.477049),
          StatisticalAreaBoundaryPoint(35.665273, 139.47716),
          StatisticalAreaBoundaryPoint(35.664955, 139.477297),
          StatisticalAreaBoundaryPoint(35.664089, 139.477586),
        ],
      ),
      StatisticalAreaBoundary(
        code: '13206019001',
        name: '矢崎町一丁目',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.66042, 139.481175),
          StatisticalAreaBoundaryPoint(35.659821, 139.481743),
          StatisticalAreaBoundaryPoint(35.659801, 139.481651),
          StatisticalAreaBoundaryPoint(35.660085, 139.481085),
          StatisticalAreaBoundaryPoint(35.660336, 139.480211),
          StatisticalAreaBoundaryPoint(35.660269, 139.479663),
          StatisticalAreaBoundaryPoint(35.660093, 139.479654),
          StatisticalAreaBoundaryPoint(35.660336, 139.479336),
          StatisticalAreaBoundaryPoint(35.660803, 139.478867),
          StatisticalAreaBoundaryPoint(35.661344, 139.478519),
          StatisticalAreaBoundaryPoint(35.661589, 139.478409),
          StatisticalAreaBoundaryPoint(35.661603, 139.478206),
          StatisticalAreaBoundaryPoint(35.661559, 139.478148),
          StatisticalAreaBoundaryPoint(35.661437, 139.478119),
          StatisticalAreaBoundaryPoint(35.6613, 139.478167),
          StatisticalAreaBoundaryPoint(35.661254, 139.47803),
          StatisticalAreaBoundaryPoint(35.661104, 139.477048),
          StatisticalAreaBoundaryPoint(35.661705, 139.476933),
          StatisticalAreaBoundaryPoint(35.662042, 139.477015),
          StatisticalAreaBoundaryPoint(35.662215, 139.476969),
          StatisticalAreaBoundaryPoint(35.662266, 139.477145),
          StatisticalAreaBoundaryPoint(35.662365, 139.477108),
          StatisticalAreaBoundaryPoint(35.662405, 139.477267),
          StatisticalAreaBoundaryPoint(35.662508, 139.477236),
          StatisticalAreaBoundaryPoint(35.662556, 139.477048),
          StatisticalAreaBoundaryPoint(35.662955, 139.476726),
          StatisticalAreaBoundaryPoint(35.662845, 139.476065),
          StatisticalAreaBoundaryPoint(35.662613, 139.476056),
          StatisticalAreaBoundaryPoint(35.662624, 139.475667),
          StatisticalAreaBoundaryPoint(35.66279, 139.475678),
          StatisticalAreaBoundaryPoint(35.662839, 139.475625),
          StatisticalAreaBoundaryPoint(35.663206, 139.475721),
          StatisticalAreaBoundaryPoint(35.663273, 139.475484),
          StatisticalAreaBoundaryPoint(35.663443, 139.475521),
          StatisticalAreaBoundaryPoint(35.663564, 139.475459),
          StatisticalAreaBoundaryPoint(35.663577, 139.475817),
          StatisticalAreaBoundaryPoint(35.663644, 139.476171),
          StatisticalAreaBoundaryPoint(35.664, 139.477623),
          StatisticalAreaBoundaryPoint(35.664089, 139.477586),
          StatisticalAreaBoundaryPoint(35.664407, 139.478972),
          StatisticalAreaBoundaryPoint(35.664727, 139.478999),
          StatisticalAreaBoundaryPoint(35.664419, 139.480152),
          StatisticalAreaBoundaryPoint(35.663929, 139.480596),
          StatisticalAreaBoundaryPoint(35.663826, 139.480556),
          StatisticalAreaBoundaryPoint(35.663737, 139.480433),
          StatisticalAreaBoundaryPoint(35.663592, 139.47992),
          StatisticalAreaBoundaryPoint(35.663056, 139.479931),
          StatisticalAreaBoundaryPoint(35.662724, 139.479825),
          StatisticalAreaBoundaryPoint(35.662255, 139.479879),
          StatisticalAreaBoundaryPoint(35.661783, 139.479822),
          StatisticalAreaBoundaryPoint(35.660665, 139.480868),
          StatisticalAreaBoundaryPoint(35.660419, 139.481113),
          StatisticalAreaBoundaryPoint(35.66042, 139.481175),
        ],
      ),
      StatisticalAreaBoundary(
        code: '132060170',
        name: '日吉町',
        isTarget: false,
        points: <StatisticalAreaBoundaryPoint>[
          StatisticalAreaBoundaryPoint(35.666453, 139.489804),
          StatisticalAreaBoundaryPoint(35.666301, 139.490219),
          StatisticalAreaBoundaryPoint(35.666091, 139.490405),
          StatisticalAreaBoundaryPoint(35.666126, 139.490566),
          StatisticalAreaBoundaryPoint(35.666317, 139.490592),
          StatisticalAreaBoundaryPoint(35.666503, 139.492578),
          StatisticalAreaBoundaryPoint(35.666263, 139.492579),
          StatisticalAreaBoundaryPoint(35.666134, 139.492981),
          StatisticalAreaBoundaryPoint(35.665952, 139.493098),
          StatisticalAreaBoundaryPoint(35.665493, 139.493145),
          StatisticalAreaBoundaryPoint(35.665019, 139.493238),
          StatisticalAreaBoundaryPoint(35.66498, 139.493172),
          StatisticalAreaBoundaryPoint(35.664448, 139.493145),
          StatisticalAreaBoundaryPoint(35.664387, 139.493062),
          StatisticalAreaBoundaryPoint(35.664015, 139.493014),
          StatisticalAreaBoundaryPoint(35.664061, 139.492597),
          StatisticalAreaBoundaryPoint(35.664344, 139.491626),
          StatisticalAreaBoundaryPoint(35.664367, 139.491442),
          StatisticalAreaBoundaryPoint(35.66469, 139.490607),
          StatisticalAreaBoundaryPoint(35.664685, 139.490461),
          StatisticalAreaBoundaryPoint(35.663955, 139.490586),
          StatisticalAreaBoundaryPoint(35.66346, 139.490768),
          StatisticalAreaBoundaryPoint(35.663025, 139.490725),
          StatisticalAreaBoundaryPoint(35.662703, 139.490749),
          StatisticalAreaBoundaryPoint(35.662452, 139.49061),
          StatisticalAreaBoundaryPoint(35.662013, 139.490562),
          StatisticalAreaBoundaryPoint(35.661699, 139.49049),
          StatisticalAreaBoundaryPoint(35.66154, 139.490369),
          StatisticalAreaBoundaryPoint(35.660622, 139.489413),
          StatisticalAreaBoundaryPoint(35.660513, 139.489227),
          StatisticalAreaBoundaryPoint(35.660462, 139.488237),
          StatisticalAreaBoundaryPoint(35.660626, 139.487403),
          StatisticalAreaBoundaryPoint(35.660474, 139.48591),
          StatisticalAreaBoundaryPoint(35.660493, 139.485233),
          StatisticalAreaBoundaryPoint(35.660454, 139.484308),
          StatisticalAreaBoundaryPoint(35.660541, 139.483908),
          StatisticalAreaBoundaryPoint(35.660538, 139.483493),
          StatisticalAreaBoundaryPoint(35.660419, 139.481113),
          StatisticalAreaBoundaryPoint(35.66177, 139.479826),
          StatisticalAreaBoundaryPoint(35.662255, 139.479879),
          StatisticalAreaBoundaryPoint(35.662724, 139.479825),
          StatisticalAreaBoundaryPoint(35.663056, 139.479931),
          StatisticalAreaBoundaryPoint(35.663592, 139.47992),
          StatisticalAreaBoundaryPoint(35.663737, 139.480433),
          StatisticalAreaBoundaryPoint(35.663826, 139.480556),
          StatisticalAreaBoundaryPoint(35.663929, 139.480596),
          StatisticalAreaBoundaryPoint(35.664419, 139.480152),
          StatisticalAreaBoundaryPoint(35.664727, 139.478999),
          StatisticalAreaBoundaryPoint(35.664792, 139.478979),
          StatisticalAreaBoundaryPoint(35.664956, 139.479148),
          StatisticalAreaBoundaryPoint(35.664805, 139.480007),
          StatisticalAreaBoundaryPoint(35.664758, 139.480668),
          StatisticalAreaBoundaryPoint(35.664779, 139.480842),
          StatisticalAreaBoundaryPoint(35.664826, 139.480923),
          StatisticalAreaBoundaryPoint(35.665208, 139.481171),
          StatisticalAreaBoundaryPoint(35.666485, 139.48109),
          StatisticalAreaBoundaryPoint(35.666495, 139.481066),
          StatisticalAreaBoundaryPoint(35.666559, 139.481162),
          StatisticalAreaBoundaryPoint(35.666597, 139.481599),
          StatisticalAreaBoundaryPoint(35.666913, 139.482486),
          StatisticalAreaBoundaryPoint(35.666937, 139.482668),
          StatisticalAreaBoundaryPoint(35.666937, 139.483001),
          StatisticalAreaBoundaryPoint(35.666867, 139.483528),
          StatisticalAreaBoundaryPoint(35.667203, 139.48725),
          StatisticalAreaBoundaryPoint(35.667201, 139.487623),
          StatisticalAreaBoundaryPoint(35.667165, 139.487832),
          StatisticalAreaBoundaryPoint(35.666974, 139.488457),
          StatisticalAreaBoundaryPoint(35.666453, 139.489804),
        ],
      ),
    ],
  );

  final String datasetLabel;
  final StatisticalBoundaryScope scope;
  final String sourceLabel;
  final String sourceUrl;
  final String license;
  final String boundaryNote;
  final String simplificationNote;
  final List<StatisticalAreaBoundary> areas;

  StatisticalAreaBoundary get target {
    for (final area in areas) {
      if (area.isTarget) return area;
    }
    throw StateError('A target statistical boundary is required.');
  }
}
