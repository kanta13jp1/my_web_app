import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_tier/home_tier_styles.dart';

void main() {
  group('HomeTierFeatureListTile', () {
    for (final brightness in Brightness.values) {
      testWidgets('uses readable $brightness theme colors', (tester) async {
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: brightness,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: const Scaffold(
              body: HomeTierFeatureListTile(
                icon: Icons.auto_awesome,
                iconColor: Color(0xFF6366F1),
                label: 'AIおすすめ機能',
                description: '目的に合う機能を案内します。',
              ),
            ),
          ),
        );

        final title = tester.widget<Text>(find.text('AIおすすめ機能'));
        final subtitle = tester.widget<Text>(find.text('目的に合う機能を案内します。'));
        final trailing = tester.widget<Icon>(find.byIcon(Icons.chevron_right));

        expect(title.style?.color, scheme.onSurface);
        expect(subtitle.style?.color, scheme.onSurfaceVariant);
        expect(trailing.color, scheme.onSurfaceVariant);
        expect(
          _contrastRatio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('HomeTierPalette', () {
    for (final brightness in Brightness.values) {
      testWidgets('keeps chip text distinct in $brightness mode', (
        tester,
      ) async {
        late HomeTierPalette palette;
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: brightness,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: Builder(
              builder: (context) {
                palette = HomeTierPalette.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(palette.primaryText, scheme.onSurface);
        expect(palette.chipBackground, scheme.surfaceContainerHighest);
        expect(
          _contrastRatio(palette.primaryText, palette.chipBackground),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
