import 'package:flutter/material.dart';
import '../../data/home_system_fixed.dart';
import '../../utils/home_feature_actions.dart';
import 'home_tier_styles.dart';

class SystemFixedFeaturesList extends StatelessWidget {
  const SystemFixedFeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = HomeTierPalette.of(context);
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
                style: TextStyle(
                  fontSize: 12,
                  color: palette.primaryText,
                  height: 1.5,
                ),
              ),
              backgroundColor: palette.chipBackground,
              side: BorderSide(color: f.color.withValues(alpha: 0.3)),
              onPressed: () => openHomeFeature(context, f.route, f.label),
            ),
          );
        }).toList(),
      ),
    );
  }
}
