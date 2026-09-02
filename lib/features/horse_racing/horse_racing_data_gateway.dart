import 'package:supabase_flutter/supabase_flutter.dart';

class HorseRacingDashboardSnapshot {
  const HorseRacingDashboardSnapshot({
    this.todayRaces = const [],
    this.predictionHistory = const [],
    this.betTickets = const [],
    this.accuracyStats = const {},
  });

  final List<Map<String, dynamic>> todayRaces;
  final List<Map<String, dynamic>> predictionHistory;
  final List<Map<String, dynamic>> betTickets;
  final Map<String, dynamic> accuracyStats;
}

abstract interface class HorseRacingDataGateway {
  bool get isAuthenticated;

  String? get userId;

  Future<HorseRacingDashboardSnapshot> loadDashboard({
    required String date,
    required String raceType,
  });

  Future<List<Map<String, dynamic>>> fetchBetTickets();

  Future<Map<String, dynamic>> runPredictions({
    required String date,
    required String raceType,
    String? raceId,
  });

  Future<void> refreshAccuracyLearning();

  Future<Map<String, dynamic>> runLearningBackfill({required String dateTo});

  Future<void> createBetTicket(Map<String, dynamic> metadata);

  Future<void> settleBetTicket({
    required Object ticketId,
    required Map<String, dynamic> metadata,
  });
}

class SupabaseHorseRacingDataGateway implements HorseRacingDataGateway {
  SupabaseHorseRacingDataGateway({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  bool get isAuthenticated => _client.auth.currentUser != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<HorseRacingDashboardSnapshot> loadDashboard({
    required String date,
    required String raceType,
  }) async {
    final results = await Future.wait([
      _invoke('horseracing.today', body: {'date': date, 'type': raceType}),
      _invoke('horseracing.predictions', body: const {'limit': 30}),
      _invoke('horseracing.accuracy'),
    ]);
    final today = _asMap(results[0]);
    final history = _asMap(results[1]);
    final accuracy = _asMap(results[2]);
    final stats = _asMap(accuracy['stats']);

    return HorseRacingDashboardSnapshot(
      todayRaces: _asMapList(today['races']),
      predictionHistory: _asMapList(history['predictions']),
      betTickets: await fetchBetTickets(),
      accuracyStats: {
        ...stats,
        'recent_hits': accuracy['recent_hits'],
        'bet_type_accuracy': accuracy['bet_type_accuracy'],
        'learning': accuracy['learning'],
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBetTickets() async {
    final currentUserId = userId;
    if (currentUserId == null) return const [];
    final rows = await _client
        .from('hub_data')
        .select('id, metadata, created_at')
        .eq('source', 'horse_bet_ticket')
        .filter('metadata->>user_id', 'eq', currentUserId)
        .order('created_at', ascending: false)
        .limit(80);
    return rows
        .whereType<Map>()
        .map(_asMap)
        .where((row) => row.isNotEmpty)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> runPredictions({
    required String date,
    required String raceType,
    String? raceId,
  }) async {
    return _asMap(
      await _invoke(
        'horseracing.predict_all',
        body: {
          'date': date,
          'type': raceType,
          'limit': raceId == null ? 80 : 1,
          if (raceId != null) 'race_id': raceId,
          if (raceId != null) 'force': true,
        },
      ),
    );
  }

  @override
  Future<void> refreshAccuracyLearning() async {
    await _invoke('horseracing.evaluate_accuracy');
  }

  @override
  Future<Map<String, dynamic>> runLearningBackfill({
    required String dateTo,
  }) async {
    return _asMap(
      await _invoke(
        'horseracing.backfill_learning_data',
        body: {'date_to': dateTo, 'days': 21, 'limit': 160},
      ),
    );
  }

  @override
  Future<void> createBetTicket(Map<String, dynamic> metadata) async {
    await _client.from('hub_data').insert({
      'source': 'horse_bet_ticket',
      'metadata': metadata,
    });
  }

  @override
  Future<void> settleBetTicket({
    required Object ticketId,
    required Map<String, dynamic> metadata,
  }) async {
    final currentUserId = userId;
    if (currentUserId == null) return;
    await _client
        .from('hub_data')
        .update({'metadata': metadata})
        .eq('id', ticketId)
        .filter('metadata->>user_id', 'eq', currentUserId);
  }

  Future<dynamic> _invoke(
    String action, {
    Map<String, dynamic> body = const {},
  }) async {
    final response = await _client.functions.invoke(
      'tools-hub',
      body: {'action': action, ...body},
    );
    return response.data;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(_asMap)
      .where((row) => row.isNotEmpty)
      .toList();
}
