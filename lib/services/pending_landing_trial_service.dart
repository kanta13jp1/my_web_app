import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingLandingTrial {
  const PendingLandingTrial({
    required this.email,
    required this.intent,
    required this.prompt,
    required this.action,
    required this.reason,
    required this.createdAt,
  });

  final String email;
  final String intent;
  final String prompt;
  final String action;
  final String reason;
  final DateTime createdAt;

  Map<String, Object> toJson() => <String, Object>{
    'version': 1,
    'email': email,
    'intent': intent,
    'prompt': prompt,
    'action': action,
    'reason': reason,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static PendingLandingTrial? fromJson(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    if (data['version'] != 1) return null;

    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    final intent = data['intent']?.toString().trim() ?? '';
    final prompt = data['prompt']?.toString().trim() ?? '';
    final action = data['action']?.toString().trim() ?? '';
    final reason = data['reason']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '');
    if (email.isEmpty ||
        !email.contains('@') ||
        !_supportedIntents.contains(intent) ||
        prompt.isEmpty ||
        action.isEmpty ||
        reason.isEmpty ||
        createdAt == null) {
      return null;
    }

    return PendingLandingTrial(
      email: email,
      intent: intent,
      prompt: prompt,
      action: action,
      reason: reason,
      createdAt: createdAt.toUtc(),
    );
  }

  static const Set<String> _supportedIntents = <String>{
    'work',
    'learning',
    'money',
  };
}

/// Keeps the anonymous LP result long enough to survive the Magic Link round trip.
///
/// The payload stays in browser-local storage and is released only to an
/// authenticated user whose normalized email matches the address used to send
/// the link.
class PendingLandingTrialService {
  const PendingLandingTrialService({
    this.ttl = const Duration(hours: 24),
    DateTime Function()? clock,
  }) : _clock = clock;

  static const String storageKey = 'pending_landing_trial_v1';

  final Duration ttl;
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  Future<void> save({
    required String email,
    required String intent,
    required String prompt,
    required String action,
    required String reason,
    SharedPreferences? preferences,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trial = PendingLandingTrial(
      email: normalizedEmail,
      intent: intent.trim(),
      prompt: prompt.trim(),
      action: action.trim(),
      reason: reason.trim(),
      createdAt: _now(),
    );
    if (PendingLandingTrial.fromJson(trial.toJson()) == null) {
      throw ArgumentError('Pending landing trial fields are incomplete.');
    }

    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(trial.toJson()));
  }

  Future<PendingLandingTrial?> loadForEmail(
    String? email, {
    SharedPreferences? preferences,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    if (normalizedEmail.isEmpty) return null;

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final trial = await _readValid(prefs);
    if (trial == null || trial.email != normalizedEmail) return null;
    return trial;
  }

  Future<bool> clearForEmail(
    String? email, {
    SharedPreferences? preferences,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    if (normalizedEmail.isEmpty) return false;

    final prefs = preferences ?? await SharedPreferences.getInstance();
    final trial = await _readValid(prefs);
    if (trial == null || trial.email != normalizedEmail) return false;
    return prefs.remove(storageKey);
  }

  Future<PendingLandingTrial?> _readValid(SharedPreferences prefs) async {
    final encoded = prefs.getString(storageKey);
    if (encoded == null || encoded.isEmpty) return null;

    PendingLandingTrial? trial;
    try {
      trial = PendingLandingTrial.fromJson(jsonDecode(encoded));
    } catch (_) {
      trial = null;
    }
    if (trial == null || _now().difference(trial.createdAt) >= ttl) {
      await prefs.remove(storageKey);
      return null;
    }
    return trial;
  }
}
