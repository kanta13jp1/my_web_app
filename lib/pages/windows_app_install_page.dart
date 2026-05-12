import 'package:flutter/material.dart';

import '../utils/web_image_downloader.dart';

class WindowsAppInstallPage extends StatelessWidget {
  const WindowsAppInstallPage({super.key});

  static const latestMsixUrl =
      'https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.msix';
  static const latestCertificateUrl =
      'https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.cer';
  static const latestZipUrl =
      'https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.zip';
  static const workflowUrl =
      'https://github.com/kanta13jp1/my_web_app/actions/workflows/windows-companion-build.yml';
  static const guideUrl =
      'https://github.com/kanta13jp1/my_web_app/blob/main/docs/WINDOWS_COMPANION_APP.md';
  static const issueUrl =
      'https://github.com/kanta13jp1/my_web_app/issues/1498';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Windows アプリ版'),
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
                      onPressed: () => openWebUrl(latestMsixUrl),
                      icon: const Icon(Icons.install_desktop_outlined),
                      label: const Text('MSIX をインストール'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openWebUrl(latestCertificateUrl),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('証明書を取得'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openWebUrl(latestZipUrl),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('ZIP 版'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openWebUrl(workflowUrl),
                      icon: const Icon(Icons.build_circle_outlined),
                      label: const Text('ビルド履歴'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/local-smart-cleanup'),
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('スマート整理を開く'),
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
                        title: 'MSIX を取得',
                        body:
                            '通常は MSIX を使います。Windows のアプリとして登録され、更新管理もしやすくなります。',
                        icon: Icons.install_desktop_outlined,
                      ),
                      _StepCard(
                        number: '2',
                        title: '証明書を信頼',
                        body:
                            '自己署名ビルドの場合だけ、同梱の .cer を Trusted People に登録してからインストールします。',
                        icon: Icons.verified_outlined,
                      ),
                      _StepCard(
                        number: '3',
                        title: 'アプリを起動',
                        body:
                            'インストール後は Jibun Windows Companion としてスタートメニューから起動できます。',
                        icon: Icons.desktop_windows_outlined,
                      ),
                      _StepCard(
                        number: '4',
                        title: '承認して実行',
                        body: 'スキャン結果を確認し、承認済みの候補だけをローカルPCで処理します。',
                        icon: Icons.task_alt_outlined,
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
                _LinkPanel(
                  theme: theme,
                  msixUrl: latestMsixUrl,
                  certUrl: latestCertificateUrl,
                  zipUrl: latestZipUrl,
                  guideUrl: guideUrl,
                  issueUrl: issueUrl,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'MSIX が利用できない場合も、ZIP 版を展開して my_web_app.exe を起動できます。',
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
                  'Web 版ではできないローカルPCのスキャン、承認済み整理、Windows タスク登録をアプリ側で実行します。',
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
        label: 'MSIX',
        body: 'Windows にアプリとして登録し、今後の更新や署名検証に乗せる標準配布形式です。',
      ),
      (
        label: '証明書',
        body: '本番証明書が未設定の場合は自己署名になります。初回だけ .cer を信頼してから使います。',
      ),
      (
        label: 'ZIP',
        body: 'インストールが難しい環境向けのポータブル fallback として残しています。',
      ),
      (
        label: 'PowerShell',
        body: '承認済み候補だけを検証し、ごみ箱移動と結果ログ保存をローカルで実行します。',
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
            '配布方式',
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

class _LinkPanel extends StatelessWidget {
  const _LinkPanel({
    required this.theme,
    required this.msixUrl,
    required this.certUrl,
    required this.zipUrl,
    required this.guideUrl,
    required this.issueUrl,
  });

  final ThemeData theme;
  final String msixUrl;
  final String certUrl;
  final String zipUrl;
  final String guideUrl;
  final String issueUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final links = <({String label, String url})>[
      (label: 'MSIX', url: msixUrl),
      (label: '証明書', url: certUrl),
      (label: 'ZIP fallback', url: zipUrl),
      (label: '運用手順', url: guideUrl),
      (label: 'Issue #1498', url: issueUrl),
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
            'ダウンロードリンク',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => openWebUrl(link.url),
                child: Text(
                  '${link.label}: ${link.url}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
