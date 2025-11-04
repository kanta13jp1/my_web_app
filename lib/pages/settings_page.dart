import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // 外観セクション
          _buildSectionHeader('外観', Icons.palette),
          
          // テーマモード設定
          ListTile(
            leading: Icon(
              themeService.themeMode == AppThemeMode.light  // 更新
                  ? Icons.light_mode
                  : themeService.themeMode == AppThemeMode.dark  // 更新
                      ? Icons.dark_mode
                      : Icons.brightness_auto,
            ),
            title: const Text('テーマ'),
            subtitle: Text(_getThemeModeLabel(themeService.themeMode)),
            onTap: () => _showThemeModeDialog(context, themeService),
          ),

          // テーマカラー選択
          ListTile(
            leading: Icon(Icons.color_lens, color: themeService.primaryColor),
            title: const Text('テーマカラー'),
            subtitle: const Text('アプリのメインカラーを変更'),
            onTap: () => _showColorPickerDialog(context, themeService),
          ),

          const Divider(),

          // プレビュー
          _buildSectionHeader('プレビュー', Icons.visibility),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: themeService.primaryColor,
                      child: const Icon(Icons.note, color: Colors.white),
                    ),
                    title: const Text('サンプルメモ'),
                    subtitle: const Text('これはプレビューです'),
                    trailing: IconButton(
                      icon: const Icon(Icons.star_border),
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('ボタンのプレビュー'),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          const Divider(),

          // アプリ情報
          _buildSectionHeader('アプリ情報', Icons.info),
          
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('バージョン'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeLabel(AppThemeMode mode) {  // 更新
    switch (mode) {
      case AppThemeMode.light:
        return 'ライトモード';
      case AppThemeMode.dark:
        return 'ダークモード';
      case AppThemeMode.system:
        return 'システム設定に従う';
    }
  }

  void _showThemeModeDialog(BuildContext context, ThemeService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマを選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<AppThemeMode>(  // 更新
              title: const Row(
                children: [
                  Icon(Icons.light_mode),
                  SizedBox(width: 12),
                  Text('ライトモード'),
                ],
              ),
              value: AppThemeMode.light,  // 更新
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(  // 更新
              title: const Row(
                children: [
                  Icon(Icons.dark_mode),
                  SizedBox(width: 12),
                  Text('ダークモード'),
                ],
              ),
              value: AppThemeMode.dark,  // 更新
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<AppThemeMode>(  // 更新
              title: const Row(
                children: [
                  Icon(Icons.brightness_auto),
                  SizedBox(width: 12),
                  Text('システム設定に従う'),
                ],
              ),
              value: AppThemeMode.system,  // 更新
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, ThemeService themeService) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
      Colors.deepOrange,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テーマカラーを選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              final isSelected = color.value == themeService.primaryColor.value;
              
              return InkWell(
                onTap: () {
                  themeService.setPrimaryColor(color);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 32)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}