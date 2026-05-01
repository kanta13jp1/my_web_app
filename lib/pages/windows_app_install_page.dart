import 'package:flutter/material.dart';

import '../utils/web_image_downloader.dart';

class WindowsAppInstallPage extends StatelessWidget {
  const WindowsAppInstallPage({super.key});

  static const latestZipUrl =
      'https://github.com/kanta13jp1/my_web_app/releases/latest/download/jibun-windows-companion.zip';
  static const workflowUrl =
      'https://github.com/kanta13jp1/my_web_app/actions/workflows/windows-companion-build.yml';
  static const issueUrl =
      'https://github.com/kanta13jp1/my_web_app/issues/1493';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Windowsアプリ版'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroPanel(theme: theme),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => openWebUrl(latestZipUrl),
                      icon: const Icon(Icons.download_for_offline_outlined),
                      label: const Text('Windows版ZIPをダウンロード'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openWebUrl(workflowUrl),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('ビルド履歴を見る'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/local-smart-cleanup'),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('スマート整理を開く'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openWebUrl(issueUrl),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('P0 Issue'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 880;
                    const cards = <Widget>[
                      _StepCard(
                        number: '1',
                        title: 'ZIPを取得',
                        body: '最新版の配布ZIPをダウンロードします。',
                        icon: Icons.file_download_outlined,
                      ),
                      _StepCard(
                        number: '2',
                        title: '任意フォルダに展開',
                        body: 'Downloads以外の固定フォルダに展開すると更新管理が安定します。',
                        icon: Icons.folder_open_outlined,
                      ),
                      _StepCard(
                        number: '3',
                        title: 'アプリを起動',
                        body: '展開先の my_web_app.exe を起動します。',
                        icon: Icons.desktop_windows_outlined,
                      ),
                      _StepCard(
                        number: '4',
                        title: '承認して実行',
                        body: 'スキャン結果を確認し、承認済みの候補だけをローカルで処理します。',
                        icon: Icons.verified_user_outlined,
                      ),
                    ];
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var index = 0;
                              index < cards.length;
                              index++) ...[
                            if (index > 0) const SizedBox(width: 12),
                            Expanded(child: cards[index]),
                          ],
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards
                          .map(
                            (card) => SizedBox(
                              width: 260,
                              child: card,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _RolePanel(theme: theme),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '安定ダウンロードURL: $latestZipUrl',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.desktop_windows_outlined,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Windows Companion App',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Web版ではできないローカルPCのスキャン、承認済み整理、Windowsタスク登録をWindowsアプリ側で実行します。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String number;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  number,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePanel extends StatelessWidget {
  const _RolePanel({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final rows = <({String label, String body})>[
      (
        label: 'Web版',
        body: 'インストール導線、レポート確認、承認CSV編集を担当します。',
      ),
      (
        label: 'Windows版',
        body: 'ローカルPCのファイル確認とPowerShell実行を担当します。',
      ),
      (
        label: 'PowerShell',
        body: '承認済み候補だけを検証し、ごみ箱移動と結果ログ保存を行います。',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '役割分担',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
            _RoleLine(label: row.label, body: row.body),
            if (row != rows.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _RoleLine extends StatelessWidget {
  const _RoleLine({
    required this.label,
    required this.body,
  });

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            body,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
