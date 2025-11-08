import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/presence_service.dart';

class LiveStatsBanner extends StatefulWidget {
  const LiveStatsBanner({super.key});

  @override
  State<LiveStatsBanner> createState() => _LiveStatsBannerState();
}

class _LiveStatsBannerState extends State<LiveStatsBanner> {
  final _supabase = Supabase.instance.client;
  late PresenceService _presenceService;
  Timer? _updateTimer;

  int _totalUsers = 0;
  int _onlineUsers = 0;
  int _totalNotes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(_supabase);
    _loadStats();
    _startAutoUpdate();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _presenceService.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _presenceService.getSiteStatistics();
      final onlineUsers = await _presenceService.getOnlineUsersCount();
      final onlineGuests = await _presenceService.getOnlineGuestsCount();

      if (mounted) {
        setState(() {
          _totalUsers = stats?.totalUsers ?? 0;
          _onlineUsers = onlineUsers + onlineGuests;
          _totalNotes = stats?.totalNotesCreated ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startAutoUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 80);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'リアルタイム統計',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.people,
                _totalUsers.toString(),
                '総ユーザー',
              ),
              _buildDivider(),
              _buildStatItem(
                Icons.circle,
                _onlineUsers.toString(),
                'オンライン',
                color: Colors.greenAccent,
              ),
              _buildDivider(),
              _buildStatItem(
                Icons.note,
                _totalNotes.toString(),
                '総メモ数',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Colors.white,
          size: 24,
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<int>(
          key: ValueKey('$label-$value'),
          tween: IntTween(
            begin: int.tryParse(value) ?? 0,
            end: int.tryParse(value) ?? 0,
          ),
          duration: const Duration(milliseconds: 500),
          builder: (context, animatedValue, child) {
            return Text(
              animatedValue.toString(),
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 60,
      color: Colors.white.withOpacity(0.2),
    );
  }
}
