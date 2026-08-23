import '../../domain/models/statistical_area_boundary.dart';
import '../services/statistical_area_boundary_service.dart';

abstract interface class StatisticalAreaBoundaryRepository {
  Future<StatisticalAreaBoundaryCatalog> loadFuchuCatalog();
}

class RemoteStatisticalAreaBoundaryRepository
    implements StatisticalAreaBoundaryRepository {
  const RemoteStatisticalAreaBoundaryRepository({required this.service});

  final StatisticalAreaBoundaryService service;

  @override
  Future<StatisticalAreaBoundaryCatalog> loadFuchuCatalog() async {
    final topology = await service.fetchFuchuTopology();
    return const FuchuStatisticalAreaTopologyDecoder().decode(topology);
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

  List<StatisticalAreaBoundaryPoint> _stitchRing(
    List<int> arcIndexes,
    List<List<StatisticalAreaBoundaryPoint>> arcs,
  ) {
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
    final simplified = _simplify(ring, 0.00002);
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
