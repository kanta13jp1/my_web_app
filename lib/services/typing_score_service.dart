import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/typing_game.dart';

/// Immutable, retryable report. The server computes score; this is not proof
/// that a human typed the letters or that the client's clock is trustworthy.
class TypingRunReport {
  TypingRunReport.fromGame(TypingGame game)
      : id = _newRunId(),
        mode = game.mode.name,
        correct = game.correct,
        mistakes = game.mistakes,
        words = game.words,
        elapsedMs = game.elapsed.inMilliseconds {
    if (!game.finished) throw StateError('Finish the run before saving');
  }

  final String id;
  final String mode;
  final int correct;
  final int mistakes;
  final int words;
  final int elapsedMs;

  static String _newRunId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'revision': 'romaji36-v1',
        'mode': mode,
        'correct': correct,
        'mistakes': mistakes,
        'words': words,
        'elapsed_ms': elapsedMs,
      };
}

abstract class TypingScoreStore {
  String? get accountId;
  Stream<String?> get accountChanges;
  Future<void> save(TypingRunReport report);
  Future<List<Map<String, dynamic>>> mine();
  Future<List<Map<String, dynamic>>> ranking();
  Future<void> publish(String id, String alias);
  Future<void> withdraw(String id);
  Future<void> delete(String id);
}

class SupabaseTypingScoreStore implements TypingScoreStore {
  SupabaseTypingScoreStore(this.client);
  final SupabaseClient client;

  @override
  Stream<String?> get accountChanges =>
      client.auth.onAuthStateChange.map((_) => accountId);

  @override
  String? get accountId {
    final user = client.auth.currentUser;
    return user == null || user.isAnonymous ? null : user.id;
  }

  Future<dynamic> _call(String action, [Map<String, dynamic>? data]) async {
    final owner = accountId;
    if (owner == null) throw StateError('login_required');
    final result = await client.rpc(
      'typing_game_records',
      params: {'p_action': action, 'p_data': data ?? <String, dynamic>{}},
    ).timeout(const Duration(seconds: 10));
    if (accountId != owner) throw StateError('account_changed');
    return result;
  }

  @override
  Future<void> save(TypingRunReport report) async {
    await _call('save', report.toJson());
  }

  Future<List<Map<String, dynamic>>> _list(String action) async {
    final data = await _call(action) as List;
    return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> mine() => _list('mine');
  @override
  Future<List<Map<String, dynamic>>> ranking() => _list('ranking');
  @override
  Future<void> publish(String id, String alias) async {
    await _call('publish', {'id': id, 'alias': alias});
  }

  @override
  Future<void> withdraw(String id) async {
    await _call('withdraw', {'id': id});
  }

  @override
  Future<void> delete(String id) async {
    await _call('delete', {'id': id});
  }
}
