import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'application/workos_scim_controller.dart';
import 'data/supabase_workos_scim_repository.dart';
import 'domain/workos_scim_models.dart';
import 'presentation/workos_scim_view.dart';

/// WorkOS Admin Portal & Directory Sync (SCIM) Container (#2683).
class WorkosScimContainer extends StatefulWidget {
  const WorkosScimContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
    this.onOpenPortalUrl,
  });

  final WorkosScimRepository? repository;
  final WorkosScimController? controller;
  final bool autoLoad;
  final ValueChanged<String>? onOpenPortalUrl;

  @override
  State<WorkosScimContainer> createState() => _WorkosScimContainerState();
}

class _WorkosScimContainerState extends State<WorkosScimContainer> {
  late final WorkosScimController _controller;
  late final bool _ownsController;
  final TextEditingController _orgIdController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  WorkosOrgRole _requiredAccessRole = WorkosOrgRole.member;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        WorkosScimController(
          repository: widget.repository ?? SupabaseWorkosScimRepository(),
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
    _orgIdController.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _openPortalUrl(final String rawUrl) async {
    final customHandler = widget.onOpenPortalUrl;
    if (customHandler != null) {
      customHandler(rawUrl);
      return;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https') {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return WorkosScimView(
          state: _controller.state,
          requiredAccessRole: _requiredAccessRole,
          orgIdController: _orgIdController,
          orgNameController: _orgNameController,
          onRetryLoad: () {
            _controller.loadDashboard();
          },
          onSelectOrganization: (final String orgId) {
            _controller.selectOrganization(orgId);
          },
          onRegisterOrganization: () async {
            final ok = await _controller.registerOrganization(
              workosOrgId: _orgIdController.text,
              organizationName: _orgNameController.text,
            );
            if (!mounted || !ok) {
              return;
            }
            _orgIdController.clear();
            _orgNameController.clear();
          },
          onSelectIntent: (final WorkosPortalIntent intent) {
            _controller.selectIntent(intent);
          },
          onGeneratePortalLink: () {
            _controller.generateAdminPortalLink();
          },
          onOpenPortalUrl: _openPortalUrl,
          onSelectStatusFilter: (final WorkosProvisioningStatus? status) {
            _controller.selectStatusFilter(status);
          },
          onUpdateMemberRole: (
            final String directoryUserId,
            final WorkosOrgRole role,
          ) {
            _controller.updateMemberRole(
              directoryUserId: directoryUserId,
              role: role,
            );
          },
          onSelectRequiredRole: (final WorkosOrgRole role) {
            setState(() {
              _requiredAccessRole = role;
            });
          },
        );
      },
    );
  }
}
