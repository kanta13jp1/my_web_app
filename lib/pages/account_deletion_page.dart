import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_deletion_request.dart';
import '../services/account_lifecycle_service.dart';
import '../view_models/account_deletion_view_model.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key, this.gateway});

  final AccountLifecycleGateway? gateway;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  late final AccountDeletionViewModel _viewModel;
  final _confirmationController = TextEditingController();
  final _reauthenticationPasswordController = TextEditingController();
  bool _understood = false;

  @override
  void initState() {
    super.initState();
    _viewModel = AccountDeletionViewModel(
      gateway: widget.gateway ?? AccountLifecycleService(),
    )..load();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    _reauthenticationPasswordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('退会・アカウント削除')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                if (_viewModel.isLoading && _viewModel.snapshot == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SubscriptionCancellationCard(
                        onOpenBilling: () =>
                            Navigator.of(context).pushNamed('/billing'),
                      ),
                      const SizedBox(height: 16),
                      _RetentionSummaryCard(policy: _viewModel.policy),
                      const SizedBox(height: 16),
                      if (_viewModel.errorCode != null)
                        _ErrorCard(
                          code: _viewModel.errorCode!,
                          passwordController:
                              _reauthenticationPasswordController,
                          isSubmitting: _viewModel.isSubmitting,
                          onPasswordReauthenticate: () async {
                            final password =
                                _reauthenticationPasswordController.text;
                            await _viewModel.reauthenticateWithPassword(
                              password,
                            );
                            _reauthenticationPasswordController.clear();
                          },
                          onGoogleReauthenticate:
                              _viewModel.reauthenticateWithGoogle,
                          onOpenBilling: () =>
                              Navigator.of(context).pushNamed('/billing'),
                        ),
                      if (_viewModel.errorCode != null)
                        const SizedBox(height: 16),
                      if (_viewModel.notice != null)
                        Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_viewModel.notice!),
                          ),
                        ),
                      if (_viewModel.notice != null) const SizedBox(height: 16),
                      if (_viewModel.request case final request?)
                        _PendingRequestCard(
                          request: request,
                          isSubmitting: _viewModel.isSubmitting,
                          onCancel: request.canCancel
                              ? _viewModel.cancelDeletion
                              : null,
                        )
                      else
                        _DeletionRequestCard(
                          policy: _viewModel.policy,
                          controller: _confirmationController,
                          understood: _understood,
                          isSubmitting: _viewModel.isSubmitting,
                          onUnderstoodChanged: (value) {
                            setState(() => _understood = value ?? false);
                          },
                          onConfirmationChanged: (_) => setState(() {}),
                          onSubmit: _canSubmit
                              ? () => _confirmAndSubmit(context)
                              : null,
                        ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/privacy'),
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('データ保持・削除ポリシーを確認'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    final requiredText = _viewModel.policy?.confirmation ?? 'アカウントを削除する';
    return !_viewModel.isSubmitting &&
        _understood &&
        _confirmationController.text.trim() == requiredText;
  }

  Future<void> _confirmAndSubmit(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退会申請を送信しますか？'),
        content: const Text('30日の取消猶予後、アカウントと関連データは復元できなくなります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退会申請を送信'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _viewModel.requestDeletion(_confirmationController.text.trim());
    }
  }
}

class _SubscriptionCancellationCard extends StatelessWidget {
  const _SubscriptionCancellationCard({required this.onOpenBilling});

  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('サブスクリプション解約', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '有料プランの解約だけではアカウントや保存データは削除されません。'
              '請求期間終了後もFreeプランとして利用できます。',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenBilling,
              icon: const Icon(Icons.credit_card_outlined),
              label: const Text('請求・サブスク管理を開く'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetentionSummaryCard extends StatelessWidget {
  const _RetentionSummaryCard({required this.policy});

  final AccountDeletionPolicy? policy;

  @override
  Widget build(BuildContext context) {
    final days = policy?.graceDays ?? 30;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('退会後のデータ処理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('申請から$days日間は取り消し可能です。'),
            const SizedBox(height: 4),
            const Text('期限後に関連データを削除し、発行済みトークンの失効後に残存を再確認します。'),
            const SizedBox(height: 4),
            const Text('法令上保持が必要な決済記録と隔離バックアップは、各保持期限まで利用を制限します。'),
          ],
        ),
      ),
    );
  }
}

class _DeletionRequestCard extends StatelessWidget {
  const _DeletionRequestCard({
    required this.policy,
    required this.controller,
    required this.understood,
    required this.isSubmitting,
    required this.onUnderstoodChanged,
    required this.onConfirmationChanged,
    required this.onSubmit,
  });

  final AccountDeletionPolicy? policy;
  final TextEditingController controller;
  final bool understood;
  final bool isSubmitting;
  final ValueChanged<bool?> onUnderstoodChanged;
  final ValueChanged<String> onConfirmationChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final confirmation = policy?.confirmation ?? 'アカウントを削除する';
    final danger = Theme.of(context).colorScheme.error;
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: .35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '退会を申請する',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: danger),
            ),
            const SizedBox(height: 8),
            const Text('この操作は有料プランの解約とは別です。期限後の削除は取り消せません。'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account-deletion-confirmation'),
              controller: controller,
              onChanged: onConfirmationChanged,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: '確認のため「$confirmation」と入力',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: understood,
              onChanged: onUnderstoodChanged,
              title: const Text('削除対象と取消猶予、法定保持の例外を確認しました'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            FilledButton.icon(
              key: const Key('account-deletion-submit'),
              onPressed: onSubmit,
              style: FilledButton.styleFrom(backgroundColor: danger),
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('退会申請へ進む'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.isSubmitting,
    required this.onCancel,
  });

  final AccountDeletionRequest request;
  final bool isSubmitting;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheduled = DateFormat(
      'yyyy年M月d日 HH:mm',
    ).format(request.scheduledFor.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('退会申請を受付済み', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('削除予定: $scheduled'),
            Text('状態: ${_statusLabel(request.status)}'),
            if (request.lastErrorCode != null)
              const Text('安全確認のため処理を保留しています。運営者が再試行します。'),
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('account-deletion-cancel'),
                onPressed: isSubmitting ? null : onCancel,
                child: const Text('退会申請を取り消す'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.code,
    required this.passwordController,
    required this.isSubmitting,
    required this.onPasswordReauthenticate,
    required this.onGoogleReauthenticate,
    required this.onOpenBilling,
  });

  final String code;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final VoidCallback onPasswordReauthenticate;
  final VoidCallback onGoogleReauthenticate;
  final VoidCallback onOpenBilling;

  @override
  Widget build(BuildContext context) {
    final reauth = const {
      'reauthentication_required',
      'reauthentication_failed',
      'reauthentication_email_unavailable',
      'reauthentication_launch_failed',
    }.contains(code);
    final billing = code == 'active_subscription_must_be_cancelled';
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_errorMessage(code)),
            if (reauth) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('account-deletion-reauth-password'),
                controller: passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'パスワード',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('account-deletion-reauth-password-submit'),
                onPressed: isSubmitting ? null : onPasswordReauthenticate,
                child: const Text('パスワードで本人確認'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('account-deletion-reauth-google'),
                onPressed: isSubmitting ? null : onGoogleReauthenticate,
                child: const Text('Googleで再ログイン'),
              ),
            ],
            if (billing) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onOpenBilling,
                child: const Text('サブスク管理を開く'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'pending' => '取消猶予中',
      'processing' => '削除処理中',
      'awaiting_token_expiry' => 'アクセストークン失効待ち',
      'failed' => '安全確認・再試行待ち',
      _ => status,
    };

String _errorMessage(String code) => switch (code) {
      'authentication_required' => 'ログイン後にもう一度お試しください。',
      'reauthentication_required' => '本人確認のため、15分以内に再ログインしてください。',
      'active_subscription_must_be_cancelled' =>
        '先に有料サブスクリプションの解約手続きを完了してください。',
      'confirmation_mismatch' => '確認文が一致しません。',
      'reauthentication_launch_failed' => '再ログイン画面を開けませんでした。',
      'reauthentication_failed' => 'パスワードを確認できませんでした。もう一度お試しください。',
      'reauthentication_email_unavailable' =>
        'ログイン中のメールアドレスを確認できません。Googleで再ログインしてください。',
      _ => '退会処理を開始できませんでした。時間をおいて再度お試しください。',
    };
