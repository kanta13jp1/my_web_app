import 'package:flutter/foundation.dart';
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
  const SupabaseActivationRevenueEventTracker({
    this.clientOverride,
    this.uniqueEventRecorderOverride,
  });

  final SupabaseClient? clientOverride;
  final Future<void> Function(String eventKey)? uniqueEventRecorderOverride;

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
  }) async {
    final eventKey = assignment.eventKey(stage);
    final client = _client;
    await LandingShareService.recordFunnelEvent(
      eventKey: eventKey,
      client: client,
    );

    try {
      final override = uniqueEventRecorderOverride;
      if (override != null) {
        await override(eventKey);
        return;
      }
      if (client == null) {
        return;
      }
      await client.rpc(
        'record_activation_experiment_event',
        params: <String, dynamic>{'p_event_key': eventKey},
      );
    } catch (error) {
      debugPrint('Unique activation experiment event failed: $error');
    }
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
