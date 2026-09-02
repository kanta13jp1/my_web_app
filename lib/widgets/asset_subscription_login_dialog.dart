import 'package:flutter/material.dart';

import '../services/asset_subscription_login_service.dart';

class AssetSubscriptionLoginDialog extends StatefulWidget {
  const AssetSubscriptionLoginDialog({
    super.key,
    AssetSubscriptionLoginService? loginService,
  }) : loginService =
            loginService ?? const SupabaseAssetSubscriptionLoginService();

  final AssetSubscriptionLoginService loginService;

  @override
  State<AssetSubscriptionLoginDialog> createState() =>
      _AssetSubscriptionLoginDialogState();
}

class _AssetSubscriptionLoginDialogState
    extends State<AssetSubscriptionLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.loginService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AssetSubscriptionLoginException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'ログインできませんでした。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.login),
          SizedBox(width: 10),
          Expanded(child: Text('ログインして解析を続ける')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'アプリに登録済みのメールアドレスとパスワードを入力してください。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('subscription_login_email'),
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(email)) {
                      return '正しいメールアドレスを入力してください。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('subscription_login_password'),
                  controller: _passwordController,
                  enabled: !_isSubmitting,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? '表示' : '非表示',
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'パスワードを入力してください。' : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    key: const Key('subscription_login_error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '入力したパスワードは保存しません。ログイン状態は安全に維持されます。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('subscription_login_submit'),
          onPressed: _isSubmitting ? null : _signIn,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('ログイン'),
        ),
      ],
    );
  }
}
