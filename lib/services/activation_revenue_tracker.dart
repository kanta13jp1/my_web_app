import 'package:supabase_flutter/supabase_flutter.dart';

import 'activation_revenue_experiment_service.dart';
import 'landing_share_service.dart';

abstract interface class ActivationRevenueEventTracker {
  Future<void> record({
    required ActivationRevenueAssignment assignment,
    required String stage,
  });
}

class SupabaseActivationRevenueEventTracker
    implements ActivationRevenueEventTracker {
  const SupabaseActivationRevenueEventTracker({this.clientOverride});

  final SupabaseClient? clientOverride;

  SupabaseClient? get _client {
    if (clientOverride != null) return clientOverride;
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> record({
    required ActivationRevenueAssignment assignment,
    required String stage,
  }) {
    return LandingShareService.recordFunnelEvent(
      eventKey: assignment.eventKey(stage),
      client: _client,
    );
  }
}

class NoopActivationRevenueEventTracker
    implements ActivationRevenueEventTracker {
  const NoopActivationRevenueEventTracker();

  @override
  Future<void> record({
    required ActivationRevenueAssignment assignment,
    required String stage,
  }) async {}
}
