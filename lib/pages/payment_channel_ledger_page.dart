import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/payment_source.dart';
import '../services/cfo_service.dart';

class PaymentChannelLedgerPage extends StatefulWidget {
  const PaymentChannelLedgerPage({super.key});

  @override
  State<PaymentChannelLedgerPage> createState() =>
      _PaymentChannelLedgerPageState();
}

class _PaymentChannelLedgerPageState extends State<PaymentChannelLedgerPage> {
  final CfoService _cfoService = CfoService();
  late Future<List<PaymentSource>> _sourcesFuture;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    _sourcesFuture = _cfoService.getPaymentSources();
  }

  void _refreshSources() {
    setState(() {
      _sourcesFuture = _cfoService.getPaymentSources();
    });
  }

  Future<void> _auditSource(String id) async {
    try {
      await _cfoService.auditPaymentSource(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('監査済みにマークしました。'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshSources();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('監査処理中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('決済ソース台帳'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<PaymentSource>>(
        future: _sourcesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Supabaseからのエラーメッセージを具体的に表示
            final error = snapshot.error;
            String errorMessage = 'エラーが発生しました。';
            if (error is Exception) {
              // PostgrestExceptionなどのSupabase固有の例外を考慮
              // For simplicity, converting error to string. In a real app, parse it.
              errorMessage = error.toString();
            }
            return Center(child: Text(errorMessage));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('決済ソースが登録されていません。'));
          }

          final sources = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshSources(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                final isAuditedRecently = source.lastAuditedAt != null &&
                    DateTime.now().difference(source.lastAuditedAt!).inDays <
                        30;
                final auditStatusColor =
                    isAuditedRecently ? Colors.green : Colors.orange;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: auditStatusColor, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: auditStatusColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '最終監査:',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (source.lastAuditedAt != null)
                              Text(
                                timeago.format(
                                  source.lastAuditedAt!,
                                  locale: 'ja',
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: auditStatusColor,
                                ),
                              )
                            else
                              const Text(
                                '未監査',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('監査済みにする'),
                            onPressed: () => _auditSource(source.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[700],
                              side: BorderSide(color: Colors.green[700]!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
