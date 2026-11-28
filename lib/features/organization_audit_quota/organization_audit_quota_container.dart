import 'package:flutter/material.dart';

import 'application/organization_audit_quota_controller.dart';
import 'data/supabase_organization_audit_quota_repository.dart';
import 'domain/organization_audit_quota_models.dart';
import 'presentation/organization_audit_quota_view.dart';

/// 組織監査ログ・クォータ管理画面の Container (#2692).
class OrganizationAuditQuotaContainer extends StatefulWidget {
  const OrganizationAuditQuotaContainer({
    super.key,
    required this.organizationId,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final String organizationId;
  final OrganizationAuditQuotaRepository? repository;
  final OrganizationAuditQuotaController? controller;
  final bool autoLoad;

  @override
  State<OrganizationAuditQuotaContainer> createState() =>
      _OrganizationAuditQuotaContainerState();
}

class _OrganizationAuditQuotaContainerState
    extends State<OrganizationAuditQuotaContainer> {
  late OrganizationAuditQuotaController _controller;
  late bool _ownsController;
  final TextEditingController _limitController =
      TextEditingController(text: '1000');
  final TextEditingController _unitsController =
      TextEditingController(text: '10');
  OrgQuotaResourceType _selectedResourceType = OrgQuotaResourceType.apiCalls;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.autoLoad) {
      Future<void>.microtask(_loadInitial);
    }
  }

  void _initController() {
    final OrganizationAuditQuotaController? provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ??
        OrganizationAuditQuotaController(
          repository:
              widget.repository ?? SupabaseOrganizationAuditQuotaRepository(),
          organizationId: widget.organizationId,
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) return;
    await _controller.loadDashboard();
  }

  @override
  void didUpdateWidget(
    covariant final OrganizationAuditQuotaContainer oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.repository != oldWidget.repository ||
        widget.organizationId != oldWidget.organizationId) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      if (widget.autoLoad) {
        Future<void>.microtask(_loadInitial);
      }
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    _unitsController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleUpdateLimit() {
    final int parsedLimit = int.tryParse(_limitController.text.trim()) ?? 0;
    if (parsedLimit <= 0) return;
    _controller.updateQuotaLimit(
      resourceType: _selectedResourceType,
      limitAmount: parsedLimit,
    );
  }

  void _handleConsumeQuota() {
    final int parsedUnits = int.tryParse(_unitsController.text.trim()) ?? 1;
    if (parsedUnits <= 0) return;
    _controller.consumeResourceQuota(
      resourceType: _selectedResourceType,
      units: parsedUnits,
    );
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return OrganizationAuditQuotaView(
          state: _controller.state,
          selectedResourceType: _selectedResourceType,
          limitController: _limitController,
          unitsController: _unitsController,
          onRefresh: _controller.loadDashboard,
          onSelectFilter: _controller.selectFilter,
          onResourceTypeChanged: (final OrgQuotaResourceType value) {
            setState(() => _selectedResourceType = value);
          },
          onUpdateLimit: _handleUpdateLimit,
          onConsumeQuota: _handleConsumeQuota,
          onAcknowledgeAlert: _controller.acknowledgeAlert,
        );
      },
    );
  }
}
