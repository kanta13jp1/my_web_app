import 'package:flutter/material.dart';

class HomeFixedFeature {
  final String route;
  final String label;
  final IconData icon;
  final Color color;

  const HomeFixedFeature({
    required this.route,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<HomeFixedFeature> kHomeSystemFixed = [
  HomeFixedFeature(
    route: '/site-guide-ai',
    label: 'サイト案内AI',
    icon: Icons.support_agent_outlined,
    color: Color(0xFF4F46E5),
  ),
  HomeFixedFeature(
    route: '/ai-secretary',
    label: 'AI秘書',
    icon: Icons.smart_toy_outlined,
    color: Color(0xFF6366F1),
  ),
  HomeFixedFeature(
    route: '/daily-judgment',
    label: 'デイリー判定',
    icon: Icons.today_outlined,
    color: Color(0xFFFF6B35),
  ),
  HomeFixedFeature(
    route: '/note-list',
    label: 'ノート',
    icon: Icons.note_outlined,
    color: Color(0xFF0D9488),
  ),
  HomeFixedFeature(
    route: '/ai-university',
    label: 'AI大学',
    icon: Icons.school_outlined,
    color: Color(0xFF6366F1),
  ),
  HomeFixedFeature(
    route: '/release-notes',
    label: 'Release Notes',
    icon: Icons.new_releases_outlined,
    color: Color(0xFF0D9488),
  ),
];
