import 'package:flutter/material.dart';

import '../widgets/ai_share_button_settings_panel.dart';

class AiShareButtonSettingsPage extends StatelessWidget {
  const AiShareButtonSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIシェアボタン')),
      // パネル自体が縦スクロールを持つ(設定シートの overflow 対策)ため、
      // ここでの二重 SingleChildScrollView は不要。
      body: const SafeArea(child: AiShareButtonSettingsPanel()),
    );
  }
}
