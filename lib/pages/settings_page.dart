import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('テーマ設定'),
            subtitle: Text(_getThemeText(themeService.themeMode)),
            trailing: const Icon(Icons.brightness_6),
            onTap: () => _showThemeDialog(context, themeService),
          ),
          // 他の設定項目...
        ],
      ),
    );
  }

  String _getThemeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'システムに合わせる';
      case ThemeMode.light:
        return 'ライトモード';
      case ThemeMode.dark:
        return 'ダークモード';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeService service) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('テーマを選択'),
        children: [
          _buildOption(context, service, ThemeMode.system, 'システムに合わせる'),
          _buildOption(context, service, ThemeMode.light, 'ライトモード'),
          _buildOption(context, service, ThemeMode.dark, 'ダークモード'),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, ThemeService service, ThemeMode mode, String text) {
    return SimpleDialogOption(
      onPressed: () {
        service.setThemeMode(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              service.themeMode == mode
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: service.themeMode == mode ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }
}
