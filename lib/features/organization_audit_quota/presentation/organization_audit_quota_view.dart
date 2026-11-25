import 'package:flutter/material.dart';

import '../application/organization_audit_quota_controller.dart';
import '../domain/organization_audit_quota_models.dart';

class _OrgPalette {
  const _OrgPalette({
    required this.cardBg,
    required this.subSurface,
    required this.primaryInk,
    required this.secondaryInk,
    required this.borderInk,
    required this.btnBg,
    required this.btnFg,
    required this.okBg,
    required this.okInk,
    required this.warnBg,
    required this.warnInk,
    required this.errBg,
    required this.errInk,
    required this.badgeBg,
    required this.badgeInk,
  });

  factory _OrgPalette.of(final BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _OrgPalette(
        cardBg: Color(0xFF0F172A),
        subSurface: Color(0xFF1E293B),
        primaryInk: Color(0xFFF8FAFC),
        secondaryInk: Color(0xFFCBD5E1),
        borderInk: Color(0xFF475569),
        btnBg: Color(0xFF93C5FD),
        btnFg: Color(0xFF0F172A),
        okBg: Color(0xFF052E16),
        okInk: Color(0xFFBBF7D0),
        warnBg: Color(0xFF451A03),
        warnInk: Color(0xFFFEF08A),
        errBg: Color(0xFF450A0A),
        errInk: Color(0xFFFECACA),
        badgeBg: Color(0xFF1E3A8A),
        badgeInk: Color(0xFFDBEAFE),
      );
    }
    return const _OrgPalette(
      cardBg: Color(0xFFFFFFFF),
      subSurface: Color(0xFFF8FAFC),
      primaryInk: Color(0xFF0F172A),
      secondaryInk: Color(0xFF334155),
      borderInk: Color(0xFF94A3B8),
      btnBg: Color(0xFF1E40AF),
      btnFg: Color(0xFFFFFFFF),
      okBg: Color(0xFFDCFCE7),
      okInk: Color(0xFF14532D),
      warnBg: Color(0xFFFEF3C7),
      warnInk: Color(0xFF78350F),
      errBg: Color(0xFFFEE2E2),
      errInk: Color(0xFF7F1D1D),
      badgeBg: Color(0xFFEFF6FF),
      badgeInk: Color(0xFF1E3A8A),
    );
  }

  final Color cardBg;
  final Color subSurface;
  final Color primaryInk;
  final Color secondaryInk;
  final Color borderInk;
  final Color btnBg;
  final Color btnFg;
  final Color okBg;
  final Color okInk;
  final Color warnBg;
  final Color warnInk;
  final Color errBg;
  final Color errInk;
  final Color badgeBg;
  final Color badgeInk;
}

/// 組織監査ログ・リソース利用クォータ表示専用 View (#2692).
class OrganizationAuditQuotaView extends StatelessWidget {
  const OrganizationAuditQuotaView({
    super.key,
    required this.state,
    required this.selectedResourceType,
    required this.limitController,
    required this.unitsController,
    required this.onRefresh,
    required this.onSelectFilter,
    required this.onResourceTypeChanged,
    required this.onUpdateLimit,
    required this.onConsumeQuota,
    required this.onAcknowledgeAlert,
  });

  final OrganizationAuditQuotaState state;
  final OrgQuotaResourceType selectedResourceType;
  final TextEditingController limitController;
  final TextEditingController unitsController;
  final VoidCallback onRefresh;
  final ValueChanged<OrgAuditEventType> onSelectFilter;
  final ValueChanged<OrgQuotaResourceType> onResourceTypeChanged;
  final VoidCallback onUpdateLimit;
  final VoidCallback onConsumeQuota;
  final ValueChanged<String> onAcknowledgeAlert;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _OrgPalette palette = _OrgPalette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '組織監査ログ・クォータ管理',
                softWrap: true,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: palette.primaryInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (state.periodKey.isNotEmpty)
                    _OrgStatusBadge(
                      label: '対象月: ${state.periodKey}',
                      bg: palette.badgeBg,
                      ink: palette.badgeInk,
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: IconButton(
                      key: const ValueKey<String>('org_audit_refresh_button'),
                      tooltip: '最新状態を再読み込み',
                      onPressed: state.isLoading ? null : onRefresh,
                      color: palette.primaryInk,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ログイン・権限変更・重要データ作成/削除を改ざん不可で自動記録し、80%警告通知と100%上限超過ブロック(HTTP 429)を実行します。',
            softWrap: true,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.secondaryInk,
              height: 1.5,
            ),
          ),
          if (state.isLoading || state.isSubmitting) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (state.quotaBlockedMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageBanner(
              key: const ValueKey<String>('org_quota_blocked_429_banner'),
              icon: Icons.block,
              title: '利用上限超過によりブロックされました (HTTP 429)',
              message: state.quotaBlockedMessage!,
              bg: palette.errBg,
              ink: palette.errInk,
              border: palette.errInk,
            ),
          ],
          if (state.hasWarning80) ...<Widget>[
            const SizedBox(height: 12),
            _MessageBanner(
              key: const ValueKey<String>('org_quota_warning_80_banner'),
              icon: Icons.warning_amber_rounded,
              title: '管理者アラート通知: クォータ80%到達',
              message: '組織のリソース利用量が設定上限の80%以上に達しました。',
              bg: palette.warnBg,
              ink: palette.warnInk,
              border: palette.warnInk,
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageBanner(
              key: const ValueKey<String>('org_audit_error_banner'),
              icon: Icons.error_outline,
              title: '読込または実行エラー',
              message: state.errorMessage!,
              bg: palette.errBg,
              ink: palette.errInk,
              border: palette.errInk,
            ),
          ],
          if (state.statusMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageBanner(
              key: const ValueKey<String>('org_audit_status_banner'),
              icon: Icons.check_circle_outline,
              title: '処理完了',
              message: state.statusMessage!,
              bg: palette.okBg,
              ink: palette.okInk,
              border: palette.okInk,
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            palette: palette,
            title: '組織リソース利用量とクォータ上限',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (state.quotas.isEmpty)
                  Text(
                    'クォータ計測データがまだありません。利用計測または上限更新を実行すると表示されます。',
                    softWrap: true,
                    style: TextStyle(color: palette.secondaryInk, height: 1.5),
                  )
                else
                  for (final OrganizationQuotaUsage quota in state.quotas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuotaItemTile(
                        quota: quota,
                        palette: palette,
                      ),
                    ),
                const SizedBox(height: 8),
                DropdownButtonFormField<OrgQuotaResourceType>(
                  key: const ValueKey<String>('org_quota_resource_select'),
                  initialValue: selectedResourceType,
                  isExpanded: true,
                  dropdownColor: palette.cardBg,
                  style: TextStyle(color: palette.primaryInk),
                  decoration: InputDecoration(
                    labelText: '対象リソース',
                    labelStyle: TextStyle(color: palette.secondaryInk),
                    filled: true,
                    fillColor: palette.subSurface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.borderInk),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.btnBg, width: 2),
                    ),
                  ),
                  items: OrgQuotaResourceType.values
                      .map(
                        (final OrgQuotaResourceType type) =>
                            DropdownMenuItem<OrgQuotaResourceType>(
                          value: type,
                          child: Text(
                            '${type.labelJa} (${type.unitLabel})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.primaryInk),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (final OrgQuotaResourceType? value) {
                    if (value != null) onResourceTypeChanged(value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>('org_quota_limit_input'),
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: palette.primaryInk),
                  decoration: InputDecoration(
                    labelText: '上限値 (${selectedResourceType.unitLabel})',
                    labelStyle: TextStyle(color: palette.secondaryInk),
                    filled: true,
                    fillColor: palette.subSurface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.borderInk),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>('org_quota_units_input'),
                  controller: unitsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: palette.primaryInk),
                  decoration: InputDecoration(
                    labelText: '利用カウント試験数',
                    labelStyle: TextStyle(color: palette.secondaryInk),
                    filled: true,
                    fillColor: palette.subSurface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: palette.borderInk),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        key: const ValueKey<String>(
                          'org_quota_update_limit_btn',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.btnBg,
                          foregroundColor: palette.btnFg,
                        ),
                        onPressed: state.isSubmitting ? null : onUpdateLimit,
                        child: const Text('上限を更新'),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton(
                        key: const ValueKey<String>('org_quota_consume_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primaryInk,
                          side: BorderSide(color: palette.borderInk),
                        ),
                        onPressed: state.isSubmitting ? null : onConsumeQuota,
                        child: const Text('利用量を計上・検証'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (state.alerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            _SectionCard(
              palette: palette,
              title: '管理者クォータアラート履歴',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final OrganizationQuotaAlert alert in state.alerts)
                    Container(
                      key: ValueKey<String>('org_quota_alert_${alert.id}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.subSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.borderInk),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _OrgStatusBadge(
                                label: alert.alertLevel.labelJa,
                                bg: alert.alertLevel ==
                                        OrgQuotaAlertLevel.limit100
                                    ? palette.errBg
                                    : palette.warnBg,
                                ink: alert.alertLevel ==
                                        OrgQuotaAlertLevel.limit100
                                    ? palette.errInk
                                    : palette.warnInk,
                              ),
                              _OrgStatusBadge(
                                label:
                                    alert.isAcknowledged ? '管理者確認済み' : '未確認通知',
                                bg: alert.isAcknowledged
                                    ? palette.okBg
                                    : palette.badgeBg,
                                ink: alert.isAcknowledged
                                    ? palette.okInk
                                    : palette.badgeInk,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            alert.message,
                            softWrap: true,
                            style: TextStyle(
                              color: palette.primaryInk,
                              height: 1.5,
                            ),
                          ),
                          if (!alert.isAcknowledged) ...<Widget>[
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: OutlinedButton(
                                key: ValueKey<String>(
                                  'org_quota_ack_btn_${alert.id}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.primaryInk,
                                  side: BorderSide(color: palette.borderInk),
                                ),
                                onPressed: state.isSubmitting
                                    ? null
                                    : () => onAcknowledgeAlert(alert.id),
                                child: const Text('アラートを確認済みにする'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            palette: palette,
            title: '組織監査ログ (${state.filteredLogs.length} 件)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final OrgAuditEventType filter
                        in const <OrgAuditEventType>[
                      OrgAuditEventType.all,
                      OrgAuditEventType.login,
                      OrgAuditEventType.permissionChange,
                      OrgAuditEventType.resourceCreate,
                      OrgAuditEventType.resourceDelete,
                    ])
                      ChoiceChip(
                        key: ValueKey<String>(
                          'org_audit_filter_${filter.wireValue}',
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(filter.labelJa),
                        selected: state.selectedFilter == filter,
                        onSelected: (final bool _) => onSelectFilter(filter),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.filteredLogs.isEmpty)
                  Text(
                    '条件に一致する監査ログはありません。',
                    softWrap: true,
                    style: TextStyle(color: palette.secondaryInk, height: 1.5),
                  )
                else
                  for (final OrganizationAuditLogEntry entry
                      in state.filteredLogs)
                    Container(
                      key: ValueKey<String>('org_audit_log_${entry.id}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.subSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.borderInk),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              _OrgStatusBadge(
                                label: entry.eventType.labelJa,
                                bg: palette.badgeBg,
                                ink: palette.badgeInk,
                              ),
                              Text(
                                entry.resourceType,
                                softWrap: true,
                                style: TextStyle(
                                  color: palette.primaryInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (entry.summary.isNotEmpty)
                            Text(
                              entry.summary,
                              softWrap: true,
                              style: TextStyle(
                                color: palette.primaryInk,
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '実行者: ${entry.actorUserId ?? 'system'} (${entry.actorRole}) • ${entry.createdAt.toIso8601String()}',
                            softWrap: true,
                            style: TextStyle(
                              color: palette.secondaryInk,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.title,
    required this.child,
  });

  final _OrgPalette palette;
  final String title;
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderInk),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              softWrap: true,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuotaItemTile extends StatelessWidget {
  const _QuotaItemTile({
    required this.quota,
    required this.palette,
  });

  final OrganizationQuotaUsage quota;
  final _OrgPalette palette;

  @override
  Widget build(final BuildContext context) {
    final Color statusBg = quota.isExceeded
        ? palette.errBg
        : (quota.isWarning80 ? palette.warnBg : palette.okBg);
    final Color statusInk = quota.isExceeded
        ? palette.errInk
        : (quota.isWarning80 ? palette.warnInk : palette.okInk);
    final String statusText = quota.isExceeded
        ? '上限到達 (${quota.usagePct.toStringAsFixed(1)}%)'
        : (quota.isWarning80
            ? '80% 警告 (${quota.usagePct.toStringAsFixed(1)}%)'
            : '正常 (${quota.usagePct.toStringAsFixed(1)}%)');

    return Container(
      key: ValueKey<String>('org_quota_card_${quota.resourceType.wireValue}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderInk),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                quota.resourceType.labelJa,
                softWrap: true,
                style: TextStyle(
                  color: palette.primaryInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _OrgStatusBadge(
                label: statusText,
                bg: statusBg,
                ink: statusInk,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (quota.usagePct / 100.0).clamp(0.0, 1.0),
            backgroundColor: palette.borderInk.withValues(alpha: 0.3),
            color: statusInk,
            minHeight: 8,
          ),
          const SizedBox(height: 6),
          Text(
            '利用量: ${quota.usedAmount} / ${quota.limitAmount} ${quota.resourceType.unitLabel} (残枠 ${quota.remaining})',
            softWrap: true,
            style: TextStyle(
              color: palette.secondaryInk,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.bg,
    required this.ink,
    required this.border,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color bg;
  final Color ink;
  final Color border;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(icon, color: ink, size: 20),
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              softWrap: true,
              style: TextStyle(
                color: ink,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgStatusBadge extends StatelessWidget {
  const _OrgStatusBadge({
    required this.label,
    required this.bg,
    required this.ink,
  });

  final String label;
  final Color bg;
  final Color ink;

  @override
  Widget build(final BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          softWrap: true,
          style: TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
