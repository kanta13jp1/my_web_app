import 'package:flutter/material.dart';

import '../models/self_mental_health_check.dart';
import '../services/self_mental_health_risk_service.dart';

class SelfMentalHealthRiskPanel extends StatefulWidget {
  final SelfMentalHealthRiskService? service;
  final DateTime? debugNow;

  const SelfMentalHealthRiskPanel({
    super.key,
    this.service,
    this.debugNow,
  });

  @override
  State<SelfMentalHealthRiskPanel> createState() =>
      _SelfMentalHealthRiskPanelState();
}

class _SelfMentalHealthRiskPanelState extends State<SelfMentalHealthRiskPanel> {
  late final SelfMentalHealthRiskService _service;
  final TextEditingController _noteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int _moodScore = 3;
  int _fatigueScore = 3;
  List<SelfMentalHealthCheck> _entries = const <SelfMentalHealthCheck>[];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? const SelfMentalHealthRiskService();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await _service.loadEntries();
    if (!mounted) return;
    final todayKey = SelfMentalHealthCheck.formatDateKey(
      widget.debugNow ?? DateTime.now(),
    );
    SelfMentalHealthCheck? todayEntry;
    for (final entry in loaded) {
      if (entry.dateKey == todayKey) {
        todayEntry = entry;
        break;
      }
    }
    setState(() {
      _entries = loaded;
      if (todayEntry != null) {
        _moodScore = todayEntry.moodScore;
        _fatigueScore = todayEntry.fatigueScore;
        _noteCtrl.text = todayEntry.note;
      }
      _loading = false;
    });
  }

  Future<void> _saveCheck() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.recordDailyCheck(
        moodScore: _moodScore,
        fatigueScore: _fatigueScore,
        note: _noteCtrl.text,
        now: widget.debugNow,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('今日のコンディションを記録しました'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final report = SelfMentalHealthRiskService.evaluateRisk(
      _entries,
      now: widget.debugNow,
    );

    return Card(
      key: const Key('self_mental_health_risk_card'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: accent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.favorite_outline, color: accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'コンディション & バーンアウト予防チェック',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '直近14日: ${report.entryCount}件',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '1日1回、絵文字ワンタップで気分と身体の疲労度を記録し、過度な負荷の蓄積を早期検知します。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LinearProgressIndicator()
            else ...<Widget>[
              _buildAlertBanner(context, report),
              const SizedBox(height: 14),
              const Text(
                '今日の気分 (1: つらい 〜 5: 良好)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (var score = 1; score <= 5; score++)
                    _buildScoreChip(
                      chipKey: Key('mental_mood_chip_$score'),
                      emoji: SelfMentalHealthCheck.moodEmojis[score - 1],
                      label:
                          '$score ${SelfMentalHealthCheck.moodLabels[score - 1]}',
                      selected: _moodScore == score,
                      semanticsLabel:
                          '気分レベル$score ${SelfMentalHealthCheck.moodLabels[score - 1]}',
                      onTap: () => setState(() => _moodScore = score),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '身体の疲労度 (1: 元気 〜 5: 限界)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (var score = 1; score <= 5; score++)
                    _buildScoreChip(
                      chipKey: Key('mental_fatigue_chip_$score'),
                      emoji: SelfMentalHealthCheck.fatigueEmojis[score - 1],
                      label:
                          '$score ${SelfMentalHealthCheck.fatigueLabels[score - 1]}',
                      selected: _fatigueScore == score,
                      semanticsLabel:
                          '疲労レベル$score ${SelfMentalHealthCheck.fatigueLabels[score - 1]}',
                      onTap: () => setState(() => _fatigueScore = score),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('mental_check_note_input'),
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'ひとことメモ (任意)',
                  hintText: '睡眠や業務負荷の気づきがあれば記録',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('mental_check_save_button'),
                  onPressed: _saving ? null : _saveCheck,
                  icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
                  label: const Text('今日のコンディションを記録'),
                ),
              ),
              if (_entries.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                const Text(
                  '最近の記録 (直近7日分)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final entry in _entries.take(7))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 96,
                          child: Text(
                            entry.dateKey,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '気分 ${entry.moodEmoji} ${entry.moodScore}/5 · '
                            '疲労 ${entry.fatigueEmoji} ${entry.fatigueScore}/5'
                            '${entry.note.isNotEmpty ? ' · ${entry.note}' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChip({
    required Key chipKey,
    required String emoji,
    required String label,
    required bool selected,
    required String semanticsLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: ChoiceChip(
        key: chipKey,
        selected: selected,
        label: Text('$emoji $label'),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    SelfBurnoutRiskReport report,
  ) {
    final theme = Theme.of(context);
    final Color borderColor;
    final Color bgColor;
    final IconData icon;
    final String badgeText;

    switch (report.level) {
      case SelfBurnoutRiskLevel.high:
        borderColor = const Color(0xFFB91C1C);
        bgColor = const Color(0xFFFEF2F2);
        icon = Icons.warning_amber_rounded;
        badgeText = '警戒';
        break;
      case SelfBurnoutRiskLevel.caution:
        borderColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFFFBEB);
        icon = Icons.info_outline;
        badgeText = '注意';
        break;
      case SelfBurnoutRiskLevel.low:
        borderColor = const Color(0xFF047857);
        bgColor = const Color(0xFFECFDF5);
        icon = Icons.verified_outlined;
        badgeText = '良好';
        break;
    }

    return Container(
      key: report.hasAlert
          ? const Key('mental_burnout_alert_banner')
          : const Key('mental_burnout_status_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: borderColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '平均気分 ${report.averageMood.toStringAsFixed(1)}/5 · '
            '平均疲労 ${report.averageFatigue.toStringAsFixed(1)}/5 · '
            '連続高負荷 ${report.consecutiveHighStrainDays}日',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          for (final suggestion in report.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '・$suggestion',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            report.neutralNotice,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
