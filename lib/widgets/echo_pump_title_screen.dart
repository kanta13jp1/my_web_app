import 'package:flutter/material.dart';

/// Static opening artwork with accessible, independent game controls.
class EchoPumpTitleScreen extends StatelessWidget {
  const EchoPumpTitleScreen({
    super.key,
    required this.onStart,
    this.backgroundAsset = 'assets/echo_pump/opening_background.png',
  });

  final VoidCallback onStart;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        key: const Key('echo-title-screen'),
        backgroundColor: const Color(0xFF081318),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              backgroundAsset,
              key: const Key('echo-opening-background'),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                key: Key('echo-background-fallback'),
                color: Color(0xFF081318),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xDE071216), Color(0x30071216)],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 600;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 24 : 64),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '夜間排水施設',
                                  style: TextStyle(
                                    color: Color(0xFFA7DFD5),
                                    fontSize: 14,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Semantics(
                                  header: true,
                                  child: Text(
                                    '残響\nポンプ室',
                                    semanticsLabel: '残響ポンプ室',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansJP',
                                      color: const Color(0xFFF0F5F2),
                                      fontSize: compact ? 48 : 76,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  '雨の向こうで、まだ何かが動いている。',
                                  style: TextStyle(
                                    color: Color(0xFFD3DEDD),
                                    fontSize: 16,
                                    height: 1.7,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                FilledButton.icon(
                                  key: const Key('echo-start'),
                                  autofocus: true,
                                  onPressed: onStart,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF9BE0CF),
                                    foregroundColor: const Color(0xFF10231F),
                                    minimumSize: const Size(220, 56),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 18,
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text(
                                    'ゲーム開始',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
