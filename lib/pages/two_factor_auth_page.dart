import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 二要素認証管理ページ
/// 2FA の有効化・バックアップコード・デバイス管理。
/// two-factor-auth Edge Function と連携。
class TwoFactorAuthPage extends StatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _trustedDevices = [];
  List<String> _backupCodes = [];

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final statusRes = await _supabase.functions.invoke(
        'two-factor-auth',
        queryParameters: {'view': 'status'},
      );
      final devRes = await _supabase.functions.invoke(
        'two-factor-auth',
        queryParameters: {'view': 'trusted_devices'},
      );
      setState(() {
        final sd = statusRes.data;
        if (sd is Map<String, dynamic>) _status = sd;

        final dd = devRes.data;
        if (dd is Map<String, dynamic>) {
          final list = dd['devices'];
          if (list is List) {
            _trustedDevices =
                list.map((d) => d as Map<String, dynamic>).toList();
          }
        }
      });
    } catch (e) {
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle2FA(bool enable) async {
    try {
      final res = await _supabase.functions.invoke(
        'two-factor-auth',
        body: {'action': enable ? 'enable' : 'disable'},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && enable) {
        final codes = data['backupCodes'];
        if (codes is List) {
          setState(() {
            _backupCodes = codes.map((c) => '$c').toList();
          });
          _showBackupCodesDialog();
        }
      }
      await _fetchStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _showBackupCodesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップコード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'これらのコードを安全な場所に保存してください。\n各コードは1回のみ使用できます。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _backupCodes
                    .map(
                      (c) => Text(
                        c,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: _backupCodes.join('\n')),
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('コピーしました')),
                );
              }
            },
            child: const Text('コピー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('二要素認証 (2FA)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchStatus),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchStatus, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final data = _status ?? {};
    final enabled = data['enabled'] as bool? ?? false;
    final method = data['method'] as String? ?? 'totp';
    final lastUsed = data['lastUsedAt'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: enabled ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '二要素認証',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            enabled ? '有効 ($method)' : '無効',
                            style: TextStyle(
                              color: enabled ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (v) => _toggle2FA(v),
                    ),
                  ],
                ),
                if (lastUsed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '最終使用: ${lastUsed.length >= 10 ? lastUsed.substring(0, 10) : lastUsed}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (enabled) ...[
          Text(
            '信頼済みデバイス',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_trustedDevices.isEmpty)
            const Text(
              '信頼済みデバイスがありません',
              style: TextStyle(color: Colors.grey),
            )
          else
            ..._trustedDevices.map((d) {
              final name = d['deviceName'] as String? ?? 'デバイス';
              final trusted = d['trustedAt'] as String? ?? '';
              final current = d['isCurrent'] as bool? ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.devices,
                    color: current ? Colors.green : null,
                  ),
                  title: Text(name),
                  subtitle: trusted.isNotEmpty
                      ? Text(
                          '信頼日: ${trusted.length >= 10 ? trusted.substring(0, 10) : trusted}',
                        )
                      : null,
                  trailing: current
                      ? const Chip(label: Text('このデバイス'))
                      : IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () async {
                            try {
                              await _supabase.functions.invoke(
                                'two-factor-auth',
                                body: {
                                  'action': 'revoke_device',
                                  'deviceId': d['id'],
                                },
                              );
                              await _fetchStatus();
                            } catch (_) {}
                          },
                        ),
                ),
              );
            }),
        ],
      ],
    );
  }
}
