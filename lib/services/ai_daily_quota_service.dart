import 'package:supabase_flutter/supabase_flutter.dart';

class AiDailyQuotaStatus {
  const AiDailyQuotaStatus({
    required this.plan,
    required this.used,
    required this.dailyLimit,
    required this.remaining,
    required this.quotaDate,
    this.resetAt,
    this.allowed = true,
  });

  final String plan;
  final int used;
  final int dailyLimit;
  final int remaining;
  final String quotaDate;
  final DateTime? resetAt;
  final bool allowed;

  bool get isLimitReached => !allowed || remaining <= 0 || used >= dailyLimit;

  double get usageRatio =>
      dailyLimit <= 0 ? 1.0 : (used / dailyLimit).clamp(0.0, 1.0);

  static int _parseInt(Object? raw, {int fallback = 0}) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  factory AiDailyQuotaStatus.fromJson(Map<String, dynamic> json) {
    final limit = _parseInt(json['daily_limit'], fallback: 50);
    final used = _parseInt(json['used'], fallback: 0);
    final remainingRaw = json['remaining'];
    final remaining = remainingRaw != null
        ? _parseInt(remainingRaw, fallback: 0)
        : (limit - used).clamp(0, limit);
    final resetRaw = json['reset_at']?.toString().trim();
    return AiDailyQuotaStatus(
      plan: (json['plan']?.toString().trim().isNotEmpty == true)
          ? json['plan'].toString().trim().toLowerCase()
          : 'free',
      used: used < 0 ? 0 : used,
      dailyLimit: limit <= 0 ? 50 : limit,
      remaining: remaining < 0 ? 0 : remaining,
      quotaDate: (json['quota_date']?.toString().trim().isNotEmpty == true)
          ? json['quota_date'].toString().trim()
          : '',
      resetAt: resetRaw != null && resetRaw.isNotEmpty
          ? DateTime.tryParse(resetRaw)?.toUtc()
          : null,
      allowed: json['allowed'] != false,
    );
  }
}

abstract class AiDailyQuotaRepository {
  Future<AiDailyQuotaStatus> fetchDailyQuotaStatus();
}

class SupabaseAiDailyQuotaRepository implements AiDailyQuotaRepository {
  SupabaseAiDailyQuotaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<AiDailyQuotaStatus> fetchDailyQuotaStatus() async {
    final res = await _client.functions.invoke(
      'ai-hub',
      body: const <String, dynamic>{'action': 'quota.daily_status'},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return AiDailyQuotaStatus.fromJson(data);
    }
    if (data is Map) {
      return AiDailyQuotaStatus.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('日次 AI クォータ情報の取得に失敗しました');
  }
}
