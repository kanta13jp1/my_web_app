import 'dart:convert';

import 'package:http/http.dart' as http;

abstract interface class StatisticalAreaBoundaryService {
  Future<Map<String, dynamic>> fetchFuchuTopology();
}

class CodhStatisticalAreaBoundaryService
    implements StatisticalAreaBoundaryService {
  CodhStatisticalAreaBoundaryService({http.Client? client}) : _client = client;

  static final topologyUri = Uri.parse(
    'https://geoshape.ex.nii.ac.jp/ka/topojson/2020/13/r2ka13206.topojson',
  );

  final http.Client? _client;

  @override
  Future<Map<String, dynamic>> fetchFuchuTopology() async {
    final ownedClient = _client == null ? http.Client() : null;
    final client = _client ?? ownedClient!;
    try {
      final response = await client.get(topologyUri);
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
