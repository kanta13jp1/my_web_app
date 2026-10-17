import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hub_data_parsing.dart';
import '../models/parking_reservation_entry.dart';

/// 駐車場予約ページ
/// parking-reservation Edge Function と連携して駐車場の予約を管理
class ParkingReservationPage extends StatefulWidget {
  const ParkingReservationPage({super.key});

  @override
  State<ParkingReservationPage> createState() => _ParkingReservationPageState();
}

class _ParkingReservationPageState extends State<ParkingReservationPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<ParkingReservationEntry> _reservations = [];

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  Future<void> _fetchReservations() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'parking.list'},
      );
      setState(
        () => _reservations =
            ParkingReservationEntry.listFromResponse(response.data),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '予約一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('駐車場予約'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReservations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReservations,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _reservations.isEmpty
                  ? const Center(child: Text('予約はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reservations.length,
                      itemBuilder: (context, index) {
                        final res = _reservations[index];
                        final spotName = res.spotLabel.isNotEmpty
                            ? res.spotLabel
                            : 'スポット ${index + 1}';
                        final timeRange = res.timeRangeLabel;
                        final feeLabel =
                            res.fee != null ? '¥${res.fee}' : '予約済み';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.local_parking,
                              color: Color(0xFF3D5AFE),
                            ),
                            title: Text(
                              spotName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              timeRange.isNotEmpty ? timeRange : '予約済み',
                            ),
                            trailing: Chip(
                              label: Text(
                                feeLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReserveDialog,
        icon: const Icon(Icons.add),
        label: const Text('新規予約'),
      ),
    );
  }

  Future<void> _openReserveDialog() async {
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約を記録するにはログインしてください')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ParkingReserveDialog(),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約を記録しました')),
      );
      await _fetchReservations();
    }
  }
}

/// `parking.reserve` で予約内容を記録するダイアログ。保存成功で true を返す。
class _ParkingReserveDialog extends StatefulWidget {
  const _ParkingReserveDialog();

  @override
  State<_ParkingReserveDialog> createState() => _ParkingReserveDialogState();
}

class _ParkingReserveDialogState extends State<_ParkingReserveDialog> {
  final _lotController = TextEditingController();
  final _spotController = TextEditingController();
  final _plateController = TextEditingController();
  final _feeController = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 次の正時から 1 時間を初期値にする。
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
    _end = _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _lotController.dispose();
    _spotController.dispose();
    _plateController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        final duration = _end.difference(_start);
        _start = picked;
        // 開始を動かしたら長さを保ったまま終了も追従させる。
        _end = picked.add(duration.isNegative ? Duration.zero : duration);
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    final draft = ParkingReservationDraft(
      lotName: _lotController.text,
      spot: _spotController.text,
      start: _start,
      end: _end,
      plate: _plateController.text,
      feeText: _feeController.text,
    );
    final error = draft.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'lifestyle-hub',
        body: draft.toRequestBody(),
      );
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(data is Map ? data['error'] ?? data : data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '記録に失敗しました: $e';
        });
      }
    }
  }

  String _format(DateTime dt) =>
      hubFormatTimestamp(dt.toUtc().toIso8601String());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('駐車場の予約を記録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '駐車場アプリや電話で取った予約の内容を控えておけます'
              '（ここから駐車場へ予約は送信されません）。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lotController,
              decoration: const InputDecoration(
                labelText: '駐車場名 *',
                hintText: '例: 駅前タイムズ第2',
              ),
            ),
            TextField(
              controller: _spotController,
              decoration: const InputDecoration(
                labelText: '区画番号',
                hintText: '例: A-3',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.login),
              title: const Text('開始'),
              subtitle: Text(_format(_start)),
              onTap: _saving ? null : () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('終了'),
              subtitle: Text(_format(_end)),
              onTap: _saving ? null : () => _pickDateTime(isStart: false),
            ),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: '車両ナンバー'),
            ),
            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '料金 (円)',
                hintText: '未定なら空欄',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? '記録中…' : '記録する'),
        ),
      ],
    );
  }
}
