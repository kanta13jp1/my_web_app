import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef PaymentReminderLoader =
    Future<List<Map<String, dynamic>>> Function(String userId);
typedef PaymentReminderInserter =
    Future<void> Function(Map<String, dynamic> payload);
typedef PaymentReminderMarker = Future<bool> Function(
  String userId,
  Map<String, dynamic> reminder,
  DateTime paidAt,
);
typedef PaymentReminderDeleter = Future<bool> Function(
  String userId,
  Object? reminderId,
);

/// 毎月の支払いリマインダーページ。
/// au、家賃、サブスク、保険、税金などの定期支払いを管理する。
class PaymentReminderPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final DateTime Function()? nowProvider;
  final PaymentReminderLoader? loadReminders;
  final PaymentReminderInserter? insertReminder;
  final PaymentReminderMarker? markReminderPaid;
  final PaymentReminderDeleter? deleteReminder;

  const PaymentReminderPage({
    super.key,
    this.supabaseClient,
    this.nowProvider,
    this.loadReminders,
    this.insertReminder,
    this.markReminderPaid,
    this.deleteReminder,
  });

  static int? safeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      return int.tryParse(cleaned);
    }
    return null;
  }

  static bool isPaidInMonth(Map<String, dynamic> reminder, DateTime now) {
    final lastPaid = reminder['last_paid_at']?.toString();
    if (lastPaid == null || lastPaid.isEmpty) return false;
    final parsed = DateTime.tryParse(lastPaid);
    if (parsed == null) return false;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return local.year == now.year && local.month == now.month;
  }

  static bool isDueSoon(Map<String, dynamic> reminder, DateTime now) {
    if (reminder['is_active'] != true) return false;
    if (isPaidInMonth(reminder, now)) return false;
    final dueDay = (safeInt(reminder['due_day']) ?? 1).clamp(1, 31);
    final diff = dueDay - now.day;
    return diff >= 0 && diff <= 3;
  }

  static bool isOverdue(Map<String, dynamic> reminder, DateTime now) {
    if (reminder['is_active'] != true) return false;
    if (isPaidInMonth(reminder, now)) return false;
    final dueDay = (safeInt(reminder['due_day']) ?? 1).clamp(1, 31);
    return now.day > dueDay;
  }

  @override
  State<PaymentReminderPage> createState() => _PaymentReminderPageState();
}

class _PaymentReminderPageState extends State<PaymentReminderPage> {
  bool _loading = true;
  bool _requiresLogin = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _reminders = <Map<String, dynamic>>[];
  final Set<String> _payingIds = <String>{};

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  DateTime _now() => (widget.nowProvider ?? DateTime.now)();

  static const _categories = <(String, String, IconData, Color)>[
    ('telecom', '通信', Icons.phone_android, Color(0xFFE91E63)),
    ('rent', '家賃', Icons.home, Color(0xFF795548)),
    ('utility', '光熱費', Icons.bolt, Color(0xFFFF9800)),
    ('subscription', 'サブスク', Icons.subscriptions, Color(0xFF9C27B0)),
    ('insurance', '保険', Icons.health_and_safety, Color(0xFF4CAF50)),
    ('tax', '税金', Icons.account_balance, Color(0xFF607D8B)),
    ('loan', 'ローン', Icons.credit_card, Color(0xFFF44336)),
    ('other', 'その他', Icons.payments, Color(0xFF2196F3)),
  ];

  static const _paymentMethods = <String>[
    '口座引落',
    'クレジットカード',
    '銀行振込',
    'コンビニ払い',
    'PayPay',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _defaultLoad(String userId) async {
    final rows = await _supabase
        .from('payment_reminders')
        .select()
        .eq('user_id', userId)
        .order('due_day');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _requiresLogin = false;
      _errorMessage = null;
    });

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _reminders = <Map<String, dynamic>>[];
        _loading = false;
      });
      return;
    }

    try {
      final loader = widget.loadReminders ?? _defaultLoad;
      final rows = await loader(userId);
      if (!mounted) return;
      setState(() {
        _reminders = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('PaymentReminderPage load error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '支払いリマインダーの読み込みに失敗しました。';
        _loading = false;
      });
    }
  }

  IconData _categoryIcon(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$3;
    }
    return Icons.payments;
  }

  Color _categoryColor(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$4;
    }
    return const Color(0xFF2196F3);
  }

  String _categoryLabel(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$2;
    }
    return 'その他';
  }

  Future<void> _defaultInsert(Map<String, dynamic> payload) async {
    await _supabase.from('payment_reminders').insert(payload);
  }

  Future<bool> _defaultMarkPaid(
    String userId,
    Map<String, dynamic> reminder,
    DateTime paidAt,
  ) async {
    final reminderId = reminder['id']?.toString() ?? '';
    if (reminderId.isEmpty) return false;

    final updated = await _supabase
        .from('payment_reminders')
        .update(<String, dynamic>{
          'last_paid_at': paidAt.toIso8601String(),
          'updated_at': paidAt.toIso8601String(),
        })
        .eq('id', reminderId)
        .eq('user_id', userId)
        .select('id');
    if (updated.isEmpty) return false;

    await _supabase.from('payment_logs').insert(<String, dynamic>{
      'user_id': userId,
      'reminder_id': reminderId,
      'paid_at': paidAt.toIso8601String(),
      'amount': PaymentReminderPage.safeInt(reminder['amount']),
    });
    return true;
  }

  Future<bool> _defaultDelete(String userId, Object? reminderId) async {
    if (reminderId == null) return false;
    final deleted = await _supabase
        .from('payment_reminders')
        .delete()
        .eq('id', reminderId)
        .eq('user_id', userId)
        .select('id');
    return deleted.isNotEmpty;
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _addReminder() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('支払いを追加するにはログインしてください。');
      return;
    }

    final input = await showDialog<_NewReminderInput>(
      context: context,
      builder: (_) => const _AddReminderDialog(
        categories: _categories,
        paymentMethods: _paymentMethods,
      ),
    );
    if (input == null) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _showSnack('支払いを追加するにはログインしてください。');
      return;
    }

    try {
      final inserter = widget.insertReminder ?? _defaultInsert;
      await inserter(<String, dynamic>{
        'user_id': currentUserId,
        'title': input.title,
        'amount': input.amount,
        'payee': input.payee,
        'payment_method': input.paymentMethod,
        'category': input.category,
        'due_day': input.dueDay,
        'is_auto_pay': input.isAutoPay,
        'note': input.note,
      });
      if (!mounted) return;
      await _load();
      _showSnack('支払いリマインダーを追加しました');
    } catch (e) {
      _showSnack(
        '追加に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  Future<void> _markPaid(Map<String, dynamic> reminder) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('ログインしてから記録してください。');
      return;
    }

    final reminderId = reminder['id']?.toString() ?? '';
    if (reminderId.isEmpty || _payingIds.contains(reminderId)) return;

    setState(() => _payingIds.add(reminderId));
    try {
      final marker = widget.markReminderPaid ?? _defaultMarkPaid;
      final saved = await marker(userId, reminder, _now());
      if (!mounted) return;
      if (!saved) {
        _showSnack(
          '支払いの記録を保存できませんでした。画面を更新してもう一度お試しください。',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }
      await _load();
      _showSnack(
        '支払い完了を記録しました',
        backgroundColor: const Color(0xFF2E7D32),
      );
    } catch (e) {
      _showSnack(
        '記録の保存に失敗しました。再試行してください。',
        backgroundColor: const Color(0xFFE53935),
      );
    } finally {
      if (mounted) {
        setState(() => _payingIds.remove(reminderId));
      }
    }
  }

  Future<void> _deleteReminder(Map<String, dynamic> reminder) async {
    final title = reminder['title']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('リマインダーを削除'),
        content: Text('「$title」を削除しますか？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('削除するにはログインしてください。');
      return;
    }

    try {
      final deleter = widget.deleteReminder ?? _defaultDelete;
      final deleted = await deleter(userId, reminder['id']);
      if (!mounted) return;
      if (!deleted) {
        _showSnack(
          '削除対象が見つからず、削除できませんでした。',
          backgroundColor: const Color(0xFFE53935),
        );
        return;
      }
      await _load();
    } catch (e) {
      _showSnack(
        '削除に失敗しました。再試行してください。',
        backgroundColor: const Color(0xFFE53935),
      );
    }
  }

  int get _monthlyTotal {
    var total = 0;
    for (final r in _reminders) {
      if (r['is_active'] == true) {
        total += PaymentReminderPage.safeInt(r['amount']) ?? 0;
      }
    }
    return total;
  }

  void _openLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final dueSoon = _reminders
        .where(
          (r) =>
              PaymentReminderPage.isDueSoon(r, now) ||
              PaymentReminderPage.isOverdue(r, now),
        )
        .toList();
    final fmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: const Text('支払いリマインダー'),
        elevation: 0,
        actions: <Widget>[
          if (!_requiresLogin)
            IconButton(
              key: const Key('payment_reminder_appbar_add_button'),
              tooltip: '支払いを追加',
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: _buildBody(fmt, dueSoon, now),
    );
  }

  Widget _buildBody(
    NumberFormat fmt,
    List<Map<String, dynamic>> dueSoon,
    DateTime now,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requiresLogin) {
      return _buildSignedOutState();
    }
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }
    if (_reminders.isEmpty) {
      return _buildEmptyState();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: <Widget>[
          _buildSummaryCard(fmt),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('payment_reminder_list_add_button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
              label: const Text('支払いを追加'),
            ),
          ),
          if (dueSoon.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _buildDueSoonBanner(dueSoon.length),
          ],
          const SizedBox(height: 16),
          ..._reminders.map((r) => _buildReminderCard(r, fmt, now)),
        ],
      ),
    );
  }

  Widget _buildSignedOutState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('payment_reminder_signed_out_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 56,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'ログインすると毎月の支払いを管理できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _openLogin,
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('payment_reminder_error_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '毎月の支払いを登録して\n忘れずにリマインドしましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
              label: const Text('支払いを追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat fmt) {
    final activeCount = _reminders.where((r) => r['is_active'] == true).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF283593), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '毎月の固定支出',
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                Text(
                  '¥${fmt.format(_monthlyTotal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$activeCount件',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueSoonBanner(int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg =
        isDark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEE);
    final bannerFg =
        isDark ? const Color(0xFFFFCDD2) : const Color(0xFF7F1D1D);
    final iconColor =
        isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('payment_reminder_due_soon_banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF9A9A)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_amber, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count件の支払いが期日間近・超過です',
                style: TextStyle(
                  color: bannerFg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(
    Map<String, dynamic> r,
    NumberFormat fmt,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final id = r['id']?.toString() ?? '';
    final cat = r['category']?.toString() ?? 'other';
    final title = r['title']?.toString() ?? '';
    final amount = PaymentReminderPage.safeInt(r['amount']);
    final dueDay = (PaymentReminderPage.safeInt(r['due_day']) ?? 1).clamp(
      1,
      31,
    );
    final payee = r['payee']?.toString();
    final method = r['payment_method']?.toString();
    final isAuto = r['is_auto_pay'] == true;
    final note = r['note']?.toString();
    final paidInMonth = PaymentReminderPage.isPaidInMonth(r, now);
    final overdue = PaymentReminderPage.isOverdue(r, now);
    final dueSoon = PaymentReminderPage.isDueSoon(r, now);
    final isPaying = id.isNotEmpty && _payingIds.contains(id);

    final borderColor = overdue
        ? const Color(0xFFE57373)
        : (dueSoon
            ? const Color(0xFFFFB74D)
            : colorScheme.surfaceContainerHigh);
    final borderWidth = overdue || dueSoon ? 1.5 : 1.0;

    final autoBg = isDark ? const Color(0xFF162447) : const Color(0xFFE8EEFF);
    final autoFg = isDark ? const Color(0xFFBAC8FF) : const Color(0xFF1E3A8A);
    final completeColor =
        isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: overdue ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _categoryColor(cat).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcon(cat),
                    color: _categoryColor(cat),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          if (isAuto)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: autoBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '自動',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: autoFg,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (payee != null && payee.isNotEmpty)
                        Text(
                          payee,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (amount != null)
                      Text(
                        '¥${fmt.format(amount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                    Text(
                      '毎月$dueDay日',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (method != null && method.isNotEmpty)
                  _buildMiniTag(
                    method,
                    colorScheme.surfaceContainerHigh,
                    colorScheme.onSurface,
                  ),
                _buildMiniTag(
                  _categoryLabel(cat),
                  _categoryColor(cat).withValues(alpha: 0.14),
                  colorScheme.onSurface,
                ),
                if (paidInMonth) _buildPaidStatusChip(isDark),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    softWrap: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                if (overdue || dueSoon)
                  TextButton.icon(
                    onPressed: isPaying ? null : () => _markPaid(r),
                    style: TextButton.styleFrom(
                      foregroundColor: completeColor,
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    icon: isPaying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, size: 18),
                    label: Text(isPaying ? '記録中...' : '支払い完了'),
                  ),
                PopupMenuButton<String>(
                  tooltip: '$title のメニュー',
                  onSelected: (v) {
                    if (v == 'paid') _markPaid(r);
                    if (v == 'delete') _deleteReminder(r);
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'paid',
                      child: Text('支払い完了'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        '削除',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
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

  Widget _buildPaidStatusChip(bool isDark) {
    final bg = isDark ? const Color(0xFF14331A) : const Color(0xFFE8F5E9);
    final fg = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '今月支払い済み',
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          height: 1.4,
        ),
      ),
    );
  }
}

class _NewReminderInput {
  final String title;
  final int? amount;
  final String? payee;
  final String paymentMethod;
  final String category;
  final int dueDay;
  final bool isAutoPay;
  final String? note;

  const _NewReminderInput({
    required this.title,
    required this.amount,
    required this.payee,
    required this.paymentMethod,
    required this.category,
    required this.dueDay,
    required this.isAutoPay,
    required this.note,
  });
}

class _AddReminderDialog extends StatefulWidget {
  final List<(String, String, IconData, Color)> categories;
  final List<String> paymentMethods;

  const _AddReminderDialog({
    required this.categories,
    required this.paymentMethods,
  });

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _selectedCategory = 'telecom';
  String _selectedMethod = '口座引落';
  int _dueDay = 25;
  bool _isAutoPay = false;
  String? _titleError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _payeeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '支払い名を入力してください');
      return;
    }
    final amountText = _amountCtrl.text.trim().replaceAll(',', '');
    final payeeText = _payeeCtrl.text.trim();
    final noteText = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      _NewReminderInput(
        title: title,
        amount: amountText.isEmpty ? null : int.tryParse(amountText),
        payee: payeeText.isEmpty ? null : payeeText,
        paymentMethod: _selectedMethod,
        category: _selectedCategory,
        dueDay: _dueDay,
        isAutoPay: _isAutoPay,
        note: noteText.isEmpty ? null : noteText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('支払いリマインダー追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: '支払い名 *',
                hintText: 'au携帯料金、家賃、Netflix など',
                errorText: _titleError,
                prefixIcon: const Icon(Icons.label),
              ),
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: '金額 (円)',
                hintText: '10000',
                prefixIcon: Icon(Icons.currency_yen),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _payeeCtrl,
              decoration: const InputDecoration(
                labelText: '振込先・支払先',
                hintText: 'KDDI、不動産会社 など',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                prefixIcon: Icon(Icons.category),
              ),
              items: widget.categories.map((c) {
                return DropdownMenuItem<String>(
                  value: c.$1,
                  child: Row(
                    children: <Widget>[
                      Icon(c.$3, size: 18, color: c.$4),
                      const SizedBox(width: 8),
                      Text(c.$2),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedCategory = v);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _dueDay,
              decoration: const InputDecoration(
                labelText: '毎月の支払日',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: List<int>.generate(31, (i) => i + 1).map((d) {
                return DropdownMenuItem<int>(
                  value: d,
                  child: Text('$d日'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _dueDay = v);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(
                labelText: '支払方法',
                prefixIcon: Icon(Icons.payment),
              ),
              items: widget.paymentMethods.map((m) {
                return DropdownMenuItem<String>(
                  value: m,
                  child: Text(m),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedMethod = v);
                }
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('自動引落し'),
              subtitle: const Text('口座引落やカード自動払いの場合'),
              value: _isAutoPay,
              onChanged: (v) => setState(() => _isAutoPay = v),
              contentPadding: EdgeInsets.zero,
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ',
                hintText: '契約番号、お客様番号 など',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('追加'),
        ),
      ],
    );
  }
}
