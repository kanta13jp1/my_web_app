import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_presence.dart';
import '../models/site_statistics.dart';
import '../utils/app_logger.dart';

class PresenceService {
  final SupabaseClient _supabase;
  Timer? _heartbeatTimer;
  String? _sessionId;

  PresenceService(this._supabase) {
    _sessionId = _generateSessionId();
  }

  // Generate a unique session ID
  String _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    return '$timestamp-$randomNum';
  }

  // Start presence tracking for authenticated user
  Future<void> startPresenceTracking(String userId, {String? pagePath}) async {
    try {
      AppLogger.info('Starting presence tracking for user: $userId');

      // Insert or update presence
      await _supabase.from('user_presence').upsert({
        'user_id': userId,
        'session_id': _sessionId,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'page_path': pagePath,
      });

      // Start heartbeat timer (update every 2 minutes)
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _updatePresence(userId, pagePath: pagePath),
      );

      AppLogger.info('Presence tracking started successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to start presence tracking', e, stackTrace);
    }
  }

  // Start guest presence tracking
  Future<void> startGuestPresenceTracking({String? pagePath}) async {
    try {
      AppLogger.info('Starting guest presence tracking');

      // Insert or update guest presence
      await _supabase.from('guest_presence').upsert({
        'session_id': _sessionId,
        'last_seen': DateTime.now().toIso8601String(),
        'page_path': pagePath,
      });

      // Start heartbeat timer
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _updateGuestPresence(pagePath: pagePath),
      );

      AppLogger.info('Guest presence tracking started successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to start guest presence tracking', e, stackTrace);
    }
  }

  // Update presence (heartbeat)
  Future<void> _updatePresence(String userId, {String? pagePath}) async {
    try {
      await _supabase.from('user_presence').upsert({
        'user_id': userId,
        'session_id': _sessionId,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'page_path': pagePath,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update presence', e, stackTrace);
    }
  }

  // Update guest presence (heartbeat)
  Future<void> _updateGuestPresence({String? pagePath}) async {
    try {
      await _supabase.from('guest_presence').upsert({
        'session_id': _sessionId,
        'last_seen': DateTime.now().toIso8601String(),
        'page_path': pagePath,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update guest presence', e, stackTrace);
    }
  }

  // Stop presence tracking
  Future<void> stopPresenceTracking(String? userId) async {
    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      if (userId != null) {
        // Mark user as offline
        await _supabase
            .from('user_presence')
            .update({
              'is_online': false,
              'last_seen': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('session_id', _sessionId!);
      } else {
        // Delete guest presence
        await _supabase
            .from('guest_presence')
            .delete()
            .eq('session_id', _sessionId!);
      }

      AppLogger.info('Presence tracking stopped');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to stop presence tracking', e, stackTrace);
    }
  }

  // Get online users count
  Future<int> getOnlineUsersCount() async {
    try {
      final response = await _supabase
          .from('user_presence')
          .select('id')
          .eq('is_online', true)
          .gte('last_seen',
               DateTime.now().subtract(const Duration(minutes: 5))
                   .toIso8601String());

      return (response as List).length;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get online users count', e, stackTrace);
      return 0;
    }
  }

  // Get online guests count
  Future<int> getOnlineGuestsCount() async {
    try {
      final response = await _supabase
          .from('guest_presence')
          .select('id')
          .gte('last_seen',
               DateTime.now().subtract(const Duration(minutes: 5))
                   .toIso8601String());

      return (response as List).length;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get online guests count', e, stackTrace);
      return 0;
    }
  }

  // Get total online count (users + guests)
  Future<int> getTotalOnlineCount() async {
    final usersCount = await getOnlineUsersCount();
    final guestsCount = await getOnlineGuestsCount();
    return usersCount + guestsCount;
  }

  // Get site statistics
  Future<SiteStatistics?> getSiteStatistics() async {
    try {
      final response = await _supabase
          .from('site_statistics')
          .select()
          .order('stat_date', ascending: false)
          .limit(1)
          .single();

      return SiteStatistics.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get site statistics', e, stackTrace);
      return null;
    }
  }

  // Update site statistics
  Future<void> updateSiteStatistics() async {
    try {
      await _supabase.rpc('update_site_statistics');
      AppLogger.info('Site statistics updated successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update site statistics', e, stackTrace);
    }
  }

  // Clean up old presence records
  Future<void> cleanupOldPresence() async {
    try {
      await _supabase.rpc('cleanup_old_presence');
      AppLogger.info('Old presence records cleaned up');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to cleanup old presence', e, stackTrace);
    }
  }

  // Stream online users count (real-time updates)
  Stream<int> watchOnlineUsersCount() {
    return Stream.periodic(const Duration(seconds: 10), (_) async {
      return await getOnlineUsersCount();
    }).asyncMap((event) => event);
  }

  // Stream total online count (real-time updates)
  Stream<int> watchTotalOnlineCount() {
    return Stream.periodic(const Duration(seconds: 10), (_) async {
      return await getTotalOnlineCount();
    }).asyncMap((event) => event);
  }

  // Dispose resources
  void dispose() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
