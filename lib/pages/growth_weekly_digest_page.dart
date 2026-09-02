import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/growth_mission_service.dart';

typedef GrowthWeeklyDigestLoader = Future<Map<String, dynamic>> Function();

/// Owner-only weekly growth digest.
///
/// The Edge Function returns `{success, digest}`. This page deliberately
/// unwraps that envelope into the same [WeeklyDigestSnapshot] used by
/// [GrowthMissionService], so the standalone and embedded views cannot drift.
class GrowthWeeklyDigestPage extends StatefulWidget {
  const GrowthWeeklyDigestPage({super.key, this.loader});

  final GrowthWeeklyDigestLoader? loader;

  @override
  State<GrowthWeeklyDigestPage> createState() => _GrowthWeeklyDigestPageState();
}

class _GrowthWeeklyDigestPageState extends State<GrowthWeeklyDigestPage> {
  bool _isLoading = false;
  String? _errorMessage;
  WeeklyDigestSnapshot? _digest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>> _invokeDigest() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const _DigestLoadException('login_required');
    }
    final response = await supabase.functions.invoke(
      'growth-weekly-digest',
      headers: <String, String>{
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: const <String, dynamic>{},
    );
    final data = response.data;
    if (data is! Map) {
      throw const _DigestLoadException('invalid_response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final envelope = await (widget.loader ?? _invokeDigest)();
      if (envelope['success'] != true) {
        throw _DigestLoadException(
          envelope['error']?.toString() ?? 'digest_failed',
        );
      }
      final rawDigest = envelope['digest'];
      if (rawDigest is! Map) {
        throw const _DigestLoadException('invalid_response');
      }
      final digest = WeeklyDigestSnapshot.fromJson(
        Map<String, dynamic>.from(rawDigest),
      );
      if (!mounted) return;
      setState(() => _digest = digest);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _localizedError(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizedError(Object error) {
    final String code;
    if (error is _DigestLoadException) {
      code = error.code;
    } else if (error is FunctionException) {
      final details = error.details;
      code = details is Map && details['error'] != null
          ? details['error'].toString()
          : switch (error.status) {
              401 => 'login_required',
              403 => 'admin_required',
              429 => 'rate_limited',
              _ => 'digest_failed',
            };
    } else {
      code = error.toString();
    }
    return switch (code) {
      'login_required' => '週次ダイジェストにはログインが必要です',
      'admin_required' => '週次ダイジェストの閲覧には管理者権限が必要です',
      'rate_limited' => '更新回数が上限に達しました。1分後に再試行してください',
      _ => '週次ダイジェスト取得に失敗しました',
    };
  }

  Widget _buildChannelCard(WeeklyDigestChannelMetrics channel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channel.label.isNotEmpty ? channel.label : channel.id,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _buildMetric('タッチ', channel.touches, const Color(0xFF3D5AFE)),
                _buildMetric(
                  '登録送信',
                  channel.signupSubmits,
                  const Color(0xFF4CAF50),
                ),
                _buildMetric('CVR', '${channel.cvr}%', const Color(0xFFFF6B35)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, Object value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, height: 1.5)),
      ],
    );
  }

  Widget _buildSummary(WeeklyDigestSnapshot digest) {
    return Wrap(
      key: const Key('growth-weekly-digest-summary'),
      spacing: 12,
      runSpacing: 8,
      children: [
        Chip(label: Text('登録送信 ${digest.signupSubmitTotal}')),
        Chip(label: Text('紹介成立 ${digest.referralsCompleted}')),
        Chip(label: Text('Import CTA ${digest.importCtaClicks}')),
        Chip(label: Text('公開メモ CTA ${digest.publicMemoCtaClicks}')),
      ],
    );
  }

  Widget _buildDecisionCard(WeeklyDigestSnapshot digest) {
    final decision = digest.decision;
    final previous = digest.previousDecisionOutcome;
    final ownerLabel = decision.owner == 'service_role' ? '自動運用' : '管理者';
    return Card(
      key: const Key('growth-weekly-digest-decision'),
      color: const Color(0xFFE0F2F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今週の意思決定',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text('Owner: $ownerLabel'),
            Text('優先チャネル: ${decision.priorityChannelLabel}'),
            Text(
              '閾値: ${decision.minimumTouches}タッチ以上 / '
              'CVR ${decision.targetCvr}%以上',
            ),
            Text('次のAction: ${decision.nextAction}'),
            Text('期限: ${decision.dueDate}'),
            const Divider(height: 24),
            Text(
              '前週ActionのOutcome: ${_outcomeLabel(previous.status)} '
              '(${previous.priorityChannelLabel} / '
              '${previous.actualTouches}タッチ / CVR ${previous.actualCvr}%)',
            ),
          ],
        ),
      ),
    );
  }

  String _outcomeLabel(String status) => switch (status) {
        'met' => '達成',
        'missed' => '未達',
        'insufficient_sample' => 'サンプル不足',
        _ => '計測待ち',
      };

  @override
  Widget build(BuildContext context) {
    final digest = _digest;
    return Scaffold(
      appBar: AppBar(
        title: const Text('週次ダイジェスト'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '更新',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: Color(0xFFE53935), height: 1.5),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (digest != null) ...[
                        Text(
                          '${digest.currentWeekStart} ～ '
                          '${digest.currentWeekEnd}',
                          key: const Key('growth-weekly-digest-week-range'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSummary(digest),
                        const SizedBox(height: 16),
                        _buildDecisionCard(digest),
                        const SizedBox(height: 16),
                      ],
                      if (digest == null || digest.channels.isEmpty)
                        const Text(
                          'チャネルデータがありません',
                          style:
                              TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                        )
                      else ...[
                        const Text(
                          'チャネル別指標',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...digest.channels.map(_buildChannelCard),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _DigestLoadException implements Exception {
  const _DigestLoadException(this.code);

  final String code;
}
