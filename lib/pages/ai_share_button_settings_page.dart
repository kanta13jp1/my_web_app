import 'package:flutter/material.dart';

import '../widgets/ai_share_button_settings_panel.dart';

class AiShareButtonSettingsPage extends StatelessWidget {
  const AiShareButtonSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIシェアボタン')),
      body: const SafeArea(
        child: SingleChildScrollView(child: AiShareButtonSettingsPanel()),
      ),
    );
  }
}
