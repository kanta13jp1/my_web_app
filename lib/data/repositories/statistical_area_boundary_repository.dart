import '../../domain/models/statistical_area_boundary.dart';
import '../services/statistical_area_boundary_service.dart';

abstract interface class StatisticalAreaBoundaryRepository {
  Future<StatisticalAreaBoundaryCatalog> loadCatalog(
    StatisticalBoundaryScope scope,
  );
}

class RemoteStatisticalAreaBoundaryRepository
    implements StatisticalAreaBoundaryRepository {
  RemoteStatisticalAreaBoundaryRepository({required this.service});

  final StatisticalAreaBoundaryService service;
  final Map<StatisticalBoundaryScope, StatisticalAreaBoundaryCatalog> _cache =
      <StatisticalBoundaryScope, StatisticalAreaBoundaryCatalog>{};
  final Map<StatisticalBoundaryScope, Future<StatisticalAreaBoundaryCatalog>>
      _inFlight =
      <StatisticalBoundaryScope, Future<StatisticalAreaBoundaryCatalog>>{};
  Future<Map<String, dynamic>>? _prefectureTopology;

  @override
  Future<StatisticalAreaBoundaryCatalog> loadCatalog(
    StatisticalBoundaryScope scope,
  ) async {
    final cached = _cache[scope];
    if (cached != null) return cached;
    final active = _inFlight[scope];
    if (active != null) return active;
    final request = _load(scope);
    _inFlight[scope] = request;
    try {
      final catalog = await request;
      _cache[scope] = catalog;
      return catalog;
    } finally {
      _inFlight.remove(scope);
    }
  }

  Future<StatisticalAreaBoundaryCatalog> _load(
    StatisticalBoundaryScope scope,
  ) async {
    try {
      final topology = switch (scope) {
        StatisticalBoundaryScope.kanto ||
        StatisticalBoundaryScope.japan =>
          await (_prefectureTopology ??= service.fetchTopology(scope)),
        _ => await service.fetchTopology(scope),
      };
      const decoder = FuchuStatisticalAreaTopologyDecoder();
      return scope == StatisticalBoundaryScope.fuchuCity
          ? decoder.decode(topology)
          : decoder.decodeAdministrative(topology, scope);
    } catch (_) {
      if (scope == StatisticalBoundaryScope.kanto ||
          scope == StatisticalBoundaryScope.japan) {
        _prefectureTopology = null;
      }
      rethrow;
    }
  }
}

class FuchuStatisticalAreaTopologyDecoder {
  const FuchuStatisticalAreaTopologyDecoder();

  StatisticalAreaBoundaryCatalog decode(Map<String, dynamic> topology) {
    if (topology['type'] != 'Topology') {
      throw const StatisticalAreaBoundaryException(
        '府中市のTopoJSONではありません。',
      );
    }

    final decodedArcs = _decodeArcs(
      _list(topology['arcs']),
      _map(topology['transform']),
    );
    final objects = _map(topology['objects']);
    final townObject = _map(objects['town']);
    final geometries = _list(townObject['geometries']);
    final areas = <StatisticalAreaBoundary>[];

    for (final rawGeometry in geometries) {
      final geometry = _map(rawGeometry);
      if (geometry['type'] != 'Polygon') continue;
      final properties = _map(geometry['properties']);
      final code = properties['KEY_CODE']?.toString().trim() ?? '';
      final name = properties['S_NAME']?.toString().trim() ?? '';
      if (!code.startsWith('13206') || name.isEmpty) continue;

      final points = _stitchRing(
        _primaryRing(_list(geometry['arcs'])),
        decodedArcs,
      );
      if (points.length < 4) continue;
      areas.add(
        StatisticalAreaBoundary(
          code: code,
          name: name,
          isTarget: code == '13206021001',
          points: List<StatisticalAreaBoundaryPoint>.unmodifiable(points),
          centerLatitude: _nullableDouble(properties['Y_CODE']),
          centerLongitude: _nullableDouble(properties['X_CODE']),
        ),
      );
    }

    areas.sort((left, right) => left.code.compareTo(right.code));
    if (areas.length < 100 || !areas.any((area) => area.isTarget)) {
      throw const StatisticalAreaBoundaryException(
        '府中市内の町丁境界を十分に読み込めませんでした。',
      );
    }

    return StatisticalAreaBoundaryCatalog(
      scope: StatisticalBoundaryScope.fuchuCity,
      municipalityName: '東京都府中市',
      datasetLabel: '令和2年国勢調査 町丁・字等別境界データ',
      sourceLabel: 'CODH 国勢調査町丁・字等別境界データセット',
      sourceUrl:
          'https://geoshape.ex.nii.ac.jp/ka/topojson/2020/13/r2ka13206.topojson',
      license: 'CC BY 4.0',
      boundaryNote: '統計調査区を基にした境界で、住居表示などの実際の町丁境界と一致しない場合があります。',
      simplificationNote: '画面表示用に約2m精度で簡略化しています。',
      areas: List<StatisticalAreaBoundary>.unmodifiable(areas),
    );
  }

  StatisticalAreaBoundaryCatalog decodeAdministrative(
    Map<String, dynamic> topology,
    StatisticalBoundaryScope scope,
  ) {
    if (scope == StatisticalBoundaryScope.fuchuCity ||
        topology['type'] != 'Topology') {
      throw const StatisticalAreaBoundaryException(
        '行政区域のTopoJSONではありません。',
      );
    }
    final decodedArcs = _decodeArcs(
      _list(topology['arcs']),
      _map(topology['transform']),
    );
    final objects = _map(topology['objects']);
    final object = _map(objects.values.isEmpty ? null : objects.values.first);
    final grouped = <String,
        ({
      String name,
      List<List<StatisticalAreaBoundaryPoint>> polygons,
    })>{};
    final kantoCodes = <String>{'08', '09', '10', '11', '12', '13', '14'};
    final tolerance = scope == StatisticalBoundaryScope.tokyo ? 0.0003 : 0.008;

    for (final rawGeometry in _list(object['geometries'])) {
      final geometry = _map(rawGeometry);
      final properties = _map(geometry['properties']);
      final code = properties['N03_007']?.toString().trim() ?? '';
      final name = (scope == StatisticalBoundaryScope.tokyo
              ? properties['N03_004']
              : properties['N03_001'])
          ?.toString()
          .trim();
      if (code.isEmpty || name == null || name.isEmpty) continue;
      if (scope == StatisticalBoundaryScope.tokyo && !code.startsWith('13')) {
        continue;
      }
      final prefectureCode = code.substring(0, code.length >= 2 ? 2 : 1);
      if (scope == StatisticalBoundaryScope.kanto &&
          !kantoCodes.contains(prefectureCode)) {
        continue;
      }
      final groupCode =
          scope == StatisticalBoundaryScope.tokyo ? code : prefectureCode;
      final rings = _exteriorRings(
        geometry['type']?.toString() ?? '',
        _list(geometry['arcs']),
      );
      final polygons = <List<StatisticalAreaBoundaryPoint>>[];
      for (final ring in rings) {
        final polygon = _stitchRing(
          ring,
          decodedArcs,
          tolerance: tolerance,
        );
        if (polygon.length >= 4) polygons.add(polygon);
      }
      if (polygons.isEmpty) continue;
      final existing = grouped[groupCode];
      grouped[groupCode] = (
        name: name,
        polygons: <List<StatisticalAreaBoundaryPoint>>[
          if (existing != null) ...existing.polygons,
          ...polygons,
        ],
      );
    }

    final areas = <StatisticalAreaBoundary>[];
    for (final entry in grouped.entries) {
      final polygons = [...entry.value.polygons]
        ..sort((left, right) => right.length.compareTo(left.length));
      areas.add(
        StatisticalAreaBoundary(
          code: entry.key,
          name: entry.value.name,
          isTarget: entry.key == scope.defaultAreaCode,
          points: List<StatisticalAreaBoundaryPoint>.unmodifiable(
            polygons.first,
          ),
          additionalPolygons:
              List<List<StatisticalAreaBoundaryPoint>>.unmodifiable(
            polygons
                .skip(1)
                .map(List<StatisticalAreaBoundaryPoint>.unmodifiable),
          ),
        ),
      );
    }
    areas.sort((left, right) => left.code.compareTo(right.code));
    final minimumCount = switch (scope) {
      StatisticalBoundaryScope.tokyo => 60,
      StatisticalBoundaryScope.kanto => 7,
      StatisticalBoundaryScope.japan => 47,
      StatisticalBoundaryScope.fuchuCity => 100,
    };
    if (areas.length < minimumCount || !areas.any((area) => area.isTarget)) {
      throw const StatisticalAreaBoundaryException(
        '行政区域境界を十分に読み込めませんでした。',
      );
    }
    final isTokyo = scope == StatisticalBoundaryScope.tokyo;
    return StatisticalAreaBoundaryCatalog(
      scope: scope,
      municipalityName: scope.regionLabel,
      datasetLabel: '歴史的行政区域データセットβ版（2023-01-01行政区域）',
      sourceLabel: 'CODH 歴史的行政区域データセットβ版',
      sourceUrl: isTokyo
          ? 'https://geoshape.ex.nii.ac.jp/city/choropleth/13_city.html'
          : 'https://geoshape.ex.nii.ac.jp/city/choropleth/jp_pref.html',
      license: 'CC BY 4.0',
      boundaryNote: '国土数値情報を変換した2023年時点の行政区域です。最新の法定境界を保証するものではありません。',
      simplificationNote: isTokyo
          ? '軽量表示用の低解像度TopoJSONをさらに約30m許容で簡略化しています。'
          : '軽量表示用の粗解像度TopoJSONをさらに約800m許容で簡略化しています。離島などは簡略表示です。',
      areas: List<StatisticalAreaBoundary>.unmodifiable(areas),
    );
  }

  List<List<StatisticalAreaBoundaryPoint>> _decodeArcs(
    List<dynamic> rawArcs,
    Map<String, dynamic> transform,
  ) {
    final scale = _list(transform['scale']);
    final translate = _list(transform['translate']);
    final hasTransform = scale.length >= 2 && translate.length >= 2;
    final scaleX = hasTransform ? _double(scale[0]) : 1;
    final scaleY = hasTransform ? _double(scale[1]) : 1;
    final translateX = hasTransform ? _double(translate[0]) : 0;
    final translateY = hasTransform ? _double(translate[1]) : 0;

    return rawArcs.map((rawArc) {
      var x = 0.0;
      var y = 0.0;
      final points = <StatisticalAreaBoundaryPoint>[];
      for (final rawCoordinate in _list(rawArc)) {
        final coordinate = _list(rawCoordinate);
        if (coordinate.length < 2) continue;
        if (hasTransform) {
          x += _double(coordinate[0]);
          y += _double(coordinate[1]);
          points.add(
            StatisticalAreaBoundaryPoint(
              y * scaleY + translateY,
              x * scaleX + translateX,
            ),
          );
        } else {
          points.add(
            StatisticalAreaBoundaryPoint(
              _double(coordinate[1]),
              _double(coordinate[0]),
            ),
          );
        }
      }
      return points;
    }).toList(growable: false);
  }

  List<int> _primaryRing(List<dynamic> rawArcs) {
    dynamic ring = rawArcs;
    while (ring is List && ring.isNotEmpty && ring.first is List) {
      ring = ring.first;
    }
    if (ring is! List) return const <int>[];
    return ring.whereType<num>().map((value) => value.toInt()).toList();
  }

  List<List<int>> _exteriorRings(String type, List<dynamic> rawArcs) {
    if (type == 'Polygon') {
      if (rawArcs.isEmpty) return const <List<int>>[];
      return <List<int>>[_integerRing(_list(rawArcs.first))];
    }
    if (type != 'MultiPolygon') return const <List<int>>[];
    return <List<int>>[
      for (final rawPolygon in rawArcs)
        if (_list(rawPolygon).isNotEmpty)
          _integerRing(_list(_list(rawPolygon).first)),
    ];
  }

  List<int> _integerRing(List<dynamic> values) =>
      values.whereType<num>().map((value) => value.toInt()).toList();

  List<StatisticalAreaBoundaryPoint> _stitchRing(
    List<int> arcIndexes,
    List<List<StatisticalAreaBoundaryPoint>> arcs, {
    double tolerance = 0.00002,
  }) {
    final ring = <StatisticalAreaBoundaryPoint>[];
    for (final signedIndex in arcIndexes) {
      final arcIndex = signedIndex >= 0 ? signedIndex : -signedIndex - 1;
      if (arcIndex < 0 || arcIndex >= arcs.length) continue;
      final source =
          signedIndex >= 0 ? arcs[arcIndex] : arcs[arcIndex].reversed;
      final points = source.toList(growable: false);
      for (var index = ring.isEmpty ? 0 : 1; index < points.length; index++) {
        ring.add(points[index]);
      }
    }
    if (ring.length < 3) return ring;
    final simplified = _simplify(ring, tolerance);
    if (!_samePoint(simplified.first, simplified.last)) {
      simplified.add(simplified.first);
    }
    return simplified;
  }

  List<StatisticalAreaBoundaryPoint> _simplify(
    List<StatisticalAreaBoundaryPoint> closedRing,
    double tolerance,
  ) {
    final source = List<StatisticalAreaBoundaryPoint>.of(closedRing);
    if (source.length > 1 && _samePoint(source.first, source.last)) {
      source.removeLast();
    }
    if (source.length <= 3) return source;
    final markers = List<bool>.filled(source.length, false);
    markers[0] = true;
    markers[source.length - 1] = true;
    _markDouglasPeucker(
      source,
      0,
      source.length - 1,
      tolerance * tolerance,
      markers,
    );
    final result = <StatisticalAreaBoundaryPoint>[
      for (var index = 0; index < source.length; index++)
        if (markers[index]) source[index],
    ];
    return result.length >= 3 ? result : source;
  }

  void _markDouglasPeucker(
    List<StatisticalAreaBoundaryPoint> points,
    int first,
    int last,
    double squaredTolerance,
    List<bool> markers,
  ) {
    var maximumDistance = squaredTolerance;
    int? splitIndex;
    for (var index = first + 1; index < last; index++) {
      final distance = _squaredSegmentDistance(
        points[index],
        points[first],
        points[last],
      );
      if (distance > maximumDistance) {
        maximumDistance = distance;
        splitIndex = index;
      }
    }
    if (splitIndex == null) return;
    if (splitIndex - first > 1) {
      _markDouglasPeucker(
        points,
        first,
        splitIndex,
        squaredTolerance,
        markers,
      );
    }
    markers[splitIndex] = true;
    if (last - splitIndex > 1) {
      _markDouglasPeucker(
        points,
        splitIndex,
        last,
        squaredTolerance,
        markers,
      );
    }
  }

  double _squaredSegmentDistance(
    StatisticalAreaBoundaryPoint point,
    StatisticalAreaBoundaryPoint start,
    StatisticalAreaBoundaryPoint end,
  ) {
    var x = start.longitude;
    var y = start.latitude;
    var deltaX = end.longitude - x;
    var deltaY = end.latitude - y;
    if (deltaX != 0 || deltaY != 0) {
      final ratio =
          ((point.longitude - x) * deltaX + (point.latitude - y) * deltaY) /
              (deltaX * deltaX + deltaY * deltaY);
      if (ratio > 1) {
        x = end.longitude;
        y = end.latitude;
      } else if (ratio > 0) {
        x += deltaX * ratio;
        y += deltaY * ratio;
      }
    }
    deltaX = point.longitude - x;
    deltaY = point.latitude - y;
    return deltaX * deltaX + deltaY * deltaY;
  }

  bool _samePoint(
    StatisticalAreaBoundaryPoint left,
    StatisticalAreaBoundaryPoint right,
  ) {
    return left.latitude == right.latitude && left.longitude == right.longitude;
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
