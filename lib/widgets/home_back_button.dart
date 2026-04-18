import 'package:flutter/material.dart';

/// Windows版#94: Flutter Web の URL 永続化問題対応
///
/// Navigator 1.0 + PathUrlStrategy 環境では、デフォルトの AppBar back button
/// を押しても URL は現在のパスのまま残る。ユーザーが画面更新すると元のページに
/// 戻されてしまうため、明示的に `pushNamedAndRemoveUntil('/', ...)` を呼んで
/// URL を '/' に更新する戻るボタンを提供する。
///
/// 使用例:
/// ```dart
/// AppBar(
///   title: const Text('..'),
///   leading: const HomeBackButton(),
/// )
/// ```
class HomeBackButton extends StatelessWidget {
  final Color? color;
  final IconData icon;

  const HomeBackButton({
    super.key,
    this.color,
    this.icon = Icons.arrow_back,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: 'ホームに戻る',
      onPressed: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/', (route) => false),
    );
  }
}
