import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/statistical_area_boundary.dart';

abstract interface class StatisticalAreaBoundaryService {
  Future<Map<String, dynamic>> fetchTopology(StatisticalBoundaryScope scope);
}

class CodhStatisticalAreaBoundaryService
    implements StatisticalAreaBoundaryService {
  CodhStatisticalAreaBoundaryService({http.Client? client}) : _client = client;

  static final topologyUri = Uri.parse(
    'https://geoshape.ex.nii.ac.jp/ka/topojson/2020/13/r2ka13206.topojson',
  );
  static final tokyoMunicipalityTopologyUri = Uri.parse(
    'https://geoshape.ex.nii.ac.jp/city/topojson/20230101/13/13_city.l.topojson',
  );
  static final japanPrefectureTopologyUri = Uri.parse(
    'https://geoshape.ex.nii.ac.jp/city/topojson/20230101/jp_pref.c.topojson',
  );

  final http.Client? _client;

  @override
  Future<Map<String, dynamic>> fetchTopology(
    StatisticalBoundaryScope scope,
  ) async {
    final uri = switch (scope) {
      StatisticalBoundaryScope.fuchuCity => topologyUri,
      StatisticalBoundaryScope.tokyo => tokyoMunicipalityTopologyUri,
      StatisticalBoundaryScope.kanto ||
      StatisticalBoundaryScope.japan =>
        japanPrefectureTopologyUri,
    };
    final ownedClient = _client == null ? http.Client() : null;
    final client = _client ?? ownedClient!;
    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StatisticalAreaBoundaryException('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const StatisticalAreaBoundaryException(
          '境界データの形式を確認できませんでした。',
        );
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on StatisticalAreaBoundaryException {
      rethrow;
    } catch (error) {
      throw StatisticalAreaBoundaryException(error.toString());
    } finally {
      ownedClient?.close();
    }
  }
}

class StatisticalAreaBoundaryException implements Exception {
  const StatisticalAreaBoundaryException(this.message);

  final String message;

  @override
  String toString() => message;
}
