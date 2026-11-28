import 'package:flutter/material.dart';

import 'application/ai_compliance_controller.dart';
import 'data/supabase_ai_compliance_repository.dart';
import 'domain/ai_compliance_models.dart';
import 'presentation/ai_compliance_view.dart';

/// Stateful container wiring AI compliance review & approval workflow (#2763).
class AiComplianceContainer extends StatefulWidget {
  const AiComplianceContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final AiComplianceRepository? repository;
  final AiComplianceController? controller;

  @override
  State<AiComplianceContainer> createState() => _AiComplianceContainerState();
}

class _AiComplianceContainerState extends State<AiComplianceContainer> {
  late final AiComplianceController _controller;
  late final bool _ownsController;
  final TextEditingController _providerKeyController = TextEditingController();
  final TextEditingController _modelIdController = TextEditingController();
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _termsUrlController = TextEditingController();
  final TextEditingController _reviewNotesController = TextEditingController();
  final TextEditingController _reviewerController = TextEditingController();
  final TextEditingController _approvalNoteController = TextEditingController();
  bool _humanConfirmed = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiComplianceController(
          repository: widget.repository ?? SupabaseAiComplianceRepository(),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.loadRecords();
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _providerKeyController.dispose();
    _modelIdController.dispose();
    _providerNameController.dispose();
    _termsUrlController.dispose();
    _reviewNotesController.dispose();
    _reviewerController.dispose();
    _approvalNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (final BuildContext context, final Widget? _) {
        final selected = _controller.state.selectedRecord;
        return AiComplianceView(
          state: _controller.state,
          humanConfirmed: _humanConfirmed,
          providerKeyController: _providerKeyController,
          modelIdController: _modelIdController,
          providerNameController: _providerNameController,
          termsUrlController: _termsUrlController,
          reviewNotesController: _reviewNotesController,
          reviewerController: _reviewerController,
          approvalNoteController: _approvalNoteController,
          onRefresh: _controller.loadRecords,
          onSeedDefaults: _controller.seedDefaults,
          onFilterChanged: _controller.setStatusFilter,
          onSelectRecord: (final String id) {
            setState(() {
              _humanConfirmed = false;
            });
            _controller.selectRecord(id);
          },
          onToggleChecklist: (final ComplianceChecklistState next) {
            if (selected == null) {
              return;
            }
            _controller.updateChecklistFlag(
              recordId: selected.id,
              nextChecklist: next,
            );
          },
          onToggleHumanConfirmed: (final bool? value) {
            setState(() {
              _humanConfirmed = value ?? false;
            });
          },
          onApproveSelected: () async {
            final ok = await _controller.approveSelected(
              reviewerName: _reviewerController.text,
              humanConfirmed: _humanConfirmed,
              approvalNote: _approvalNoteController.text,
            );
            if (ok && mounted) {
              setState(() {
                _humanConfirmed = false;
              });
              _approvalNoteController.clear();
            }
          },
          onTestInvokeGuard: _controller.testInvokeGuard,
          onSubmitReview: () async {
            final ok = await _controller.submitReviewRequest(
              providerKey: _providerKeyController.text,
              modelId: _modelIdController.text,
              providerName: _providerNameController.text,
              termsUrl: _termsUrlController.text,
              reviewNotes: _reviewNotesController.text,
            );
            if (ok && mounted) {
              _providerKeyController.clear();
              _modelIdController.clear();
              _providerNameController.clear();
              _termsUrlController.clear();
              _reviewNotesController.clear();
            }
          },
        );
      },
    );
  }
}
