import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_version.dart';
import '../services/theme_service.dart';
import 'ai_form_assistant_page.dart';
import 'ai_share_button_settings_page.dart';
import 'profile_settings_page.dart';
import 'asset_management_page.dart';
import 'financial_report_page.dart';
import 'admin_analytics_page.dart';
import 'feedback_page.dart';
import 'offline_secure_mode_settings_page.dart';
import 'account_deletion_page.dart';
import 'theme_selector_page.dart';
import 'voice_ai_governance_page.dart';

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
            leading: const Icon(Icons.person_outline),
            title: const Text('プロフィール設定'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/profile-settings'),
                builder: (_) => const ProfileSettingsPage(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('settings-ai-form-assistant'),
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('AIフォーム設定支援'),
            subtitle: const Text('対話で複雑な設定を入力・確認'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/settings/ai-form-assistant',
                ),
                builder: (_) => const AiFormAssistantPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('テーマ設定'),
            subtitle: Text(_getThemeText(themeService.themeMode)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showThemeDialog(context, themeService),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('デザインテーマ'),
            subtitle: Text(
              _currentCatalogThemeName(themeService.selectedThemeCode),
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/settings/theme'),
                builder: (_) => const ThemeSelectorPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_motion_outlined),
            title: const Text('AIシェアボタン'),
            subtitle: const Text('表示と位置'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings:
                    const RouteSettings(name: '/settings/ai-share-button'),
                builder: (_) => const AiShareButtonSettingsPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Voice AI governance'),
            subtitle: const Text('Consent, ZDR, usage, and realtime TTS'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoiceAiGovernancePage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('アセット管理'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/asset-management'),
                builder: (_) => const AssetManagementPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('財務レポート'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/financial-report'),
                builder: (_) => const FinancialReportPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('オフラインセキュアモード'),
            subtitle: const Text('ローカルRAGと外部API遮断ポリシー'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/offline-secure-mode'),
                builder: (_) => const OfflineSecureModeSettingsPage(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('フィードバック'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/feedback'),
                builder: (_) => const FeedbackPage(),
              ),
            ),
          ),
          ListTile(
            key: const Key('settings-account-deletion'),
            leading: Icon(
              Icons.person_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('退会・アカウント削除'),
            subtitle: const Text('サブスク解約とは別に、関連データの削除を申請'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/account-deletion'),
                builder: (_) => const AccountDeletionPage(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('管理者パネル'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/admin'),
                builder: (_) => const AdminAnalyticsPage(),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                AppVersion.display,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _currentCatalogThemeName(String code) {
    final def = ThemeService.catalog.firstWhere(
      (d) => d.code == code,
      orElse: () => ThemeService.catalog.first,
    );
    return '${def.emoji} ${def.nameJa}';
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
    BuildContext context,
    ThemeService service,
    ThemeMode mode,
    String text,
  ) {
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
              color: service.themeMode == mode
                  ? const Color(0xFF3D5AFE)
                  : const Color(0xFFB0B0B0),
            ),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }
}
