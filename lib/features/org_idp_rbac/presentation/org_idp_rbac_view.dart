import 'package:flutter/material.dart';

import '../application/org_idp_rbac_controller.dart';
import '../domain/org_idp_rbac_models.dart';

/// Pure presentation view for Org/IdP Group RBAC & SSO control (#2691).
class OrgIdpRbacView extends StatelessWidget {
  const OrgIdpRbacView({
    super.key,
    required this.state,
    required this.groupIdController,
    required this.groupLabelController,
    required this.ssoGroupsController,
    required this.simulateAzureOverage,
    required this.onRetryLoad,
    required this.onSelectOrganization,
    required this.onSelectProvider,
    required this.onSelectMappedRole,
    required this.onSaveMapping,
    required this.onDeleteMapping,
    required this.onToggleAzureOverage,
    required this.onEvaluateSso,
  });

  final OrgIdpRbacState state;
  final TextEditingController groupIdController;
  final TextEditingController groupLabelController;
  final TextEditingController ssoGroupsController;
  final bool simulateAzureOverage;
  final VoidCallback onRetryLoad;
  final ValueChanged<String> onSelectOrganization;
  final ValueChanged<IdpProviderKind> onSelectProvider;
  final ValueChanged<OrgRbacRole> onSelectMappedRole;
  final VoidCallback onSaveMapping;
  final ValueChanged<String> onDeleteMapping;
  final ValueChanged<bool> onToggleAzureOverage;
  final VoidCallback onEvaluateSso;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final caps = state.capabilities;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RoleHeaderCard(
            state: state,
            colors: colors,
            onRefresh: onRetryLoad,
            onSelectOrganization: onSelectOrganization,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _AlertBanner(
              key: const ValueKey<String>('idp_rbac_error_banner'),
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('idp_rbac_retry_button'),
              onAction: onRetryLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _AlertBanner(
              key: const ValueKey<String>('idp_rbac_status_banner'),
              message: state.statusNotice!,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _RoleCapabilitiesCard(
            caps: caps,
            colors: colors,
          ),
          const SizedBox(height: 12),
          if (caps.canManageIdpMappings) ...<Widget>[
            _AdminMappingEditorCard(
              key: const ValueKey<String>('idp_rbac_admin_editor_card'),
              state: state,
              groupIdController: groupIdController,
              groupLabelController: groupLabelController,
              colors: colors,
              onSelectProvider: onSelectProvider,
              onSelectMappedRole: onSelectMappedRole,
              onSaveMapping: onSaveMapping,
            ),
            const SizedBox(height: 12),
          ] else ...<Widget>[
            _RestrictedNoticeCard(
              key: const ValueKey<String>('idp_rbac_restricted_card'),
              role: state.callerRole,
              colors: colors,
            ),
            const SizedBox(height: 12),
          ],
          _GroupMappingsListCard(
            mappings: state.mappings,
            canDelete: caps.canManageIdpMappings && !state.isSaving,
            colors: colors,
            onDeleteMapping: onDeleteMapping,
          ),
          const SizedBox(height: 12),
          _SsoSimulatorCard(
            state: state,
            ssoGroupsController: ssoGroupsController,
            simulateAzureOverage: simulateAzureOverage,
            colors: colors,
            onSelectProvider: onSelectProvider,
            onToggleAzureOverage: onToggleAzureOverage,
            onEvaluateSso: onEvaluateSso,
          ),
        ],
      ),
    );
  }
}

class _RoleHeaderCard extends StatelessWidget {
  const _RoleHeaderCard({
    required this.state,
    required this.colors,
    required this.onRefresh,
    required this.onSelectOrganization,
  });

  final OrgIdpRbacState state;
  final ColorScheme colors;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSelectOrganization;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(Icons.verified_user_outlined, color: colors.primary),
                Text(
                  '組織 IdP グループ RBAC & SSO 制御',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Chip(
                  key: const ValueKey<String>('idp_rbac_role_chip'),
                  backgroundColor: state.callerRole == OrgRbacRole.none
                      ? colors.errorContainer
                      : colors.primaryContainer,
                  label: Text(
                    '現在ロール: ${state.callerRole.label}',
                    style: TextStyle(
                      fontSize: 12,
                      color: state.callerRole == OrgRbacRole.none
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('idp_rbac_refresh_button'),
                  tooltip: '組織 RBAC 状態を再読み込み',
                  onPressed: state.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Okta / Microsoft Entra ID グループクレームとテナント RLS により、組織間のデータ分離とロール別 UI 出し分けを制御します。',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            if (state.organizations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              KeyedSubtree(
                key: ValueKey<String>(
                  'idp_org_subtree_${state.selectedOrgId ?? 'none'}',
                ),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('idp_org_dropdown'),
                  initialValue: state.selectedOrgId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '対象テナント組織',
                    border: OutlineInputBorder(),
                  ),
                  items: state.organizations
                      .map(
                        (final OrgTenantSummary org) =>
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
                  onChanged: (final String? value) {
                    if (value != null) {
                      onSelectOrganization(value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCapabilitiesCard extends StatelessWidget {
  const _RoleCapabilitiesCard({
    required this.caps,
    required this.colors,
  });

  final OrgUiCapabilities caps;
  final ColorScheme colors;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(
              key: const ValueKey<String>('cap_view_chip'),
              label: Text(
                caps.canViewOrg ? 'テナント閲覧: 許可' : 'テナント閲覧: 拒否',
              ),
            ),
            Chip(
              key: const ValueKey<String>('cap_member_chip'),
              label: Text(
                caps.canExecuteMemberActions
                    ? 'メンバー操作 API: 許可'
                    : 'メンバー操作 API: 拒否',
              ),
            ),
            Chip(
              key: const ValueKey<String>('cap_admin_chip'),
              label: Text(
                caps.canManageIdpMappings ? 'IdP ルール管理: 許可' : 'IdP ルール管理: 不可',
              ),
            ),
            Chip(
              key: const ValueKey<String>('cap_owner_chip'),
              label: Text(
                caps.canAssignOwnerRole ? 'オーナー権限委譲: 許可' : 'オーナー権限委譲: 不可',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMappingEditorCard extends StatelessWidget {
  const _AdminMappingEditorCard({
    super.key,
    required this.state,
    required this.groupIdController,
    required this.groupLabelController,
    required this.colors,
    required this.onSelectProvider,
    required this.onSelectMappedRole,
    required this.onSaveMapping,
  });

  final OrgIdpRbacState state;
  final TextEditingController groupIdController;
  final TextEditingController groupLabelController;
  final ColorScheme colors;
  final ValueChanged<IdpProviderKind> onSelectProvider;
  final ValueChanged<OrgRbacRole> onSelectMappedRole;
  final VoidCallback onSaveMapping;

  @override
  Widget build(final BuildContext context) {
    final assignableRoles = <OrgRbacRole>[
      if (state.capabilities.canAssignOwnerRole) OrgRbacRole.owner,
      OrgRbacRole.admin,
      OrgRbacRole.member,
      OrgRbacRole.viewer,
    ];
    final currentMapped = assignableRoles.contains(state.selectedMappedRole)
        ? state.selectedMappedRole
        : OrgRbacRole.member;

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '管理者設定: IdP グループ → ロール自動割り当てルール',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: ValueKey<String>(
                'provider_subtree_${state.selectedProvider.wireValue}',
              ),
              child: DropdownButtonFormField<IdpProviderKind>(
                key: const ValueKey<String>('idp_provider_dropdown'),
                initialValue: state.selectedProvider,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'SSO / IdP プロバイダ',
                  border: OutlineInputBorder(),
                ),
                items: IdpProviderKind.values
                    .map(
                      (final IdpProviderKind p) =>
                          DropdownMenuItem<IdpProviderKind>(
                        value: p,
                        child: Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (final IdpProviderKind? value) {
                  if (value != null) {
                    onSelectProvider(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('idp_group_id_field'),
              controller: groupIdController,
              decoration: const InputDecoration(
                labelText: 'IdP グループ ID / 名前 (Okta グループ名 または Entra Object ID)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('idp_group_label_field'),
              controller: groupLabelController,
              decoration: const InputDecoration(
                labelText: '表示ラベル (任意)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: ValueKey<String>(
                'mapped_role_subtree_${currentMapped.wireValue}',
              ),
              child: DropdownButtonFormField<OrgRbacRole>(
                key: const ValueKey<String>('idp_mapped_role_dropdown'),
                initialValue: currentMapped,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '割り当て先アプリロール',
                  border: OutlineInputBorder(),
                ),
                items: assignableRoles
                    .map(
                      (final OrgRbacRole r) => DropdownMenuItem<OrgRbacRole>(
                        value: r,
                        child: Text(
                          r.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (final OrgRbacRole? value) {
                  if (value != null) {
                    onSelectMappedRole(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey<String>('idp_save_mapping_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSaving ? null : onSaveMapping,
              icon: const Icon(Icons.save_outlined),
              label: const Text('IdP マッピングを保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestrictedNoticeCard extends StatelessWidget {
  const _RestrictedNoticeCard({
    super.key,
    required this.role,
    required this.colors,
  });

  final OrgRbacRole role;
  final ColorScheme colors;

  @override
  Widget build(final BuildContext context) {
    final isDenied = role == OrgRbacRole.none;
    return Card(
      color: isDenied ? colors.errorContainer : colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          isDenied
              ? 'この組織への有効なメンバーシップまたは IdP グループ権限が確認できないため、設定および操作 API はブロックされています。'
              : '現在のロール (${role.label}) では IdP グループマッピングの閲覧のみ許可されています（作成・削除は管理者専用）。',
          style: TextStyle(
            fontSize: 13,
            color: isDenied ? colors.onErrorContainer : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _GroupMappingsListCard extends StatelessWidget {
  const _GroupMappingsListCard({
    required this.mappings,
    required this.canDelete,
    required this.colors,
    required this.onDeleteMapping,
  });

  final List<IdpGroupMapping> mappings;
  final bool canDelete;
  final ColorScheme colors;
  final ValueChanged<String> onDeleteMapping;

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
              '登録済み IdP グループマッピング (${mappings.length})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (mappings.isEmpty)
              Text(
                'マッピングはまだ登録されていません。',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              )
            else
              ...mappings.map(
                (final IdpGroupMapping item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Chip(label: Text(item.idpProvider.wireValue)),
                      Text(
                        item.idpGroupLabel.isNotEmpty
                            ? '${item.idpGroupLabel} (${item.idpGroupId})'
                            : item.idpGroupId,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      Chip(label: Text(item.mappedRole.label)),
                      if (canDelete)
                        IconButton(
                          key: ValueKey<String>('delete_mapping_${item.id}'),
                          tooltip: 'マッピング削除',
                          onPressed: () => onDeleteMapping(item.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SsoSimulatorCard extends StatelessWidget {
  const _SsoSimulatorCard({
    required this.state,
    required this.ssoGroupsController,
    required this.simulateAzureOverage,
    required this.colors,
    required this.onSelectProvider,
    required this.onToggleAzureOverage,
    required this.onEvaluateSso,
  });

  final OrgIdpRbacState state;
  final TextEditingController ssoGroupsController;
  final bool simulateAzureOverage;
  final ColorScheme colors;
  final ValueChanged<IdpProviderKind> onSelectProvider;
  final ValueChanged<bool> onToggleAzureOverage;
  final VoidCallback onEvaluateSso;

  @override
  Widget build(final BuildContext context) {
    final evaluation = state.lastEvaluation;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'SSO グループアサーション / Overage 評価テスト',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: ValueKey<String>(
                'sso_provider_subtree_${state.selectedProvider.wireValue}',
              ),
              child: DropdownButtonFormField<IdpProviderKind>(
                key: const ValueKey<String>('sso_provider_dropdown'),
                initialValue: state.selectedProvider,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '評価対象 IdP プロバイダ',
                  border: OutlineInputBorder(),
                ),
                items: IdpProviderKind.values
                    .map(
                      (final IdpProviderKind p) =>
                          DropdownMenuItem<IdpProviderKind>(
                        value: p,
                        child: Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (final IdpProviderKind? value) {
                  if (value != null) {
                    onSelectProvider(value);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('sso_groups_csv_field'),
              controller: ssoGroupsController,
              decoration: const InputDecoration(
                labelText: 'SSO groups クレーム (カンマ区切り)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey<String>('sso_overage_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Entra ID hasgroups 超過 (overage) をシミュレート'),
              value: simulateAzureOverage,
              onChanged: onToggleAzureOverage,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const ValueKey<String>('sso_evaluate_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSaving ? null : onEvaluateSso,
              icon: const Icon(Icons.security),
              label: const Text('SSO アサーションでロール評価'),
            ),
            if (evaluation != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '判定結果: allowed=${evaluation.allowed}, role=${evaluation.resolvedRole.label}, source=${evaluation.resolutionSource}',
                key: const ValueKey<String>('sso_evaluation_result_text'),
                style: TextStyle(fontSize: 13, color: colors.onSurface),
              ),
              for (final String warning in evaluation.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    warning,
                    style: TextStyle(fontSize: 12, color: colors.error),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
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
