import 'package:flutter/material.dart';

import '../models/asset_external_points.dart';

/// 外部ポイント（京王ポイント・Vポイント等）の記録・最新残高サマリカード。
///
/// 純資産・手元現金・月次支出には一切合算せず、ポイント残高と利用・付与の
/// 控えのみを独立して可視化する自己完結ウィジェット。
class AssetExternalPointsCard extends StatelessWidget {
  const AssetExternalPointsCard({
    super.key,
    required this.records,
    this.statusMessage,
    this.onAddRecord,
    this.onDeleteRecord,
    this.now,
  });

  final List<AssetExternalPointRecord> records;
  final String? statusMessage;
  final VoidCallback? onAddRecord;
  final ValueChanged<AssetExternalPointRecord>? onDeleteRecord;
  final DateTime? now;

  static const Color _accent = Color(0xFF4F46E5);
  static const Color _positive = Color(0xFF15803D);
  static const Color _warning = Color(0xFFD97706);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final trimmedStatus = statusMessage?.trim();
    final summaries = summarizeExternalPointPrograms(records, now: now);
    final sortedRecords = sortExternalPointRecords(records);
    final deleteCallback = onDeleteRecord;

    return Card(
      key: const Key('asset_external_points_card'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars_outlined, color: _accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '外部ポイント記録（京王・Vポイント等）',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                if (onAddRecord != null)
                  TextButton.icon(
                    key: const Key('asset_external_points_add'),
                    onPressed: onAddRecord,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('ポイントを記録'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('asset_external_points_notice'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.info_outline, size: 15, color: _accent),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '純資産・手元現金・月次支出には合算しません。会員番号・取引番号・POS番号は入力しないでください。',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trimmedStatus != null && trimmedStatus.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trimmedStatus,
                style: const TextStyle(
                  fontSize: 12,
                  color: _muted,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (records.isEmpty)
              const Padding(
                key: Key('asset_external_points_empty'),
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '京王ポイントやVポイントなどの残高・付与・利用の控えを記録できます。',
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              )
            else ...[
              const Text(
                'プログラム別最新残高',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final summary in summaries)
                _buildProgramSummaryTile(summary),
              const SizedBox(height: 6),
              const Text(
                '記録履歴',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final record in sortedRecords)
                _buildHistoryRow(record, onDelete: deleteCallback),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgramSummaryTile(AssetExternalPointProgramSummary summary) {
    final latest = summary.latestRecord;
    final isUrgent =
        summary.expiryStatus == AssetExternalPointExpiryStatus.expiringSoon ||
            summary.expiryStatus == AssetExternalPointExpiryStatus.expired;
    final expiryBadge = _buildExpiryBadge(summary);

    return Semantics(
      container: true,
      liveRegion: isUrgent,
      child: MergeSemantics(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isUrgent ? _warning : _accent).withValues(alpha: 0.05),
            border: Border.all(
              color: isUrgent ? _warning.withValues(alpha: 0.4) : _border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.programName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${formatExternalPointsCount(latest.balanceAfter)} P',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '観測: ${formatExternalPointDateTime(latest.observedAt)}・記録 ${summary.recordCount}件',
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  height: 1.4,
                ),
              ),
              if (expiryBadge != null) ...[
                const SizedBox(height: 6),
                expiryBadge,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildExpiryBadge(AssetExternalPointProgramSummary summary) {
    final latest = summary.latestRecord;
    final expiringPoints = latest.expiringPoints;
    final expiresOn = latest.expiresOn;

    if (summary.expiryStatus == AssetExternalPointExpiryStatus.none) {
      if (expiresOn == null) {
        return null;
      }
      return _buildExpiryChip(
        color: _muted,
        icon: Icons.schedule,
        label: '期限 ${formatExternalPointDate(expiresOn)}',
      );
    }

    if (expiringPoints == null || expiresOn == null) {
      return null;
    }

    final pointsText = formatExternalPointsCount(expiringPoints);
    final dateText = formatExternalPointDate(expiresOn);

    switch (summary.expiryStatus) {
      case AssetExternalPointExpiryStatus.expired:
        return _buildExpiryChip(
          color: _danger,
          icon: Icons.error_outline,
          label: '失効期限切れ注意: $pointsText P (期限 $dateText)',
        );
      case AssetExternalPointExpiryStatus.expiringSoon:
        return _buildExpiryChip(
          color: _warning,
          icon: Icons.warning_amber_rounded,
          label: '失効間近注意: $pointsText P (期限 $dateText)',
        );
      case AssetExternalPointExpiryStatus.active:
        return _buildExpiryChip(
          color: _accent,
          icon: Icons.schedule,
          label: '期限付き $pointsText P (期限 $dateText)',
        );
      case AssetExternalPointExpiryStatus.none:
        return null;
    }
  }

  Widget _buildExpiryChip({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(
    AssetExternalPointRecord record, {
    required ValueChanged<AssetExternalPointRecord>? onDelete,
  }) {
    final balanceBefore = record.balanceBefore;
    final expiringPoints = record.expiringPoints;
    final expiresOn = record.expiresOn;
    final targetYen = record.pointTargetAmountYen;
    final merchant = record.merchant.trim();
    final memo = record.memo.trim();
    final deltaColor = _deltaColor(record.deltaPoints);
    final deltaLabel = _formatDeltaPoints(record.deltaPoints);

    return MergeSemantics(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        record.programName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatExternalPointDateTime(record.observedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: deltaColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          deltaLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: deltaColor,
                          ),
                        ),
                      ),
                      Text(
                        balanceBefore != null
                            ? '${formatExternalPointsCount(balanceBefore)} P → ${formatExternalPointsCount(record.balanceAfter)} P'
                            : '残高 ${formatExternalPointsCount(record.balanceAfter)} P',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (merchant.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '加盟店: $merchant',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                  if (targetYen != null && targetYen > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ポイント対象額: ${formatExternalPointsCount(targetYen)}円（参考・支出計上外）',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (expiringPoints != null &&
                      expiringPoints > 0 &&
                      expiresOn != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '期限付き: ${formatExternalPointsCount(expiringPoints)} P（期限 ${formatExternalPointDate(expiresOn)}）',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (memo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'メモ: $memo',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                key: Key('asset_external_points_delete_${record.id}'),
                onPressed: () => onDelete(record),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: _muted,
                tooltip: '記録を削除',
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDeltaPoints(int deltaPoints) {
    if (deltaPoints > 0) {
      return '+${formatExternalPointsCount(deltaPoints)} P';
    }
    if (deltaPoints < 0) {
      return '-${formatExternalPointsCount(deltaPoints.abs())} P';
    }
    return '0 P (確認)';
  }

  Color _deltaColor(int deltaPoints) {
    if (deltaPoints > 0) {
      return _positive;
    }
    if (deltaPoints < 0) {
      return _danger;
    }
    return _muted;
  }
}

/// 外部ポイント記録の追加ダイアログを表示し、保存された記録を返す。
///
/// キャンセルされた場合は `null` を返す。
Future<AssetExternalPointRecord?> showAssetExternalPointEditorDialog(
  BuildContext context, {
  String initialProgramName = AssetExternalPointPresets.keio,
  DateTime? initialObservedAt,
}) {
  return showDialog<AssetExternalPointRecord>(
    context: context,
    builder: (dialogContext) {
      return _AssetExternalPointEditorDialog(
        initialProgramName: initialProgramName,
        initialObservedAt: initialObservedAt,
      );
    },
  );
}

class _AssetExternalPointEditorDialog extends StatefulWidget {
  const _AssetExternalPointEditorDialog({
    required this.initialProgramName,
    required this.initialObservedAt,
  });

  final String initialProgramName;
  final DateTime? initialObservedAt;

  @override
  State<_AssetExternalPointEditorDialog> createState() =>
      _AssetExternalPointEditorDialogState();
}

class _AssetExternalPointEditorDialogState
    extends State<_AssetExternalPointEditorDialog> {
  static const Color _accent = Color(0xFF4F46E5);
  static const Color _muted = Color(0xFF6B7280);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _programController;
  late final TextEditingController _balanceAfterController;
  late final TextEditingController _deltaController;
  late final TextEditingController _balanceBeforeController;
  late final TextEditingController _merchantController;
  late final TextEditingController _expiringPointsController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _memoController;

  late DateTime _observedAt;
  DateTime? _expiresOn;

  @override
  void initState() {
    super.initState();
    _programController = TextEditingController(text: widget.initialProgramName);
    _balanceAfterController = TextEditingController();
    _deltaController = TextEditingController();
    _balanceBeforeController = TextEditingController();
    _merchantController = TextEditingController();
    _expiringPointsController = TextEditingController();
    _targetAmountController = TextEditingController();
    _memoController = TextEditingController();
    _observedAt = widget.initialObservedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _programController.dispose();
    _balanceAfterController.dispose();
    _deltaController.dispose();
    _balanceBeforeController.dispose();
    _merchantController.dispose();
    _expiringPointsController.dispose();
    _targetAmountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  DateTime _clampPickerDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final minDate = DateTime(2000, 1, 1);
    final maxDate = DateTime(2100, 12, 31);
    if (normalized.isBefore(minDate)) {
      return minDate;
    }
    if (normalized.isAfter(maxDate)) {
      return maxDate;
    }
    return normalized;
  }

  Future<void> _pickObservedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampPickerDate(_observedAt),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _observedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _observedAt.hour,
        _observedAt.minute,
      );
    });
  }

  Future<void> _pickObservedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_observedAt),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _observedAt = DateTime(
        _observedAt.year,
        _observedAt.month,
        _observedAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickExpiresOn() async {
    final currentExpiresOn = _expiresOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampPickerDate(currentExpiresOn ?? _observedAt),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _expiresOn = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    final balanceAfter = parseFlexiblePointInt(_balanceAfterController.text);
    if (balanceAfter == null || balanceAfter < 0) {
      return;
    }
    final deltaText = _deltaController.text.trim();
    final deltaPoints = deltaText.isEmpty
        ? 0
        : (parseFlexiblePointInt(deltaText, allowNegative: true) ?? 0);
    final balanceBeforeText = _balanceBeforeController.text.trim();
    final balanceBefore = balanceBeforeText.isEmpty
        ? null
        : parseFlexiblePointInt(balanceBeforeText);
    final expiringText = _expiringPointsController.text.trim();
    final expiringPoints =
        expiringText.isEmpty ? null : parseFlexiblePointInt(expiringText);
    final targetText = _targetAmountController.text.trim();
    final targetAmountYen =
        targetText.isEmpty ? null : parseFlexiblePointInt(targetText);
    final currentExpiresOn = _expiresOn;
    final normalizedExpiresOn = currentExpiresOn == null
        ? null
        : DateTime(
            currentExpiresOn.year,
            currentExpiresOn.month,
            currentExpiresOn.day,
          );

    final record = AssetExternalPointRecord(
      id: 'ep_${DateTime.now().microsecondsSinceEpoch}',
      programName: _programController.text.trim(),
      observedAt: _observedAt,
      balanceAfter: balanceAfter,
      deltaPoints: deltaPoints,
      balanceBefore: balanceBefore,
      expiringPoints: expiringPoints,
      expiresOn: normalizedExpiresOn,
      merchant: _merchantController.text.trim(),
      pointTargetAmountYen: targetAmountYen,
      memo: _memoController.text.trim(),
    );
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final currentExpiresOn = _expiresOn;
    final selectedProgram = _programController.text.trim();

    return AlertDialog(
      title: const Text('外部ポイントを記録'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '会員番号・取引番号・端末番号は入力しないでください',
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final preset in AssetExternalPointPresets.all)
                      ChoiceChip(
                        key: Key('asset_external_point_preset_$preset'),
                        selected: selectedProgram == preset,
                        onSelected: (_) {
                          setState(() {
                            _programController.text = preset;
                          });
                        },
                        selectedColor: _accent,
                        labelStyle: TextStyle(
                          color: selectedProgram == preset
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        label: Text(preset),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_program_field'),
                  controller: _programController,
                  decoration: const InputDecoration(
                    labelText: 'プログラム名',
                    hintText: '例: 京王ポイント / Vポイント',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'プログラム名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_balance_after_field'),
                  controller: _balanceAfterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '残高（ポイント）',
                    hintText: '例: 94（全角数字可）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '残高を入力してください';
                    }
                    final parsed = parseFlexiblePointInt(value);
                    if (parsed == null || parsed < 0) {
                      return '0以上の整数で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_delta_field'),
                  controller: _deltaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '増減（+付与 / -利用 / 0確認のみ）',
                    hintText: '例: +28 / -50（空欄は0）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    if (parseFlexiblePointInt(value, allowNegative: true) ==
                        null) {
                      return '整数で入力してください（例: +28, -50）';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_balance_before_field'),
                  controller: _balanceBeforeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '付与前残高',
                    hintText: '任意（例: 66）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = parseFlexiblePointInt(value);
                    if (parsed == null || parsed < 0) {
                      return '0以上の整数で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '観測日時',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(formatExternalPointDateTime(_observedAt)),
                      ),
                      IconButton(
                        key: const Key('asset_external_point_pick_date'),
                        onPressed: _pickObservedDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        tooltip: '観測日を変更',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        key: const Key('asset_external_point_pick_time'),
                        onPressed: _pickObservedTime,
                        icon: const Icon(
                          Icons.access_time_outlined,
                          size: 18,
                        ),
                        tooltip: '観測時刻を変更',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_merchant_field'),
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: '加盟店',
                    hintText: '例: 紀伊國屋書店 府中店',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_expiring_points_field'),
                  controller: _expiringPointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '失効予定ポイント',
                    hintText: '任意（例: 30）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = parseFlexiblePointInt(value);
                    if (parsed == null || parsed <= 0) {
                      return '1以上の整数で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '失効日',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: const Key(
                            'asset_external_point_expires_on_picker',
                          ),
                          onTap: _pickExpiresOn,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentExpiresOn != null
                                      ? formatExternalPointDate(
                                          currentExpiresOn,
                                        )
                                      : '未設定',
                                ),
                              ),
                              const Icon(Icons.event_outlined, size: 18),
                            ],
                          ),
                        ),
                      ),
                      if (currentExpiresOn != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key(
                            'asset_external_point_expires_on_clear',
                          ),
                          onPressed: () {
                            setState(() {
                              _expiresOn = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: '失効日をクリア',
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_target_amount_field'),
                  controller: _targetAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ポイント対象金額（円・参考値）',
                    hintText: '例: 970',
                    helperText: '支出・残高には加算されません',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final parsed = parseFlexiblePointInt(value);
                    if (parsed == null || parsed <= 0) {
                      return '1以上の整数で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('asset_external_point_memo_field'),
                  controller: _memoController,
                  minLines: 1,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    hintText: '任意',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('asset_external_point_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('asset_external_point_save'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
