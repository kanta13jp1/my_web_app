import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 休暇・休職管理ページ
/// leave-management Edge Function と連携して休暇申請・承認を管理
class LeaveManagementPage extends StatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  State<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends State<LeaveManagementPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _leaves = [];
  final _reasonCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _leaveType = '有給休暇';

  static const _leaveTypes = ['有給休暇', '病気休暇', '慶弔休暇', '育児休暇', 'その他'];

  @override
  void initState() {
    super.initState();
    _fetchLeaves();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaves() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions
          .invoke('enterprise-hub', body: {'action': 'leave.list'});
      final data = response.data;
      if (data is Map<String, dynamic> && data['requests'] is List) {
        setState(
          () =>
              _leaves = (data['requests'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _leaves = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '休暇一覧の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitLeave() async {
    if (_startDate == null || _endDate == null || _reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('開始日・終了日・理由を入力してください')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'leave.request',
          'type': _leaveType,
          'start_date': _startDate!.toIso8601String().substring(0, 10),
          'end_date': _endDate!.toIso8601String().substring(0, 10),
          'reason': _reasonCtrl.text,
        },
      );
      _reasonCtrl.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _leaveType = '有給休暇';
      });
      await _fetchLeaves();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('休暇申請を提出しました')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '申請に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case '承認':
        return Colors.green;
      case '却下':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('休暇管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeaves,
          ),
        ],
      ),
      body: Column(
        children: [
          // 申請フォーム
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '休暇申請',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _leaveType,
                    decoration: const InputDecoration(
                      labelText: '休暇種別',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _leaveTypes
                        .map(
                          (t) => DropdownMenuItem(value: t, child: Text(t)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _leaveType = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _startDate == null
                                ? '開始日を選択'
                                : _startDate!
                                    .toIso8601String()
                                    .substring(0, 10),
                          ),
                          onPressed: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _endDate == null
                                ? '終了日を選択'
                                : _endDate!.toIso8601String().substring(0, 10),
                          ),
                          onPressed: () => _pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: '申請理由',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitLeave,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('申請する'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // エラー表示
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          // 申請一覧
          Expanded(
            child: _isLoading && _leaves.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _leaves.isEmpty
                    ? const Center(child: Text('休暇申請はありません'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _leaves.length,
                        itemBuilder: (context, i) {
                          final leave = _leaves[i];
                          final status = leave['status'] as String? ?? '審査中';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _statusColor(status).withAlpha(30),
                                child: Icon(
                                  Icons.beach_access,
                                  color: _statusColor(status),
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '${leave['leave_type'] ?? '-'}  '
                                '${leave['start_date'] ?? '-'} 〜 ${leave['end_date'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              subtitle: Text(
                                leave['reason'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              trailing: Chip(
                                label: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _statusColor(status),
                                    height: 1.5,
                                  ),
                                ),
                                backgroundColor:
                                    _statusColor(status).withAlpha(20),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
