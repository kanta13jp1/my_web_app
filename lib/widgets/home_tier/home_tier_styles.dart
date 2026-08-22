import 'package:flutter/material.dart';

/// Theme-aware colors shared by the feature tiers on the home page.
///
/// The tier cards are transparent, so text and controls must follow the active
/// color scheme instead of assuming a permanently dark background.
class HomeTierPalette {
  final Color primaryText;
  final Color secondaryText;
  final Color trailingIcon;
  final Color chipBackground;
  final Color chipBorder;
  final bool isDark;

  const HomeTierPalette({
    required this.primaryText,
    required this.secondaryText,
    required this.trailingIcon,
    required this.chipBackground,
    required this.chipBorder,
    required this.isDark,
  });

  factory HomeTierPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HomeTierPalette(
      primaryText: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      trailingIcon: scheme.onSurfaceVariant,
      chipBackground: scheme.surfaceContainerHighest,
      chipBorder: scheme.outlineVariant,
      isDark: scheme.brightness == Brightness.dark,
    );
  }

  Color tintedChipBackground(Color accent) {
    return Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.18 : 0.10),
      chipBackground,
    );
  }
}

class HomeTierFeatureListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HomeTierFeatureListTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.description = '',
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HomeTierPalette.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: iconColor),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.primaryText,
          height: 1.5,
        ),
      ),
      subtitle: description.isNotEmpty
          ? Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: palette.secondaryText,
                height: 1.5,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        size: 16,
        color: palette.trailingIcon,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
