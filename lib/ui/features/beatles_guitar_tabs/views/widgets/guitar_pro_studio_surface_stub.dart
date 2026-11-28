import 'package:flutter/material.dart';

import '../../../../../theme/design_tokens.dart';

const String kGuitarProStudioAssetPath = '/labs/guitar-pro-studio/index.html';

class GuitarProStudioSurface extends StatelessWidget {
  const GuitarProStudioSurface({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          key: const Key('guitar_pro_studio_fallback'),
          margin: const EdgeInsets.all(DesignTokens.space24),
          padding: const EdgeInsets.all(DesignTokens.space20),
          decoration: BoxDecoration(
            color: DesignTokens.surface2,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.divider),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.music_note_outlined,
                color: DesignTokens.orangeLight,
                size: 32,
              ),
              SizedBox(height: DesignTokens.space12),
              Text(
                'プロ譜面ラボ (alphaTab) は Web 版の my_web_app で利用できます。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: DesignTokens.space8),
              Text(
                'SMuFL (Bravura) 五線譜＋6線TAB、複数トラック切替、ローカル .gp/.gpx/.musicxml/.tex 読込に対応します。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
