import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新規予約機能は準備中です')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新規予約'),
      ),
    );
  }
}
