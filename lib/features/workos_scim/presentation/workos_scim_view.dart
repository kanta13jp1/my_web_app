import 'package:flutter/material.dart';

import '../application/workos_scim_controller.dart';
import '../domain/workos_scim_models.dart';

/// Pure presentation view for WorkOS Admin Portal & Directory Sync SCIM (#2683).
class WorkosScimView extends StatelessWidget {
  const WorkosScimView({
    super.key,
    required this.state,
    required this.requiredAccessRole,
    required this.orgIdController,
    required this.orgNameController,
    required this.onRetryLoad,
    required this.onSelectOrganization,
    required this.onRegisterOrganization,
    required this.onSelectIntent,
    required this.onGeneratePortalLink,
    required this.onOpenPortalUrl,
    required this.onSelectStatusFilter,
    required this.onUpdateMemberRole,
    required this.onSelectRequiredRole,
  });

  final WorkosScimState state;
  final WorkosOrgRole requiredAccessRole;
  final TextEditingController orgIdController;
  final TextEditingController orgNameController;
  final VoidCallback onRetryLoad;
  final ValueChanged<String> onSelectOrganization;
  final VoidCallback onRegisterOrganization;
  final ValueChanged<WorkosPortalIntent> onSelectIntent;
  final VoidCallback onGeneratePortalLink;
  final ValueChanged<String> onOpenPortalUrl;
  final ValueChanged<WorkosProvisioningStatus?> onSelectStatusFilter;
  final void Function(String directoryUserId, WorkosOrgRole role)
      onUpdateMemberRole;
  final ValueChanged<WorkosOrgRole> onSelectRequiredRole;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedOrg = state.selectedOrganization;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderCard(
            selectedOrg: selectedOrg,
            memberCount: state.members.length,
            isLoading: state.isLoading,
            colors: colors,
            onRefresh: onRetryLoad,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _BannerCard(
              key: const ValueKey<String>('workos_error_banner'),
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('workos_retry_button'),
              onAction: onRetryLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _BannerCard(
              key: const ValueKey<String>('workos_status_notice'),
              message: state.statusNotice!,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _OrganizationPortalCard(
            state: state,
            orgIdController: orgIdController,
            orgNameController: orgNameController,
            colors: colors,
            onSelectOrganization: onSelectOrganization,
            onRegisterOrganization: onRegisterOrganization,
            onSelectIntent: onSelectIntent,
            onGeneratePortalLink: onGeneratePortalLink,
            onOpenPortalUrl: onOpenPortalUrl,
          ),
          const SizedBox(height: 12),
          _DirectoryMembersCard(
            state: state,
            requiredAccessRole: requiredAccessRole,
            colors: colors,
            onSelectStatusFilter: onSelectStatusFilter,
            onSelectRequiredRole: onSelectRequiredRole,
            onUpdateMemberRole: onUpdateMemberRole,
          ),
          const SizedBox(height: 12),
          _ScimEventsCard(
            events: state.events,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.selectedOrg,
    required this.memberCount,
    required this.isLoading,
    required this.colors,
    required this.onRefresh,
  });

  final WorkosOrganization? selectedOrg;
  final int memberCount;
  final bool isLoading;
  final ColorScheme colors;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.business_center_outlined, color: colors.primary),
                Text(
                  'WorkOS Admin Portal & SCIM テナント管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Chip(
                  key: const ValueKey<String>('workos_scim_badge'),
                  backgroundColor: selectedOrg?.scimEnabled ?? false
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  label: Text(
                    selectedOrg?.scimEnabled ?? false
                        ? 'SCIM 有効 ($memberCount名)'
                        : '組織未選択',
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedOrg?.scimEnabled ?? false
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('workos_refresh_button'),
                  tooltip: '最新同期状態を取得',
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'B2B テナント管理者向け IdP 設定リンク発行、SCIM ユーザー追加/停止同期、組織別 RBAC 認可を一元管理します。',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            message,
            style: TextStyle(fontSize: 13, color: foregroundColor),
          ),
          if (actionLabel != null && onAction != null)
            OutlinedButton(
              key: actionKey,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: foregroundColor,
                side: BorderSide(color: foregroundColor),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _OrganizationPortalCard extends StatelessWidget {
  const _OrganizationPortalCard({
    required this.state,
    required this.orgIdController,
    required this.orgNameController,
    required this.colors,
    required this.onSelectOrganization,
    required this.onRegisterOrganization,
    required this.onSelectIntent,
    required this.onGeneratePortalLink,
    required this.onOpenPortalUrl,
  });

  final WorkosScimState state;
  final TextEditingController orgIdController;
  final TextEditingController orgNameController;
  final ColorScheme colors;
  final ValueChanged<String> onSelectOrganization;
  final VoidCallback onRegisterOrganization;
  final ValueChanged<WorkosPortalIntent> onSelectIntent;
  final VoidCallback onGeneratePortalLink;
  final ValueChanged<String> onOpenPortalUrl;

  @override
  Widget build(final BuildContext context) {
    final portalResult = state.latestPortalResult;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Admin Portal セッション発行',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (state.organizations.isNotEmpty) ...<Widget>[
              KeyedSubtree(
                key: ValueKey<String>(
                  'workos_org_subtree_${state.selectedOrganization?.workosOrgId ?? 'none'}',
                ),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('workos_org_dropdown'),
                  initialValue: state.selectedOrganization?.workosOrgId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '管理対象 WorkOS 組織',
                    border: OutlineInputBorder(),
                  ),
                  items: state.organizations
                      .map(
                        (final WorkosOrganization org) =>
                            DropdownMenuItem<String>(
                          value: org.workosOrgId,
                          child: Text(
                            '${org.organizationName} (${org.workosOrgId})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (final String? val) {
                    if (val != null) {
                      onSelectOrganization(val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey<String>('workos_org_id_field'),
              controller: orgIdController,
              decoration: const InputDecoration(
                labelText: '新規 WorkOS Organization ID (例: org_01...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('workos_org_name_field'),
              controller: orgNameController,
              decoration: const InputDecoration(
                labelText: '組織名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('workos_register_org_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.isSubmitting ? null : onRegisterOrganization,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('組織を登録'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<WorkosPortalIntent>(
              key: const ValueKey<String>('workos_intent_dropdown'),
              initialValue: state.selectedIntent,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Portal Intent (設定目的)',
                border: OutlineInputBorder(),
              ),
              items: WorkosPortalIntent.values
                  .map(
                    (final WorkosPortalIntent intent) =>
                        DropdownMenuItem<WorkosPortalIntent>(
                      value: intent,
                      child: Text(
                        intent.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (final WorkosPortalIntent? val) {
                if (val != null) {
                  onSelectIntent(val);
                }
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey<String>('workos_generate_portal_button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSubmitting ? null : onGeneratePortalLink,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Admin Portal リンクを生成'),
            ),
            if (portalResult != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey<String>('workos_portal_result_card'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      portalResult.isOfflineFallback
                          ? 'オフラインプレビューモード (WORKOS_API_KEY 未設定)'
                          : '有効リンク発行済み (有効期限 ${portalResult.expiresInSeconds}秒)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      portalResult.portalUrl ?? portalResult.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    if (portalResult.portalUrl != null) ...<Widget>[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        key:
                            const ValueKey<String>('workos_open_portal_button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () =>
                            onOpenPortalUrl(portalResult.portalUrl!),
                        child: const Text('Admin Portal を開く'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectoryMembersCard extends StatelessWidget {
  const _DirectoryMembersCard({
    required this.state,
    required this.requiredAccessRole,
    required this.colors,
    required this.onSelectStatusFilter,
    required this.onSelectRequiredRole,
    required this.onUpdateMemberRole,
  });

  final WorkosScimState state;
  final WorkosOrgRole requiredAccessRole;
  final ColorScheme colors;
  final ValueChanged<WorkosProvisioningStatus?> onSelectStatusFilter;
  final ValueChanged<WorkosOrgRole> onSelectRequiredRole;
  final void Function(String directoryUserId, WorkosOrgRole role)
      onUpdateMemberRole;

  @override
  Widget build(final BuildContext context) {
    final orgEnabled = state.selectedOrganization?.scimEnabled ?? false;
    final filtered = state.filteredMembers;

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Directory Sync メンバー・組織別 RBAC 認可チェック',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  key: const ValueKey<String>('workos_filter_all'),
                  label: const Text('すべて'),
                  selected: state.statusFilter == null,
                  onSelected: (final bool _) => onSelectStatusFilter(null),
                ),
                for (final status in WorkosProvisioningStatus.values)
                  ChoiceChip(
                    key: ValueKey<String>('workos_filter_${status.wireValue}'),
                    label: Text(status.label),
                    selected: state.statusFilter == status,
                    onSelected: (final bool _) => onSelectStatusFilter(status),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<WorkosOrgRole>(
              key: const ValueKey<String>('workos_required_role_dropdown'),
              initialValue: requiredAccessRole,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '検証対象の必要ロール (RBAC ポリシー)',
                border: OutlineInputBorder(),
              ),
              items: WorkosOrgRole.values
                  .map(
                    (final WorkosOrgRole role) =>
                        DropdownMenuItem<WorkosOrgRole>(
                      value: role,
                      child: Text(
                        role.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (final WorkosOrgRole? val) {
                if (val != null) {
                  onSelectRequiredRole(val);
                }
              },
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Text(
                '該当する SCIM プロビジョニング済みメンバーはありません。',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              )
            else
              for (final member in filtered)
                _MemberRow(
                  member: member,
                  orgScimEnabled: orgEnabled,
                  requiredAccessRole: requiredAccessRole,
                  isSubmitting: state.isSubmitting,
                  colors: colors,
                  onUpdateRole: onUpdateMemberRole,
                ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.orgScimEnabled,
    required this.requiredAccessRole,
    required this.isSubmitting,
    required this.colors,
    required this.onUpdateRole,
  });

  final WorkosDirectoryMember member;
  final bool orgScimEnabled;
  final WorkosOrgRole requiredAccessRole;
  final bool isSubmitting;
  final ColorScheme colors;
  final void Function(String directoryUserId, WorkosOrgRole role) onUpdateRole;

  @override
  Widget build(final BuildContext context) {
    final allowed = member.canAccess(
      orgScimEnabled: orgScimEnabled,
      requiredRole: requiredAccessRole,
    );
    return Container(
      key: ValueKey<String>('workos_member_${member.directoryUserId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                member.displayName.isNotEmpty
                    ? '${member.displayName} (${member.email})'
                    : member.email,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              Chip(
                backgroundColor:
                    member.status == WorkosProvisioningStatus.active
                        ? colors.primaryContainer
                        : colors.errorContainer,
                label: Text(
                  member.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: member.status == WorkosProvisioningStatus.active
                        ? colors.onPrimaryContainer
                        : colors.onErrorContainer,
                  ),
                ),
              ),
              Chip(
                key: ValueKey<String>(
                  'workos_rbac_${member.directoryUserId}',
                ),
                backgroundColor:
                    allowed ? colors.secondaryContainer : colors.errorContainer,
                label: Text(
                  allowed ? '認可: 許可' : '認可: 拒否',
                  style: TextStyle(
                    fontSize: 11,
                    color: allowed
                        ? colors.onSecondaryContainer
                        : colors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: ValueKey<String>(
              'workos_role_subtree_${member.directoryUserId}_${member.role.wireValue}',
            ),
            child: DropdownButtonFormField<WorkosOrgRole>(
              key: ValueKey<String>('workos_role_${member.directoryUserId}'),
              initialValue: member.role,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '割り当てロール',
                border: OutlineInputBorder(),
              ),
              items: WorkosOrgRole.values
                  .map(
                    (final WorkosOrgRole role) =>
                        DropdownMenuItem<WorkosOrgRole>(
                      value: role,
                      child: Text(
                        role.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isSubmitting
                  ? null
                  : (final WorkosOrgRole? next) {
                      if (next != null && next != member.role) {
                        onUpdateRole(member.directoryUserId, next);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScimEventsCard extends StatelessWidget {
  const _ScimEventsCard({
    required this.events,
    required this.colors,
  });

  final List<WorkosScimEvent> events;
  final ColorScheme colors;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'SCIM Webhook 同期ログ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              Text(
                '同期済み SCIM イベントはまだありません。',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              )
            else
              for (final event in events)
                Padding(
                  key: ValueKey<String>('workos_event_${event.workosEventId}'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        event.eventType,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        '${event.directoryUserId} -> ${event.targetStatus.wireValue}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
