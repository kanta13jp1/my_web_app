import 'package:flutter/material.dart';

enum _ExampleRoute { direct, forward, strip }

/// Illustrates fixed examples only; it neither reads credentials nor sends data.
class SyntheticAuthBoundaryGuide extends StatefulWidget {
  const SyntheticAuthBoundaryGuide({super.key});

  @override
  State<SyntheticAuthBoundaryGuide> createState() =>
      _SyntheticAuthBoundaryGuideState();
}

class _SyntheticAuthBoundaryGuideState
    extends State<SyntheticAuthBoundaryGuide> {
  _ExampleRoute _selected = _ExampleRoute.direct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final throughMiddle = _selected != _ExampleRoute.direct;
    final reachesDestination = _selected != _ExampleRoute.strip;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('認証情報が届く場所を考える', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '架空の認証文字列を使い、中継する場合はその文字列を'
              '中継先へ明示的に渡す例です。経路を選ぶと、それぞれの'
              '受信先を確認できます。実際の情報は入力しません。',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (route, label) in const [
                  (_ExampleRoute.direct, '直接送る'),
                  (_ExampleRoute.forward, '中継して転送'),
                  (_ExampleRoute.strip, '中継で除去'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _selected == route,
                    onSelected: (_) => setState(() => _selected = route),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              throughMiddle ? '中継先：架空の認証文字列を受け取る' : '中継先：経由しない',
              key: const Key('auth-boundary-intermediary'),
            ),
            const SizedBox(height: 4),
            Text(
              reachesDestination ? '送信先：架空の認証文字列を受け取る' : '送信先：認証文字列は届かない',
              key: const Key('auth-boundary-destination'),
            ),
            const SizedBox(height: 12),
            const Text(
              'これは固定の例で、通信・保存・実際の設定変更は行いません。'
              '暗号化通信の安全性や実在製品の動作・規約違反・情報漏えいを'
              '検査する機能ではありません。',
            ),
          ],
        ),
      ),
    );
  }
}
