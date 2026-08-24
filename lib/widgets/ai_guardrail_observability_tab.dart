import 'package:flutter/material.dart';

import '../services/ai_guardrail_observability_service.dart';

class AiGuardrailObservabilityTab extends StatefulWidget {
  final AiGuardrailObservabilityService service;

  const AiGuardrailObservabilityTab({
    super.key,
    this.service = const AiGuardrailObservabilityService(),
  });

  @override
  State<AiGuardrailObservabilityTab> createState() =>
      _AiGuardrailObservabilityTabState();
}

class _AiGuardrailObservabilityTabState
    extends State<AiGuardrailObservabilityTab> {
  static const _accent = Color(0xFF38BDF8);

  AiGuardrailOverview? _overview;
  AiGuardrailObservabilityException? _error;
  bool _loading = true;
  int _windowDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final overview = await widget.service.fetchOverview(
        windowDays: _windowDays,
      );
      if (mounted) setState(() => _overview = overview);
    } on AiGuardrailObservabilityException catch (error) {
      if (mounted) {
        setState(() {
          _overview = null;
          _error = error;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _overview = null;
          _error = const AiGuardrailObservabilityException(
            'ガードレール監査ログを取得できませんでした。',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }
    final error = _error;
    if (error != null) return _errorView(error);
    final overview = _overview;
    if (overview == null) {
      return _errorView(
        const AiGuardrailObservabilityException('ガードレール監査ログを取得できませんでした。'),
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
          final contentWidth = (constraints.maxWidth - horizontalPadding * 2)
              .clamp(0.0, 1120.0)
              .toDouble();
          return ListView(
            key: const Key('guardrail-overview-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            children: [
              Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _privacyNotice(overview),
                      const SizedBox(height: 16),
                      _summaryCards(overview.summary, contentWidth),
                      const SizedBox(height: 24),
                      _categories(overview.summary),
                      const SizedBox(height: 24),
                      _events(overview),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Writer Content Guardrails',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '入力ブロックと出力マスキングの判定履歴を確認します。',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7日')),
            ButtonSegment(value: 30, label: Text('30日')),
            ButtonSegment(value: 90, label: Text('90日')),
          ],
          selected: {_windowDays},
          onSelectionChanged: (selection) {
            final selected = selection.first;
            if (selected == _windowDays) return;
            setState(() => _windowDays = selected);
            _load();
          },
        ),
        IconButton(
          tooltip: '再読み込み',
          onPressed: _load,
          icon: const Icon(Icons.refresh, color: _accent),
        ),
      ],
    );
  }

  Widget _privacyNotice(AiGuardrailOverview overview) {
    final privacySafe = !overview.rawContentStored && !overview.userIdReturned;
    return Container(
      key: const Key('guardrail-privacy-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2532),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            privacySafe ? Icons.privacy_tip_outlined : Icons.warning_amber,
            color: privacySafe ? _accent : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              privacySafe
                  ? 'プライバシー保護: 入出力の本文と利用者IDは保存・返却していません。'
                  : 'プライバシー設定を確認してください。本文または利用者IDが返却されています。',
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(AiGuardrailSummary summary, double width) {
    final columns = width >= 900 ? 4 : (width >= 520 ? 2 : 1);
    final cardWidth = (width - (columns - 1) * 12) / columns;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard(
          width: cardWidth,
          label: '判定件数',
          value: '${summary.sampledEvents}',
          detail:
              summary.sampleLimited ? '上限までのサンプル' : '${summary.windowDays}日間',
          color: const Color(0xFFCBD5E1),
        ),
        _summaryCard(
          width: cardWidth,
          label: 'ブロック',
          value: '${summary.blocked}',
          detail: '送信・表示を停止',
          color: const Color(0xFFEF4444),
        ),
        _summaryCard(
          width: cardWidth,
          label: 'マスキング',
          value: '${summary.redacted}',
          detail: '出力を安全化',
          color: const Color(0xFFF59E0B),
        ),
        _summaryCard(
          width: cardWidth,
          label: '平均判定時間',
          value: '${summary.averageLatencyMs}ms',
          detail: '許可 ${summary.allowed}件',
          color: _accent,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required double width,
    required String label,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categories(AiGuardrailSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '検知カテゴリ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        if (summary.categories.isEmpty)
          const Text(
            '該当する検知はありません。',
            style: TextStyle(color: Color(0xFF94A3B8), height: 1.6),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in summary.categories)
                Chip(
                  label: Text('${category.category}  ${category.count}'),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                  labelStyle: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _events(AiGuardrailOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近の判定',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        if (overview.recentEvents.isEmpty)
          Container(
            key: const Key('guardrail-empty'),
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '選択期間内のガードレール判定はありません。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), height: 1.6),
            ),
          )
        else
          for (final event in overview.recentEvents) ...[
            _eventCard(event),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _eventCard(AiGuardrailEvent event) {
    final color = switch (event.decision) {
      'block' => const Color(0xFFEF4444),
      'redact' => const Color(0xFFF59E0B),
      _ => const Color(0xFF22C55E),
    };
    final createdAt = event.createdAt?.toLocal();
    final timestamp = createdAt == null
        ? '時刻不明'
        : '${createdAt.year}-${_two(createdAt.month)}-${_two(createdAt.day)} '
            '${_two(createdAt.hour)}:${_two(createdAt.minute)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.decision.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${event.provider} / ${event.stage}',
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                timestamp,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.categories.isEmpty ? 'カテゴリなし' : event.categories.join(', '),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '判定 ${event.latencyMs}ms ・ ${event.contentChars}文字 ・ '
            'マスキング ${event.redactionCount}件 ・ trace ${event.shortTraceId}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(AiGuardrailObservabilityException error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error.adminRequired
                  ? Icons.admin_panel_settings
                  : Icons.error_outline,
              color: error.adminRequired ? _accent : const Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              error.message,
              key: const Key('guardrail-error-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
