import 'package:flutter/material.dart';

enum GoogleOAuthDisclosurePurpose { signIn, accountDeletionReauthentication }

extension on GoogleOAuthDisclosurePurpose {
  String get explanation => switch (this) {
        GoogleOAuthDisclosurePurpose.signIn => 'ログインとアカウント表示のために使用します。',
        GoogleOAuthDisclosurePurpose.accountDeletionReauthentication =>
          '退会申請を行う本人であることを確認するために使用します。',
      };

  String get continueLabel => switch (this) {
        GoogleOAuthDisclosurePurpose.signIn => '同意してGoogleへ',
        GoogleOAuthDisclosurePurpose.accountDeletionReauthentication =>
          '同意して本人確認へ',
      };
}

Future<bool> showGoogleOAuthDisclosureDialog({
  required BuildContext context,
  GoogleOAuthDisclosurePurpose purpose = GoogleOAuthDisclosurePurpose.signIn,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => GoogleOAuthDisclosureDialog(purpose: purpose),
  );
  return accepted ?? false;
}

class GoogleOAuthDisclosureDialog extends StatelessWidget {
  const GoogleOAuthDisclosureDialog({
    super.key,
    this.purpose = GoogleOAuthDisclosurePurpose.signIn,
  });

  final GoogleOAuthDisclosurePurpose purpose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('google-oauth-disclosure-dialog'),
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Googleに移動する前の確認'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purpose.explanation,
                key: const Key('google-oauth-purpose'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const _DisclosureItem(
                icon: Icons.account_circle_outlined,
                title: '取得するGoogleアカウント情報',
                body: '表示名、メールアドレス、プロフィール画像',
              ),
              const SizedBox(height: 12),
              const _DisclosureItem(
                icon: Icons.block_outlined,
                title: 'この操作では取得しない情報',
                body: 'Gmail、Googleカレンダー、Google Driveの内容',
              ),
              const SizedBox(height: 12),
              const _DisclosureItem(
                icon: Icons.storage_outlined,
                title: '保存・共有',
                body:
                    'Supabaseを認証・保存の委託先として利用し、アカウントの存続中に保持します。広告配信やデータ販売には利用しません。',
              ),
              const SizedBox(height: 12),
              const _DisclosureItem(
                icon: Icons.delete_outline,
                title: '削除',
                body: '退会申請後の取消猶予が終了すると、関連するアカウント情報の削除を開始します。',
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('google-oauth-privacy-link'),
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/privacy'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('プライバシーポリシーを確認'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('google-oauth-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('google-oauth-accept'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(purpose.continueLabel),
        ),
      ],
    );
  }
}

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}
