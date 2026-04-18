import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// メール整理リマインダーページ。
/// ユーザーが管理対象のメールアカウントを登録し、
/// 定期的にメール整理を実施・記録する。
class EmailCleanupPage extends StatefulWidget {
  const EmailCleanupPage({super.key});

  @override
  State<EmailCleanupPage> createState() => _EmailCleanupPageState();
}

class _EmailCleanupPageState extends State<EmailCleanupPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _accounts = [];

  static const _providers = [
    ('gmail', 'Gmail', Icons.mail, Color(0xFFEA4335)),
    ('outlook', 'Outlook', Icons.mail_outline, Color(0xFF0078D4)),
    ('yahoo', 'Yahoo!メール', Icons.mail, Color(0xFF720E9E)),
    ('icloud', 'iCloud', Icons.cloud, Color(0xFF3693F3)),
    ('other', 'その他', Icons.alternate_email, Color(0xFF757575)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('email_accounts')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      if (mounted) {
        setState(() {
          _accounts = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('EmailCleanupPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _needsClean(Map<String, dynamic> account) {
    final lastCleaned = account['last_cleaned_at']?.toString();
    final interval = account['clean_interval_days'] as int? ?? 7;
    if (lastCleaned == null || lastCleaned.isEmpty) return true;
    final lastDate = DateTime.tryParse(lastCleaned);
    if (lastDate == null) return true;
    return DateTime.now().difference(lastDate).inDays >= interval;
  }

  int _daysSinceClean(Map<String, dynamic> account) {
    final lastCleaned = account['last_cleaned_at']?.toString();
    if (lastCleaned == null || lastCleaned.isEmpty) return -1;
    final lastDate = DateTime.tryParse(lastCleaned);
    if (lastDate == null) return -1;
    return DateTime.now().difference(lastDate).inDays;
  }

  IconData _providerIcon(String provider) {
    for (final p in _providers) {
      if (p.$1 == provider) return p.$3;
    }
    return Icons.alternate_email;
  }

  Color _providerColor(String provider) {
    for (final p in _providers) {
      if (p.$1 == provider) return p.$4;
    }
    return const Color(0xFF757575);
  }

  Future<void> _addAccount() async {
    final emailCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    String selectedProvider = 'gmail';
    int interval = 7;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('メールアカウント追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    hintText: 'example@gmail.com',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ラベル (任意)',
                    hintText: '仕事用、個人用 など',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedProvider,
                  decoration: const InputDecoration(
                    labelText: 'プロバイダー',
                    prefixIcon: Icon(Icons.cloud),
                  ),
                  items: _providers.map((p) {
                    return DropdownMenuItem(
                      value: p.$1,
                      child: Row(
                        children: [
                          Icon(p.$3, size: 18, color: p.$4),
                          const SizedBox(width: 8),
                          Text(p.$2),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedProvider = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: interval,
                  decoration: const InputDecoration(
                    labelText: 'リマインド間隔',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('毎日')),
                    DropdownMenuItem(value: 3, child: Text('3日ごと')),
                    DropdownMenuItem(value: 7, child: Text('週1回')),
                    DropdownMenuItem(value: 14, child: Text('2週間ごと')),
                    DropdownMenuItem(value: 30, child: Text('月1回')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => interval = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('email_accounts').insert({
        'user_id': userId,
        'email_address': email,
        'provider': selectedProvider,
        'label': labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
        'clean_interval_days': interval,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアカウントを追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markCleaned(Map<String, dynamic> account) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final deletedCtrl = TextEditingController();
    final archivedCtrl = TextEditingController();
    final unsubCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${account['label'] ?? account['email_address']} を整理完了',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '整理の結果を記録しましょう（任意）',
                style: TextStyle(fontSize: 13, color: const Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deletedCtrl,
                decoration: const InputDecoration(
                  labelText: '削除した件数',
                  prefixIcon: Icon(Icons.delete_outline),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: archivedCtrl,
                decoration: const InputDecoration(
                  labelText: 'アーカイブした件数',
                  prefixIcon: Icon(Icons.archive_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unsubCtrl,
                decoration: const InputDecoration(
                  labelText: '購読解除した件数',
                  prefixIcon: Icon(Icons.unsubscribe),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('完了を記録'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _supabase.from('email_accounts').update({
        'last_cleaned_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', account['id']);

      await _supabase.from('email_clean_logs').insert({
        'user_id': userId,
        'email_account_id': account['id'],
        'deleted_count': int.tryParse(deletedCtrl.text) ?? 0,
        'archived_count': int.tryParse(archivedCtrl.text) ?? 0,
        'unsubscribed_count': int.tryParse(unsubCtrl.text) ?? 0,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ メール整理を記録しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: Text(
          '${account['email_address']} を削除しますか？\n整理ログも削除されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabase
          .from('email_accounts')
          .delete()
          .eq('id', account['id'])
          .select();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static const _routineSteps = [
    '1. 未読メールを全件チェックし、不要なものを削除',
    '2. メルマガ・プロモーションを確認し、不要なものは配信停止(unsubscribe)',
    '3. 通知メール(SNS/アプリ)で不要なものは通知設定をOFF',
    '4. サブスク関連メールを確認し、使っていないサービスは解約',
    '5. フィルタ・ラベルを整理し、自動振り分けルールを追加',
    '6. ゴミ箱・迷惑メールフォルダを空にする',
    '7. 重要なメールにスター/フラグを付ける',
  ];

  List<bool> _routineChecks = [];

  void _initRoutineChecks() {
    if (_routineChecks.isEmpty) {
      _routineChecks = List.filled(_routineSteps.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initRoutineChecks();
    final needsCleanAccounts =
        _accounts.where((a) => a['is_active'] == true && _needsClean(a));
    final routineDone = _routineChecks.where((c) => c).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('メール整理'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAccount,
        icon: const Icon(Icons.add),
        label: const Text('アカウント追加'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (needsCleanAccounts.isNotEmpty) ...[
                      _buildReminderBanner(needsCleanAccounts.length),
                      const SizedBox(height: 12),
                    ],
                    _buildRoutineCard(routineDone),
                    const SizedBox(height: 16),
                    ..._accounts.map(_buildAccountCard),
                  ],
                ),
    );
  }

  Widget _buildRoutineCard(int doneCount) {
    final progress =
        _routineSteps.isEmpty ? 0.0 : doneCount / _routineSteps.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              progress >= 1.0 ? Colors.green.shade200 : Colors.indigo.shade100,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: progress >= 1.0
                ? Colors.green.shade50
                : const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            progress >= 1.0 ? Icons.check_circle : Icons.checklist,
            color: progress >= 1.0 ? Colors.green : const Color(0xFF4338CA),
          ),
        ),
        title: Text(
          progress >= 1.0
              ? '✅ 整理ルーチン完了！'
              : '📋 メール整理ルーチン ($doneCount/${_routineSteps.length})',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: progress < 1.0
            ? LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4338CA)),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              )
            : null,
        initiallyExpanded: progress < 1.0,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: List.generate(_routineSteps.length, (i) {
                return CheckboxListTile(
                  value: _routineChecks[i],
                  onChanged: (v) {
                    setState(() => _routineChecks[i] = v ?? false);
                  },
                  title: Text(
                    _routineSteps[i],
                    style: TextStyle(
                      fontSize: 13,
                      decoration:
                          _routineChecks[i] ? TextDecoration.lineThrough : null,
                      color: _routineChecks[i] ? const Color(0xFF9CA3AF) : null,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'メールアカウントを登録して\n整理リマインダーを設定しましょう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add),
              label: const Text('アカウントを追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📧 $count件のメールアカウントが整理時期です',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '「整理完了」をタップして記録しましょう',
                  style: TextStyle(fontSize: 12, color: const Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final provider = account['provider']?.toString() ?? 'other';
    final email = account['email_address']?.toString() ?? '';
    final label = account['label']?.toString();
    final isActive = account['is_active'] == true;
    final needs = _needsClean(account);
    final daysSince = _daysSinceClean(account);
    final interval = account['clean_interval_days'] as int? ?? 7;
    final lastCleaned = account['last_cleaned_at']?.toString();

    String lastCleanedStr;
    if (lastCleaned == null || lastCleaned.isEmpty) {
      lastCleanedStr = '未実施';
    } else {
      final dt = DateTime.tryParse(lastCleaned);
      lastCleanedStr = dt != null
          ? DateFormat('M/d (E)', 'ja_JP').format(dt.toLocal())
          : '不明';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: needs ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: needs
              ? Colors.orange.shade300
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          width: needs ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _providerColor(provider).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _providerIcon(provider),
                    color: _providerColor(provider),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null && label.isNotEmpty)
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: label != null ? 12 : 14,
                          fontWeight: label != null
                              ? FontWeight.normal
                              : FontWeight.w700,
                          color: label != null ? const Color(0xFF9CA3AF) : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (needs)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '要整理',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepOrange,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '整理済み',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniInfo(
                  '最終整理',
                  lastCleanedStr,
                ),
                const SizedBox(width: 16),
                _buildMiniInfo(
                  '間隔',
                  '$interval日ごと',
                ),
                if (daysSince >= 0) ...[
                  const SizedBox(width: 16),
                  _buildMiniInfo(
                    '経過',
                    '$daysSince日',
                  ),
                ],
                const Spacer(),
                if (isActive)
                  TextButton.icon(
                    onPressed: () => _markCleaned(account),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('整理完了'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _deleteAccount(account);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        '削除',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
