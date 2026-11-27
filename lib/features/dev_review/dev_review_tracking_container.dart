import 'dart:async';

import 'package:flutter/material.dart';

import 'application/dev_review_controller.dart';
import 'data/supabase_dev_review_repository.dart';
import 'domain/dev_review_models.dart';
import 'presentation/dev_review_tracking_view.dart';

class DevReviewTrackingContainer extends StatefulWidget {
  const DevReviewTrackingContainer({
    super.key,
    this.repository,
  });

  final DevReviewTrackingRepository? repository;

  @override
  State<DevReviewTrackingContainer> createState() =>
      _DevReviewTrackingContainerState();
}

class _DevReviewTrackingContainerState
    extends State<DevReviewTrackingContainer> {
  late final DevReviewTrackingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = DevReviewTrackingController(
      repository: widget.repository ?? SupabaseDevReviewTrackingRepository(),
    );
    unawaited(_ctrl.loadSessions());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevReviewTrackingView(controller: _ctrl);
  }
}
