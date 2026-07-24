import 'package:supabase_flutter/supabase_flutter.dart';

/// OMOCHA WORKS「自律オペレーションコンソール」の実データ取得サービス。
///
/// Edge Function `autonomous-ops` を呼び、GitHub Actions 由来の表示
/// スナップショットを取得する。実データはログイン済みオーナー限定
/// (EF 側で `user_profiles.is_admin` を検証)。未認証 / 非オーナー /
/// 通信失敗時は [fetch] が `null` を返し、ページはシミュレーションに
/// フォールバックする。
class AutonomousOpsService {
  AutonomousOpsService({SupabaseClient? client}) : _injected = client;

  // コンストラクタでは Supabase.instance に触れない (テストで未初期化でも
  // サブクラスが isSignedIn/fetch を override できるよう遅延解決する)。
  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  /// ログイン済みか (実データ取得を試みる資格があるか)。
  bool get isSignedIn => _client.auth.currentSession != null;

  /// 実データスナップショットを取得する。
  ///
  /// - 未ログイン: `null` (呼び出し自体を行わない)。
  /// - オーナーだがトークン未構成: `configured=false` の DTO を返す
  ///   (ページはシミュレーション継続 + 構成ヒント表示に使える)。
  /// - 実データあり: `live=true` の DTO。
  /// - 非オーナー / エラー: `null` (フォールバック)。
  Future<OpsSnapshotDto?> fetch() async {
    if (!isSignedIn) return null;
    try {
      final response = await _client.functions.invoke(
        'autonomous-ops',
        body: const <String, dynamic>{},
      );
      final data = response.data;
      if (data is! Map) return null;
      if (data['ok'] != true) return null;
      final configured = data['configured'] == true;
      final snapshot = data['snapshot'];
      if (snapshot is! Map) return null;
      return OpsSnapshotDto.fromJson(
        Map<String, dynamic>.from(snapshot),
        configured: configured,
      );
    } catch (_) {
      // 403 (非オーナー) / 5xx / ネットワーク断はフォールバック扱い。
      return null;
    }
  }
}

/// EF から受け取る表示スナップショット。
class OpsSnapshotDto {
  const OpsSnapshotDto({
    required this.configured,
    required this.live,
    required this.tasks,
    required this.activities,
    required this.completedToday,
    required this.automatedHours,
    required this.revenueImpact,
    required this.slaCompliance,
    required this.throughput,
    required this.throughputHistory,
  });

  final bool configured;
  final bool live;
  final List<OpsTaskDto> tasks;
  final List<OpsActivityDto> activities;
  final int completedToday;
  final double automatedHours;
  final int revenueImpact;
  final double slaCompliance;
  final double throughput;
  final List<double> throughputHistory;

  factory OpsSnapshotDto.fromJson(
    Map<String, dynamic> json, {
    required bool configured,
  }) {
    final kpis = json['kpis'] is Map
        ? Map<String, dynamic>.from(json['kpis'] as Map)
        : const <String, dynamic>{};
    return OpsSnapshotDto(
      configured: configured,
      live: json['live'] == true,
      tasks: _list(json['tasks'])
          .map(OpsTaskDto.fromJson)
          .toList(growable: false),
      activities: _list(json['activities'])
          .map(OpsActivityDto.fromJson)
          .toList(growable: false),
      completedToday: _int(kpis['completedToday']),
      automatedHours: _double(kpis['automatedHours']),
      revenueImpact: _int(kpis['revenueImpact']),
      slaCompliance: _double(kpis['slaCompliance']),
      throughput: _double(kpis['throughput']),
      throughputHistory: _list(json['throughputHistory'])
          .map((e) => _double(e))
          .toList(growable: false),
    );
  }
}

class OpsTaskDto {
  const OpsTaskDto({
    required this.code,
    required this.dept,
    required this.title,
    required this.valueYen,
    required this.lane,
    required this.agentId,
  });

  final String code;
  final String dept;
  final String title;
  final int valueYen;
  final String lane; // backlog | progress | review | done
  final String? agentId; // H | K | M | B | S

  factory OpsTaskDto.fromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return OpsTaskDto(
      code: _string(json['code']),
      dept: _string(json['dept']),
      title: _string(json['title']),
      valueYen: _int(json['valueYen']),
      lane: _string(json['lane']),
      agentId: json['agentId'] is String ? json['agentId'] as String : null,
    );
  }
}

class OpsActivityDto {
  const OpsActivityDto({
    required this.text,
    required this.time,
    required this.agentId,
  });

  final String text;
  final String time;
  final String? agentId;

  factory OpsActivityDto.fromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return OpsActivityDto(
      text: _string(json['text']),
      time: _string(json['time']),
      agentId: json['agentId'] is String ? json['agentId'] as String : null,
    );
  }
}

// ── 防御的パースヘルパー ─────────────────────────────────────
List<Object?> _list(Object? value) =>
    value is List ? value : const <Object?>[];

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _double(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
