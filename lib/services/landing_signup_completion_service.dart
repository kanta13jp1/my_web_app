import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'growth_acquisition_service.dart';
import 'landing_conversion_analytics.dart';
import 'landing_conversion_experiment_service.dart';
import 'landing_page_adapter.dart';

class PendingLandingSignup {
  const PendingLandingSignup({
    required this.email,
    required this.eventKey,
    required this.visitorId,
    required this.createdAt,
  });

  final String? email;
  final String eventKey;
  final String visitorId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 1,
        'email': email,
        'event_key': eventKey,
        'visitor_id': visitorId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static PendingLandingSignup? fromJson(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    if (data['version'] != 1) return null;

    final normalizedEmail = data['email']?.toString().trim().toLowerCase();
    final eventKey = data['event_key']?.toString().trim() ?? '';
    final visitorId = data['visitor_id']?.toString().trim().toLowerCase() ?? '';
    final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '');
    if ((normalizedEmail != null &&
            normalizedEmail.isNotEmpty &&
            !normalizedEmail.contains('@')) ||
        !LandingConversionExperimentService.isExperimentEventKey(eventKey) ||
        !eventKey.endsWith('_signup_complete') ||
        !LandingConversionExperimentService.isValidVisitorId(visitorId) ||
        createdAt == null) {
      return null;
    }

    return PendingLandingSignup(
      email: normalizedEmail == null || normalizedEmail.isEmpty
          ? null
          : normalizedEmail,
      eventKey: eventKey,
      visitorId: visitorId,
      createdAt: createdAt.toUtc(),
    );
  }
}

/// Carries an LP signup intent across external auth redirects.
///
/// The authenticated route can be selected before [LandingPage] mounts, so
/// signup completion cannot depend on the LP auth listener alone. This service
/// stores only attribution metadata and consumes it after authentication.
class LandingSignupCompletionService {
  const LandingSignupCompletionService({
    this.ttl = const Duration(hours: 48),
    LandingPageAdapter? landingPageAdapter,
    LandingConversionAnalytics? conversionAnalytics,
    GrowthAcquisitionService? acquisitionService,
    DateTime Function()? clock,
  })  : _landingPageAdapter =
            landingPageAdapter ?? const SupabaseLandingPageAdapter(),
        _conversionAnalytics =
            conversionAnalytics ?? const PostHogLandingConversionAnalytics(),
        _acquisitionService =
            acquisitionService ?? const GrowthAcquisitionService(),
        _clock = clock;

  static const String storageKey = 'pending_landing_signup_v1';
  static const Duration _accountCreationClockSkew = Duration(minutes: 5);
  static final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  final Duration ttl;
  final LandingPageAdapter _landingPageAdapter;
  final LandingConversionAnalytics _conversionAnalytics;
  final GrowthAcquisitionService _acquisitionService;
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  Future<void> markPending({
    required String eventKey,
    required String visitorId,
    String? email,
    SharedPreferences? preferences,
  }) async {
    final pending = PendingLandingSignup(
      email: _normalizeEmail(email),
      eventKey: eventKey.trim(),
      visitorId: visitorId.trim().toLowerCase(),
      createdAt: _now(),
    );
    if (PendingLandingSignup.fromJson(pending.toJson()) == null) {
      throw ArgumentError('Pending landing signup attribution is invalid.');
    }

    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(pending.toJson()));
  }

  Future<bool> cancelPending({
    String? email,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final pending = await _readValid(prefs);
    if (pending == null) return false;

    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail != null && pending.email != normalizedEmail) {
      return false;
    }
    return _removeIfCurrent(prefs, pending);
  }

  Future<bool> completeIfPending({
    required String? signupUserId,
    String? signupEmail,
    DateTime? accountCreatedAt,
    SharedPreferences? preferences,
  }) async {
    try {
      final userId = signupUserId?.trim() ?? '';
      if (userId.isEmpty) return false;

      final prefs = preferences ?? await SharedPreferences.getInstance();
      final pending = await _readValid(prefs);
      if (pending == null) return false;

      final normalizedSignupEmail = _normalizeEmail(signupEmail);
      if (pending.email != null && pending.email != normalizedSignupEmail) {
        return false;
      }

      final createdAt = accountCreatedAt?.toUtc();
      if (createdAt != null &&
          createdAt.isBefore(
            pending.createdAt.subtract(_accountCreationClockSkew),
          )) {
        await _removeIfCurrent(prefs, pending);
        return false;
      }

      final operationKey = '$userId:${pending.visitorId}:${pending.eventKey}';
      final existing = _inFlight[operationKey];
      if (existing != null) return existing;

      final operation = _complete(
        prefs: prefs,
        pending: pending,
        signupUserId: userId,
      );
      _inFlight[operationKey] = operation;
      unawaited(
        operation.whenComplete(() {
          if (identical(_inFlight[operationKey], operation)) {
            _inFlight.remove(operationKey);
          }
        }),
      );
      return operation;
    } catch (error, stackTrace) {
      debugPrint('Landing signup completion bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _complete({
    required SharedPreferences prefs,
    required PendingLandingSignup pending,
    required String signupUserId,
  }) async {
    try {
      await _landingPageAdapter.recordConversionEvent(
        eventKey: pending.eventKey,
        visitorId: pending.visitorId,
      );
      unawaited(
        _conversionAnalytics.captureExperimentEvent(
          eventKey: pending.eventKey,
        ),
      );
      try {
        await _acquisitionService.recordFirstUserFunnelStage(
          stage: 'signup_complete',
          visitorId: pending.visitorId,
        );
      } catch (error, stackTrace) {
        debugPrint('First-user signup completion signal failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      await _acquisitionService.notifySignupSuccess(signupUserId: signupUserId);
      await _removeIfCurrent(prefs, pending);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Landing signup completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<PendingLandingSignup?> _readValid(SharedPreferences prefs) async {
    final encoded = prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return null;

    PendingLandingSignup? pending;
    try {
      pending = PendingLandingSignup.fromJson(jsonDecode(encoded));
    } catch (_) {
      pending = null;
    }
    if (pending == null || _now().difference(pending.createdAt) >= ttl) {
      await prefs.remove(storageKey);
      return null;
    }
    return pending;
  }

  Future<bool> _removeIfCurrent(
    SharedPreferences prefs,
    PendingLandingSignup pending,
  ) async {
    final encoded = prefs.getString(storageKey);
    if (encoded == null) return false;

    PendingLandingSignup? current;
    try {
      current = PendingLandingSignup.fromJson(jsonDecode(encoded));
    } catch (_) {
      current = null;
    }
    if (current == null ||
        current.eventKey != pending.eventKey ||
        current.visitorId != pending.visitorId ||
        current.createdAt != pending.createdAt) {
      return false;
    }
    return prefs.remove(storageKey);
  }

  static String? _normalizeEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    return email.isEmpty ? null : email;
  }
}
