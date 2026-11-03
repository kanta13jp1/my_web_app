import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A detached, single-isolate prototype. Not wired into the product.
///
/// The owner-scoped snapshot and pending marker share one preference value.
/// It does not implement a cross-tab lock, migration of existing unscoped
/// values, an authenticated sender, or a server-side compare-and-swap.
class AssetPaymentDayOwnerStoreCandidate {
  AssetPaymentDayOwnerStoreCandidate(
      this.prefs, this.isCurrentOwner, this.currentSessionIdentity,
      {this.testWrite});

  static const storageKey = 'synthetic_payment_day_owner_state_v1';
  static Future<void> _tail = Future<void>.value();
  static bool _writeUncertain = false;
  final SharedPreferences prefs;
  final bool Function(String ownerId) isCurrentOwner;
  /// Must synchronously return a non-reused opaque identity for a session.
  /// The real auth adapter and its identity semantics are not implemented.
  final Object? Function() currentSessionIdentity;
  /// Synthetic failure injection only; not a production adapter.
  final Future<bool> Function(String key, String value)? testWrite;

  /// Tests only; never reset while any operation remains in flight.
  static void resetForTest() {
    _tail = Future<void>.value();
    _writeUncertain = false;
  }

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  void _checkOwner(String owner, Object session) {
    if (_writeUncertain || owner.isEmpty || !isCurrentOwner(owner) ||
        !identical(currentSessionIdentity(), session)) {
      throw StateError('Current owner changed');
    }
  }

  Future<T> _withSession<T>(String owner, Future<T> Function(Object session) action) {
    final session = currentSessionIdentity();
    if (_writeUncertain || session == null || owner.isEmpty || !isCurrentOwner(owner)) {
      return Future<T>.error(StateError('Current owner changed'));
    }
    return _locked(() => action(session));
  }

  Map<String, dynamic> _load() {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {'version': 1, 'owners': <String, dynamic>{}};
    final decoded = jsonDecode(raw);
    // Only our own deterministic encoding is accepted. This rejects duplicate
    // keys and any other non-canonical representation instead of allowing the
    // JSON decoder to silently discard an earlier pending marker.
    if (jsonEncode(decoded) != raw) throw const FormatException('Noncanonical owner state');
    if (decoded is! Map || decoded.keys.toSet().difference({'version', 'owners'}).isNotEmpty ||
        decoded.length != 2 || decoded['version'] != 1 || decoded['owners'] is! Map) {
      throw const FormatException('Invalid owner state');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _owner(Map<String, dynamic> root, String owner) {
    final owners = Map<String, dynamic>.from(root['owners'] as Map);
    root['owners'] = owners;
    if (!owners.containsKey(owner)) {
      final created = <String, dynamic>{'revision': 0, 'sequence': 0,
        'values': <String, int>{}, 'deleted': <String>[],
        'dirty': false, 'pending': null};
      owners[owner] = created;
      return created;
    }
    final raw = owners[owner];
    const required = {'revision', 'sequence', 'values', 'deleted', 'dirty', 'pending'};
    if (raw is! Map || raw.length != required.length ||
        raw.keys.toSet().difference(required).isNotEmpty ||
        raw['revision'] is! int || (raw['revision'] as int) < 0 ||
        raw['sequence'] is! int || (raw['sequence'] as int) < 0 ||
        raw['values'] is! Map || raw['deleted'] is! List || raw['dirty'] is! bool ||
        (raw['pending'] != null && raw['pending'] is! Map)) {
      throw const FormatException('Invalid owner entry');
    }
    final state = Map<String, dynamic>.from(raw);
    final values = Map<String, dynamic>.from(state['values'] as Map);
    if (values.entries.any((e) => e.key.isEmpty || e.value is! int ||
        (e.value as int) < 1 || (e.value as int) > 31)) {
      throw const FormatException('Invalid day');
    }
    if ((state['deleted'] as List).any((e) => e is! String || e.isEmpty)) {
      throw const FormatException('Invalid deletion');
    }
    final deleted = List<String>.from(state['deleted'] as List);
    if (deleted.toSet().length != deleted.length || deleted.any(values.containsKey)) {
      throw const FormatException('Inconsistent deletion');
    }
    final pending = state['pending'];
    if (pending != null && (pending is! Map || pending.length != 5 ||
        pending.keys.toSet().difference({'sequence', 'revision', 'nonce', 'values', 'deleted'}).isNotEmpty ||
        pending['values'] is! Map || pending['deleted'] is! List ||
        pending['sequence'] is! int || pending['sequence'] != state['sequence'] || pending['sequence'] == 0 ||
        pending['revision'] is! int || (pending['revision'] as int) < 1 ||
        (pending['revision'] as int) > (state['revision'] as int) || state['dirty'] != true ||
        pending['nonce'] is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(pending['nonce'] as String))) {
      throw const FormatException('Invalid pending state');
    }
    if (pending != null) {
      final pendingValues = Map<String, dynamic>.from(pending['values'] as Map);
      final pendingDeletedRaw = pending['deleted'] as List;
      if (pendingValues.entries.any((e) => e.key.isEmpty || e.value is! int ||
          (e.value as int) < 1 || (e.value as int) > 31) ||
          pendingDeletedRaw.any((e) => e is! String || e.isEmpty)) {
        throw const FormatException('Invalid pending snapshot');
      }
      final pendingDeleted = List<String>.from(pendingDeletedRaw);
      if (pendingDeleted.toSet().length != pendingDeleted.length ||
          pendingDeleted.any(pendingValues.containsKey)) {
        throw const FormatException('Inconsistent pending snapshot');
      }
      if (pending['revision'] == state['revision'] &&
          (pendingValues.length != values.length ||
           pendingValues.entries.any((e) => values[e.key] != e.value) ||
           pendingDeleted.length != deleted.length ||
           pendingDeleted.toSet().difference(deleted.toSet()).isNotEmpty)) {
        throw const FormatException('Pending snapshot differs at same revision');
      }
    }
    state['values'] = values;
    state['deleted'] = deleted;
    owners[owner] = state;
    return state;
  }

  Future<void> _write(Map<String, dynamic> root) async {
    try {
      final writer = testWrite ?? prefs.setString;
      if (!await writer(storageKey, jsonEncode(root))) {
        throw StateError('Owner state write failed');
      }
    } catch (_) {
      // The adapter may have persisted despite throwing. Block all instances
      // in this isolate. This does not survive process/isolate restart.
      _writeUncertain = true;
      rethrow;
    }
  }

  /// Persist one owner-scoped edit; null records a tombstone.
  Future<void> edit(String owner, String key, int? day) => _withSession(owner, (session) async {
    _checkOwner(owner, session);
    if (key.isEmpty || (day != null && (day < 1 || day > 31))) {
      throw ArgumentError('Invalid synthetic payment-day edit');
    }
    final root = _load();
    final state = _owner(root, owner);
    final values = Map<String, dynamic>.from(state['values'] as Map);
    final deleted = Set<String>.from(state['deleted'] as List);
    if (day == null) { values.remove(key); deleted.add(key); }
    else { values[key] = day; deleted.remove(key); }
    state['values'] = values;
    state['deleted'] = deleted.toList()..sort();
    state['revision'] = (state['revision'] as int) + 1;
    state['dirty'] = true;
    _checkOwner(owner, session);
    await _write(root);
    _checkOwner(owner, session);
  });

  /// Write a durable pending marker *before* any caller sends data.
  Future<PaymentDayOwnerTicket?> begin(String owner) => _withSession(owner, (session) async {
    _checkOwner(owner, session);
    final root = _load();
    final state = _owner(root, owner);
    if (state['pending'] != null) throw StateError('Prior result is unresolved');
    if (state['dirty'] != true) return null;
    final sequence = (state['sequence'] as int) + 1;
    final revision = state['revision'] as int;
    final random = Random.secure();
    final nonce = List.generate(16, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    state['sequence'] = sequence;
    final snapshotValues = Map<String, int>.from(state['values'] as Map);
    final snapshotDeleted = List<String>.from(state['deleted'] as List);
    state['pending'] = {'sequence': sequence, 'revision': revision, 'nonce': nonce,
      'values': snapshotValues, 'deleted': snapshotDeleted};
    final ticket = PaymentDayOwnerTicket._(owner, sequence, revision, nonce, session,
      snapshotValues, snapshotDeleted);
    _checkOwner(owner, session);
    await _write(root);
    // If auth changed while persistence waited, do not send. The durable
    // marker remains pending and requires an independently verified recovery.
    _checkOwner(owner, session);
    return ticket;
  });

  /// Caller must independently prove both the snapshot and tombstone writes
  /// committed; this method does not implement or verify such a receipt.
  Future<void> acknowledgeConfirmed(PaymentDayOwnerTicket ticket) => _locked(() async {
    _checkOwner(ticket.owner, ticket.sessionIdentity);
    final root = _load();
    final state = _owner(root, ticket.owner);
    final pending = state['pending'];
    if (pending is! Map || pending['sequence'] != ticket.sequence ||
        pending['revision'] != ticket.revision || pending['nonce'] != ticket.nonce) {
      throw StateError('Pending ticket differs');
    }
    final pendingValues = Map<String, dynamic>.from(pending['values'] as Map);
    final pendingDeleted = List<String>.from(pending['deleted'] as List);
    if (pendingValues.length != ticket.values.length ||
        pendingValues.entries.any((e) => ticket.values[e.key] != e.value) ||
        pendingDeleted.length != ticket.deleted.length ||
        pendingDeleted.toSet().difference(ticket.deleted.toSet()).isNotEmpty) {
      throw StateError('Pending ticket payload differs');
    }
    state['pending'] = null;
    if (state['revision'] == ticket.revision) state['dirty'] = false;
    _checkOwner(ticket.owner, ticket.sessionIdentity);
    await _write(root);
    _checkOwner(ticket.owner, ticket.sessionIdentity);
  });

  Future<Map<String, dynamic>> inspect(String owner) => _withSession(owner, (session) async {
    _checkOwner(owner, session);
    final state = _owner(_load(), owner);
    return jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  });
}

class PaymentDayOwnerTicket {
  PaymentDayOwnerTicket._(this.owner, this.sequence, this.revision, this.nonce, this.sessionIdentity,
      Map<String, int> values, List<String> deleted)
      : values = Map.unmodifiable(values), deleted = List.unmodifiable(deleted);
  final String owner;
  final int sequence;
  final int revision;
  final String nonce;
  final Object sessionIdentity;
  final Map<String, int> values;
  final List<String> deleted;
}
