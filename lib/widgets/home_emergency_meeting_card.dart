import 'package:flutter/material.dart';

class HomeEmergencyMeetingCard extends StatelessWidget {
  const HomeEmergencyMeetingCard({
    super.key,
    required this.onTap,
    this.isVisible = true,
  });

  static const cardKey = Key('home_emergency_meeting_card');

  final VoidCallback onTap;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return Container(
      key: cardKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor,
            Color.alphaBlend(
              const Color(0xFFE53935).withValues(alpha: isDark ? 0.16 : 0.07),
              baseColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4CE53935)),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFFE53935).withValues(alpha: isDark ? 0.16 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE53935),
          radius: 26,
          child: Icon(Icons.emergency, color: Colors.white, size: 28),
        ),
        title: const Text(
          '緊急役員会議',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        subtitle: const Text('CEOとして全AI役員を招集し、直面している課題を解決します。'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
