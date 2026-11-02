import 'package:flutter/material.dart';
import '../models/asset_calendar_reflection.dart';

class AssetReflectionDayBadge extends StatelessWidget {
  const AssetReflectionDayBadge({
    super.key,
    required this.kinds,
    this.preserveTextScale = false,
  });
  final Set<AssetReflectionKind> kinds;
  final bool preserveTextScale;
  static Color? backgroundFor(Set<AssetReflectionKind> kinds) {
    if (kinds.contains(AssetReflectionKind.tobaccoPurchase)) {
      return const Color(0xFFCBD5E1);
    }
    if (kinds.contains(AssetReflectionKind.drinkingOut)) {
      return const Color(0xFFFECACA);
    }
    if (kinds.contains(AssetReflectionKind.dining)) {
      return const Color(0xFFFED7AA);
    }
    if (kinds.contains(AssetReflectionKind.alcoholPurchase)) {
      return const Color(0xFFF5D0FE);
    }
    if (kinds.contains(AssetReflectionKind.reading)) {
      return const Color(0xFFBBF7D0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      kinds.map((kind) => kind.label).join('\n'),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Color(0xFF172554),
      ),
    );
    return preserveTextScale
        ? text
        : FittedBox(fit: BoxFit.scaleDown, child: text);
  }
}
