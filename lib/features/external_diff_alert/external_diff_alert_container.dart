import 'dart:async';

import 'package:flutter/material.dart';

import 'application/external_diff_alert_controller.dart';
import 'data/supabase_external_diff_alert_repository.dart';
import 'domain/external_diff_alert_models.dart';
import 'presentation/external_diff_alert_view.dart';

class ExternalDiffAlertContainer extends StatefulWidget {
  const ExternalDiffAlertContainer({
    super.key,
    this.repository,
  });

  final ExternalDiffAlertRepository? repository;

  @override
  State<ExternalDiffAlertContainer> createState() =>
      _ExternalDiffAlertContainerState();
}

class _ExternalDiffAlertContainerState
    extends State<ExternalDiffAlertContainer> {
  late final ExternalDiffAlertController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ExternalDiffAlertController(
      repository: widget.repository ?? SupabaseExternalDiffAlertRepository(),
    );
    unawaited(_ctrl.loadDashboard());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExternalDiffAlertView(controller: _ctrl);
  }
}
