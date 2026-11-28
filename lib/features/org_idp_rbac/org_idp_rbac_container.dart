import 'package:flutter/material.dart';

import 'application/org_idp_rbac_controller.dart';
import 'data/supabase_org_idp_rbac_repository.dart';
import 'domain/org_idp_rbac_models.dart';
import 'presentation/org_idp_rbac_view.dart';

/// DI container for Org / IdP Group RBAC & SSO management (#2691).
class OrgIdpRbacContainer extends StatefulWidget {
  const OrgIdpRbacContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final OrgIdpRbacRepository? repository;
  final OrgIdpRbacController? controller;
  final bool autoLoad;

  @override
  State<OrgIdpRbacContainer> createState() => _OrgIdpRbacContainerState();
}

class _OrgIdpRbacContainerState extends State<OrgIdpRbacContainer> {
  late final OrgIdpRbacController _controller;
  late final bool _ownsController;
  final TextEditingController _groupIdController = TextEditingController();
  final TextEditingController _groupLabelController = TextEditingController();
  final TextEditingController _ssoGroupsController = TextEditingController();
  bool _simulateAzureOverage = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        OrgIdpRbacController(
          repository: widget.repository ?? SupabaseOrgIdpRbacRepository(),
        );
    if (widget.autoLoad) {
      _controller.loadDashboard();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _groupIdController.dispose();
    _groupLabelController.dispose();
    _ssoGroupsController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return OrgIdpRbacView(
          state: _controller.state,
          groupIdController: _groupIdController,
          groupLabelController: _groupLabelController,
          ssoGroupsController: _ssoGroupsController,
          simulateAzureOverage: _simulateAzureOverage,
          onRetryLoad: () {
            _controller.loadDashboard();
          },
          onSelectOrganization: (final String orgId) {
            _controller.selectOrganization(orgId);
          },
          onSelectProvider: (final IdpProviderKind provider) {
            _controller.selectProvider(provider);
          },
          onSelectMappedRole: (final OrgRbacRole role) {
            _controller.selectMappedRole(role);
          },
          onSaveMapping: () async {
            final ok = await _controller.saveMapping(
              idpGroupId: _groupIdController.text,
              idpGroupLabel: _groupLabelController.text,
            );
            if (!mounted || !ok) {
              return;
            }
            _groupIdController.clear();
            _groupLabelController.clear();
          },
          onDeleteMapping: (final String mappingId) {
            _controller.deleteMapping(mappingId);
          },
          onToggleAzureOverage: (final bool nextVal) {
            setState(() {
              _simulateAzureOverage = nextVal;
            });
          },
          onEvaluateSso: () {
            _controller.evaluateSso(
              groupsCsv: _ssoGroupsController.text,
              simulateAzureOverage: _simulateAzureOverage,
            );
          },
        );
      },
    );
  }
}
