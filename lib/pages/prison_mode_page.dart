import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/data/repositories/debt_guard_repository.dart';
import 'package:my_web_app/data/services/debt_guard_event_service.dart';
import 'package:my_web_app/view_models/debt_guard_view_model.dart';
import 'package:my_web_app/widgets/debt_guard_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 刑務所モード — 借金完済まで生活を律する
///
/// 借金残高を登録し、完済するまで「収監中」として
/// 毎日のスケジュールを刑務所のように厳格に管理する。
class PrisonModePage extends StatefulWidget {
  const PrisonModePage({super.key});

  @override
  State<PrisonModePage> createState() => _PrisonModePageState();
}

class _PrisonModePageState extends State<PrisonModePage> {
  final _supabase = Supabase.instance.client;
  late final DebtGuardViewModel _debtGuardViewModel;
  bool _loading = true;
  Map<String, dynamic>? _prisonData;
  List<Map<String, dynamic>> _debts = [];
  Set<String> _completedToday = {};

  static const _defaultSchedule = [
    ('06:00', '起床・洗顔・着替え', Icons.wb_sunny),
    ('06:15', '部屋の清掃・ベッドメイク', Icons.cleaning_services),
    ('06:30', '朝食（質素に）', Icons.rice_bowl),
    ('07:00', '朝の点呼（今日のタスク確認）', Icons.checklist),
    ('07:30', '作業開始（最重要タスク）', Icons.work),
    ('10:00', '休憩（10分のみ）', Icons.coffee),
    ('10:10', '作業再開', Icons.work),
    ('12:00', '昼食（30分以内）', Icons.lunch_dining),
    ('12:30', '軽い運動（散歩・ストレッチ）', Icons.directions_walk),
    ('13:00', '午後の作業開始', Icons.work),
    ('15:00', '休憩（10分のみ）', Icons.coffee),
    ('15:10', '作業再開', Icons.work),
    ('17:00', '作業終了・成果記録', Icons.assessment),
    ('17:30', '副業・借金返済のための活動', Icons.attach_money),
    ('19:00', '夕食（質素に）', Icons.dinner_dining),
    ('19:30', 'スキルアップ学習', Icons.school),
    ('20:30', '翌日の計画・振り返り', Icons.edit_note),
    ('21:00', '入浴・身だしなみ', Icons.bathtub),
    ('21:30', '読書（30分）', Icons.menu_book),
    ('22:00', '消灯・就寝', Icons.nightlight),
  ];

  @override
  void initState() {
    super.initState();
    _debtGuardViewModel = DebtGuardViewModel(
      repository: SupabaseDebtGuardRepository(
        service: DebtGuardEventService(client: _supabase),
      ),
      userId: _supabase.auth.currentUser?.id,
    );
    _debtGuardViewModel.load();
    _load();
  }

  @override
  void dispose() {
    _debtGuardViewModel.dispose();
    super.dispose();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _supabase
            .from('prison_mode')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        _supabase
            .from('prison_debts')
            .select()
            .eq('user_id', userId)
            .order('created_at'),
        _supabase
            .from('prison_schedule_logs')
            .select('schedule_key')
            .eq('user_id', userId)
            .eq('completed_date', _todayStr),
      ]);

      final prisonData = results[0] as Map<String, dynamic>?;
      final debts = List<Map<String, dynamic>>.from(
        (results[1] as List?) ?? [],
      );
      final logs = List<Map<String, dynamic>>.from(
        (results[2] as List?) ?? [],
      );

      if (mounted) {
        setState(() {
          _prisonData = prisonData;
          _debts = debts;
          _completedToday =
              logs.map((l) => l['schedule_key']?.toString() ?? '').toSet();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('PrisonMode load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activatePrisonMode() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('prison_mode').upsert({
        'user_id': userId,
        'is_active': true,
        'activated_at': DateTime.now().toIso8601String(),
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _addDebt() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('借金を登録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '借入先',
                hintText: '例: クレジットカード、奨学金',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '残高 (円)',
                hintText: '例: 500000',
                prefixText: '¥',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('登録'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final name = nameCtrl.text.trim();
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (name.isEmpty || amount <= 0) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('prison_debts').insert({
        'user_id': userId,
        'creditor_name': name,
        'original_amount': amount,
        'remaining_amount': amount,
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _recordPayment(Map<String, dynamic> debt) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('返済記録: ${debt['creditor_name']}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '返済額 (円)',
            hintText:
                '残高: ¥${_formatNumber(debt['remaining_amount'] as int? ?? 0)}',
            prefixText: '¥',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('記録'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final payment = int.tryParse(ctrl.text.trim()) ?? 0;
    if (payment <= 0) return;

    final remaining = (debt['remaining_amount'] as int? ?? 0) - payment;
    try {
      await _supabase.from('prison_debts').update({
        'remaining_amount': remaining < 0 ? 0 : remaining,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', debt['id']);
      final otherRemaining =
          _debts.where((item) => item['id'] != debt['id']).fold<int>(
                0,
                (sum, item) => sum + (item['remaining_amount'] as int? ?? 0),
              );
      final isNowPaidOff =
          otherRemaining + (remaining < 0 ? 0 : remaining) <= 0;
      if (isNowPaidOff) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('prison_mode').update({
            'is_active': false,
            'released_at': DateTime.now().toIso8601String(),
          }).eq('user_id', userId);
        }
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¥${_formatNumber(payment)} を返済しました${remaining <= 0 ? " 🎉 完済！" : ""}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _toggleSchedule(String key) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final done = _completedToday.contains(key);
    try {
      if (done) {
        await _supabase
            .from('prison_schedule_logs')
            .delete()
            .eq('user_id', userId)
            .eq('schedule_key', key)
            .eq('completed_date', _todayStr)
            .select();
      } else {
        await _supabase.from('prison_schedule_logs').insert({
          'user_id': userId,
          'schedule_key': key,
          'completed_date': _todayStr,
        });
      }
      await _load();
    } catch (e) {
      debugPrint('Schedule toggle error: $e');
    }
  }

  String _formatNumber(int n) {
    return NumberFormat('#,###').format(n);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _prisonData?['is_active'] == true;
    final totalDebt = _debts.fold<int>(
      0,
      (sum, d) => sum + (d['remaining_amount'] as int? ?? 0),
    );
    final totalOriginal = _debts.fold<int>(
      0,
      (sum, d) => sum + (d['original_amount'] as int? ?? 0),
    );
    final paidOff = totalDebt <= 0 && _debts.isNotEmpty;
    final scheduleCompleted =
        _defaultSchedule.where((s) => _completedToday.contains(s.$1)).length;
    final scheduleProgress = _defaultSchedule.isEmpty
        ? 0.0
        : scheduleCompleted / _defaultSchedule.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isActive ? '🔒 完済ガード中' : '完済ガード'),
        backgroundColor:
            isActive ? Theme.of(context).colorScheme.onSurface : null,
        foregroundColor: isActive ? Colors.white : null,
        elevation: 0,
      ),
      backgroundColor:
          isActive ? Theme.of(context).colorScheme.surfaceContainerHigh : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ステータスカード
                _buildStatusCard(
                  isActive,
                  totalDebt,
                  totalOriginal,
                  paidOff,
                  scheduleProgress,
                ),
                const SizedBox(height: 16),

                if (!isActive) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _activatePrisonMode,
                      icon: const Icon(Icons.lock),
                      label: const Text('刑務所モードを有効にする'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 借金一覧
                _buildSectionTitle('📋 借金台帳'),
                ..._debts.map(_buildDebtCard),
                OutlinedButton.icon(
                  onPressed: _addDebt,
                  icon: const Icon(Icons.add),
                  label: const Text('借金を登録'),
                ),
                const SizedBox(height: 24),

                DebtGuardPanel(
                  viewModel: _debtGuardViewModel,
                  isLocked: isActive && !paidOff && _debts.isNotEmpty,
                  isPaidOff: paidOff,
                ),
                const SizedBox(height: 24),

                // 日課スケジュール
                if (isActive) ...[
                  _buildSectionTitle(
                    '⏰ 本日の日課 ($scheduleCompleted/${_defaultSchedule.length})',
                  ),
                  ..._defaultSchedule.map((s) {
                    final done = _completedToday.contains(s.$1);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: done
                              ? const Color(0xFFA5D6A7)
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          done ? Icons.check_circle : s.$3,
                          color: done
                              ? const Color(0xFF4CAF50)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        title: Text(
                          '${s.$1}  ${s.$2}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done ? const Color(0xFF9CA3AF) : null,
                            height: 1.5,
                          ),
                        ),
                        onTap: () => _toggleSchedule(s.$1),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusCard(
    bool isActive,
    int totalDebt,
    int totalOriginal,
    bool paidOff,
    double scheduleProgress,
  ) {
    final repaidPercent = totalOriginal > 0
        ? ((totalOriginal - totalDebt) / totalOriginal * 100).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: paidOff
              ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
              : isActive
                  ? [
                      Theme.of(context).colorScheme.onSurface,
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ]
                  : [const Color(0xFF455A64), const Color(0xFF607D8B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            paidOff
                ? '🎉'
                : isActive
                    ? '🔒'
                    : '🏛️',
            style: const TextStyle(
              fontSize: 40,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            paidOff
                ? '出所おめでとう！借金完済！'
                : isActive
                    ? '現在収監中'
                    : '刑務所モード',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_debts.isNotEmpty) ...[
            Text(
              '借金残高: ¥${_formatNumber(totalDebt)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '返済率: $repaidPercent% (¥${_formatNumber(totalOriginal - totalDebt)} / ¥${_formatNumber(totalOriginal)})',
              style: TextStyle(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: totalOriginal > 0
                    ? (totalOriginal - totalDebt) / totalOriginal
                    : 0,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  paidOff ? Colors.greenAccent : const Color(0xFFFFC107),
                ),
                minHeight: 8,
              ),
            ),
          ],
          if (isActive && !paidOff) ...[
            const SizedBox(height: 12),
            Text(
              '日課遵守率: ${(scheduleProgress * 100).toInt()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: scheduleProgress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildDebtCard(Map<String, dynamic> debt) {
    final name = debt['creditor_name']?.toString() ?? '';
    final original = debt['original_amount'] as int? ?? 0;
    final remaining = debt['remaining_amount'] as int? ?? 0;
    final paid = original - remaining;
    final progress = original > 0 ? paid / original : 0.0;
    final isPaidOff = remaining <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPaidOff
              ? const Color(0xFF81C784)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPaidOff ? Icons.check_circle : Icons.account_balance,
                  color: isPaidOff
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFC62828),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: isPaidOff ? TextDecoration.lineThrough : null,
                      height: 1.5,
                    ),
                  ),
                ),
                if (!isPaidOff)
                  TextButton(
                    onPressed: () => _recordPayment(debt),
                    child: const Text('返済'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '残高: ¥${_formatNumber(remaining)} / ¥${_formatNumber(original)}',
              style: TextStyle(
                fontSize: 12,
                color: isPaidOff
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFC62828),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(
                  isPaidOff ? const Color(0xFF4CAF50) : const Color(0xFFFFA000),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
