import 'package:flutter/material.dart';
import '../../data/home_system_fixed.dart';
import '../../utils/home_feature_actions.dart';

class SystemFixedFeaturesList extends StatelessWidget {
  const SystemFixedFeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kHomeSystemFixed.map((f) {
          return GestureDetector(
            onLongPress: () => pinHomeFeature(context, f.route, f.label),
            child: ActionChip(
              avatar: Icon(f.icon, size: 16, color: f.color),
              label: Text(
                f.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE2E8F0),
                  height: 1.5,
                ),
              ),
              backgroundColor: const Color(0xFF1A1A1A),
              side: BorderSide(color: f.color.withValues(alpha: 0.3)),
              onPressed: () => openHomeFeature(context, f.route, f.label),
            ),
          );
        }).toList(),
      ),
    );
  }
}
