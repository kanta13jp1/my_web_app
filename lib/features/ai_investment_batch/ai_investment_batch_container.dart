import 'package:flutter/material.dart';

import 'application/ai_investment_controller.dart';
import 'data/supabase_ai_investment_repository.dart';
import 'domain/ai_investment_models.dart';
import 'presentation/ai_investment_batch_view.dart';

/// Stateful container for 2026Q2 AI investment batch admin UI (#2761).
class AiInvestmentBatchContainer extends StatefulWidget {
  const AiInvestmentBatchContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final AiInvestmentRepository? repository;
  final AiInvestmentController? controller;

  @override
  State<AiInvestmentBatchContainer> createState() =>
      _AiInvestmentBatchContainerState();
}

class _AiInvestmentBatchContainerState
    extends State<AiInvestmentBatchContainer> {
  late final AiInvestmentController _controller;
  late final bool _ownsController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _verificationNoteController =
      TextEditingController();
  final TextEditingController _rawPayloadController = TextEditingController();
  final TextEditingController _ingestSourceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiInvestmentController(
          repository: widget.repository ?? SupabaseAiInvestmentRepository(),
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
    _searchController.dispose();
    _verificationNoteController.dispose();
    _rawPayloadController.dispose();
    _ingestSourceController.dispose();
    super.dispose();
  }

  void _insertSamplePayload() {
    _ingestSourceController.text = '公式発表サンプル形式';
    _rawPayloadController.text =
        '{"company_name":"Sample Inference Inc","round_stage":"Series A",'
        '"amount_display":"要一次確認","announced_at":"2026-05-18T00:00:00Z",'
        '"source_url":"https://example.com/press-release",'
        '"summary":"テスト取込サンプル（登録時は常に要検証）"}';
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return AiInvestmentBatchView(
          state: _controller.state,
          searchController: _searchController,
          verificationNoteController: _verificationNoteController,
          rawPayloadController: _rawPayloadController,
          ingestSourceController: _ingestSourceController,
          onRefresh: () => _controller.loadRecords(
            searchQuery: _searchController.text,
          ),
          onSearchSubmit: () => _controller.loadRecords(
            searchQuery: _searchController.text,
          ),
          onFilterChanged: _controller.setStatusFilter,
          onSelectRecord: (final String id) {
            _verificationNoteController.clear();
            _controller.selectRecord(id);
          },
          onSeedDefaults: _controller.seedDefaults,
          onVerifyDecision: (
            final InvestmentVerificationStatus decision,
          ) async {
            final ok = await _controller.verifySelected(
              decision: decision,
              note: _verificationNoteController.text,
            );
            if (ok && mounted) {
              _verificationNoteController.clear();
            }
          },
          onInsertSamplePayload: _insertSamplePayload,
          onIngestSubmit: () async {
            final ok = await _controller.ingestRawPayload(
              rawPayload: _rawPayloadController.text,
              sourceName: _ingestSourceController.text,
            );
            if (ok && mounted) {
              _rawPayloadController.clear();
              _ingestSourceController.clear();
            }
          },
        );
      },
    );
  }
}
