import 'package:flutter/material.dart';

import '../../../../../theme/design_tokens.dart';
import '../../../../../domain/models/guitar_tab_song.dart';

class GuitarTabStaff extends StatelessWidget {
  const GuitarTabStaff({super.key, required this.section});

  final GuitarTabSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            section.title,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            section.practiceNote,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          Semantics(
            label: '${section.title}のギタータブ譜',
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: DesignTokens.background,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              ),
              padding: const EdgeInsets.all(DesignTokens.space16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  section.lines.join('\n'),
                  key: const Key('beatles_tab_notation'),
                  style: const TextStyle(
                    color: DesignTokens.textOnDark,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
