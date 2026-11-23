import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';
import '../services/asset_payment_reminder_service.dart';
import 'debt_legal_disclaimer_banner.dart';

/// 返済期日リマインダーと遅延損害金の日割り増加・対応ガイダンスを表示するバナー (#2749)。
class AssetPaymentReminderBanner extends StatelessWidget {
  const AssetPaymentReminderBanner({
    super.key,
    required this.workbook,
    required this.schedule,
    required this.settings,
    required this.deliveredKeys,
    required this.onSettingsChanged,
    required this.onTriggerNotifications,
    required this.onOpenCreditorContact,
    required this.onOpenConsultationGuide,
  });

  final AssetLiabilityWorkbook workbook;
  final AssetPaymentReminderSchedule schedule;
  final AssetPaymentReminderSettings settings;
  final Set<String> deliveredKeys;
  final void Function(AssetPaymentReminderSettings next) onSettingsChanged;
  final Future<void> Function() onTriggerNotifications;
  final VoidCallback onOpenCreditorContact;
  final VoidCallback onOpenConsultationGuide;

  String _formatYen(double amount) {
    final fmt = NumberFormat('#,##0', 'ja_JP');
    return '¥${fmt.format(amount.round())}';
  }

  @override
  Widget build(BuildContext context) {
    if (!schedule.hasAny && settings.enabled) {
      return const SizedBox.shrink();
    }
    final upcomingAndToday = <AssetPaymentReminderItem>[
      ...schedule.dueTodayItems,
      ...schedule.upcomingItems,
    ];
    final hasOverdue = schedule.overdueItems.isNotEmpty;
    final undeliveredCount = schedule.actionableItems
        .where((item) => !deliveredKeys.contains(item.deliveryKey))
        .length;

    return Container(
      key: const Key('asset_payment_reminder_banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasOverdue ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasOverdue ? const Color(0xFFE11D48) : const Color(0xFF93C5FD),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    hasOverdue
                        ? Icons.notification_important_outlined
                        : Icons.notifications_active_outlined,
                    color: hasOverdue
                        ? const Color(0xFFBE123C)
                        : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasOverdue
                          ? '返済期日リマインダー・遅延損害金警告 (${schedule.actionableItems.length}件)'
                          : '返済期日リマインダー (${upcomingAndToday.length}件)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasOverdue
                            ? const Color(0xFF9F1239)
                            : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (schedule.hasAny)
                    OutlinedButton.icon(
                      key: const Key('payment_reminder_send_now_button'),
                      onPressed: onTriggerNotifications,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: Text(
                        undeliveredCount > 0
                            ? '通知・記録 ($undeliveredCount件)'
                            : '送信済み確認',
                      ),
                    ),
                  if (schedule.emailDigestBody.isNotEmpty)
                    OutlinedButton.icon(
                      key: const Key('payment_reminder_copy_email_button'),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${schedule.emailDigestSubject}\n\n${schedule.emailDigestBody}',
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('リマインダーメール用サマリをコピーしました。'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('メール文面コピー'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('payment_reminder_settings_button'),
                    onPressed: () => _openSettings(context),
                    icon: const Icon(Icons.tune_outlined, size: 16),
                    label: const Text('設定'),
                  ),
                ],
              ),
            ],
          ),
          if (!settings.enabled) ...[
            const SizedBox(height: 8),
            const Text(
              '返済期日リマインダーは現在オフです。「設定」から有効化できます。',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
          if (upcomingAndToday.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in upcomingAndToday)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.stage == PaymentReminderStage.dueToday
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.stageLabel,
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
                        '${item.accountName}: ${DateFormat('M/d').format(item.dueDate)} 予定額 ${_formatYen(item.scheduledPaymentAmount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (hasOverdue) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('payment_reminder_overdue_guidance_box'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDA4AF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '1日あたりの遅延損害金目安: +${_formatYen(schedule.totalDailyLateFee)}/日 '
                    '・累計概算 +${_formatYen(schedule.totalEstimatedLateFee)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in schedule.overdueItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '・${item.accountName} (${item.overdueDays}日超過 / 年利'
                        '${(item.effectiveLateFeeAnnualRate * 100).toStringAsFixed(1)}%): '
                        '加算額 +${_formatYen(item.estimatedLateFeeAmount)} '
                        '(残高見込 ${_formatYen(item.projectedBalanceWithLateFee)})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF881337),
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    '遅延発生時の優先ガイダンス: 放置すると日割りで遅延損害金が増加します。'
                    '債権者窓口への早期連絡（支払日変更・分割相談）または公的・専門相談窓口の確認をご検討ください。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        key: const Key(
                          'payment_reminder_open_creditor_contact_button',
                        ),
                        onPressed: onOpenCreditorContact,
                        icon:
                            const Icon(Icons.phone_in_talk_outlined, size: 16),
                        label: const Text('債権者へ早期連絡・記録を開く'),
                      ),
                      OutlinedButton.icon(
                        key: const Key(
                          'payment_reminder_open_consultation_guide_button',
                        ),
                        onPressed: onOpenConsultationGuide,
                        icon:
                            const Icon(Icons.support_agent_outlined, size: 16),
                        label: const Text('専門機関の相談窓口を確認'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const DebtLegalDisclaimerBanner(
                    contextType:
                        DebtLegalNoticeContext.overpaymentAndSimulation,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            '※ OSのプッシュ通知・自動メール送信は端末権限やメール連携状況に依存するため、確実な管理のため画面上でも確認できます。',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final debtRows = workbook.debtMasterRows
        .where((row) => row.isDirectCashflowTarget && !row.paid)
        .toList(growable: false);
    final updated = await showDialog<AssetPaymentReminderSettings>(
      context: context,
      builder: (_) => AssetPaymentReminderSettingsDialog(
        initialSettings: settings,
        debtRows: debtRows,
      ),
    );
    if (updated != null) {
      onSettingsChanged(updated);
    }
  }
}

/// 返済期日リマインダーの通知タイミング・遅延利率設定ダイアログ (#2749)。
class AssetPaymentReminderSettingsDialog extends StatefulWidget {
  const AssetPaymentReminderSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.debtRows,
  });

  final AssetPaymentReminderSettings initialSettings;
  final List<AssetLiabilityDebtRow> debtRows;

  @override
  State<AssetPaymentReminderSettingsDialog> createState() =>
      _AssetPaymentReminderSettingsDialogState();
}

class _AssetPaymentReminderSettingsDialogState
    extends State<AssetPaymentReminderSettingsDialog> {
  late bool _enabled;
  late bool _pushEnabled;
  late bool _emailDigestEnabled;
  late Set<int> _daysBefore;
  late Map<String, TextEditingController> _rateControllers;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialSettings.enabled;
    _pushEnabled = widget.initialSettings.pushEnabled;
    _emailDigestEnabled = widget.initialSettings.emailDigestEnabled;
    _daysBefore = Set<int>.from(widget.initialSettings.daysBefore);
    _rateControllers = <String, TextEditingController>{};
    for (final row in widget.debtRows) {
      final custom = widget.initialSettings.customRateFor(row.id);
      _rateControllers[row.id] = TextEditingController(
        text: custom != null ? (custom * 100).toStringAsFixed(1) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final rates = <String, double>{
      ...widget.initialSettings.customLateFeeAnnualRates,
    };
    for (final entry in _rateControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) {
        rates.remove(entry.key);
        continue;
      }
      final pct = double.tryParse(text);
      if (pct != null && pct >= 0) {
        rates[entry.key] = min(pct / 100.0, 0.20);
      }
    }
    final sortedDays = _daysBefore.toList()..sort((a, b) => b.compareTo(a));
    Navigator.of(context).pop(
      AssetPaymentReminderSettings(
        enabled: _enabled,
        daysBefore: sortedDays.isEmpty ? const <int>[0] : sortedDays,
        pushEnabled: _pushEnabled,
        emailDigestEnabled: _emailDigestEnabled,
        customLateFeeAnnualRates: Map<String, double>.unmodifiable(rates),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('payment_reminder_settings_dialog'),
      title: const Text('返済期日リマインダー・遅延損害金率設定'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SwitchListTile(
                key: const Key('payment_reminder_enabled_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('返済期日リマインダーを有効にする'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('端末プッシュ通知連携を有効化'),
                value: _pushEnabled,
                onChanged: (v) => setState(() => _pushEnabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('メール通知用ダイジェスト生成'),
                value: _emailDigestEnabled,
                onChanged: (v) => setState(() => _emailDigestEnabled = v),
              ),
              const SizedBox(height: 8),
              const Text(
                '事前リマインド日数',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  for (final day in const <int>[5, 3, 1, 0])
                    FilterChip(
                      label: Text(day == 0 ? '当日' : '$day日前'),
                      selected: _daysBefore.contains(day),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _daysBefore.add(day);
                          } else {
                            _daysBefore.remove(day);
                          }
                        });
                      },
                    ),
                ],
              ),
              if (widget.debtRows.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  '個別遅延損害金年利 (%) 上限20.0%・空欄時は既定率',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final row in widget.debtRows.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      key: Key('payment_reminder_rate_field_${row.id}'),
                      controller: _rateControllers[row.id],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${row.name} 遅延損害金年利 (%)',
                        hintText: '例: 20.0（空欄時は登録年利または14.6%）',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('payment_reminder_settings_save_button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
