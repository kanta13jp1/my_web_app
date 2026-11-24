import 'package:flutter/material.dart';

import 'application/ai_action_budget_controller.dart';
import 'data/supabase_ai_action_budget_repository.dart';
import 'domain/ai_action_budget_models.dart';
import 'presentation/ai_action_budget_view.dart';

/// AiActionBudgetController と View・入力コントローラを接続する Container (#2609).
class AiActionBudgetContainer extends StatefulWidget {
  const AiActionBudgetContainer({
    super.key,
    this.repository,
    this.controller,
    this.billingMonth = '2026-11',
  });

  final AiActionBudgetRepository? repository;
  final AiActionBudgetController? controller;
  final String billingMonth;

  @override
  State<AiActionBudgetContainer> createState() =>
      _AiActionBudgetContainerState();
}

class _AiActionBudgetContainerState extends State<AiActionBudgetContainer> {
  late AiActionBudgetController _controller;
  late bool _ownsController;
  final TextEditingController _capController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initController();
    _capController.text = _controller.state.config.monthlyUsdCap.toString();
    Future<void>.microtask(_loadInitial);
  }

  void _initController() {
    final provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ??
        AiActionBudgetController(
          repository: widget.repository ?? SupabaseAiActionBudgetRepository(),
          billingMonth: widget.billingMonth,
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadSnapshot();
    if (mounted && !_controller.isDisposed) {
      _capController.text = _controller.state.config.monthlyUsdCap.toString();
    }
  }

  @override
  void didUpdateWidget(covariant AiActionBudgetContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.repository != oldWidget.repository ||
        widget.billingMonth != oldWidget.billingMonth) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      Future<void>.microtask(_loadInitial);
    }
  }

  @override
  void dispose() {
    _capController.dispose();
    _actionController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleUpdateCap() {
    _controller.updateMonthlyCap(rawCapUsd: _capController.text);
  }

  void _handleResumeBudget() {
    _controller.resumeBudget();
  }

  void _handleRecordUsage() {
    _controller.recordUsage(actionName: _actionController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return AiActionBudgetView(
          state: _controller.state,
          capController: _capController,
          actionController: _actionController,
          onRetryLoad: _loadInitial,
          onUpdateCap: _handleUpdateCap,
          onResumeBudget: _handleResumeBudget,
          onRecordUsage: _handleRecordUsage,
        );
      },
    );
  }
}
