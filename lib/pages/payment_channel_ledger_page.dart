import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_channel.dart';
import '../services/payment_channel_service.dart';

class PaymentChannelLedgerPage extends StatefulWidget {
  const PaymentChannelLedgerPage({super.key});

  @override
  State<PaymentChannelLedgerPage> createState() =>
      _PaymentChannelLedgerPageState();
}

class _PaymentChannelLedgerPageState extends State<PaymentChannelLedgerPage> {
  final PaymentChannelService _paymentChannelService = PaymentChannelService();
  late Future<List<PaymentChannel>> _channelsFuture;

  @override
  void initState() {
    super.initState();
    _channelsFuture = _paymentChannelService.getPaymentChannels();
  }

  String _formatCurrency(double amount, String currency) {
    return NumberFormat.currency(
      locale: currency == 'JPY' ? 'ja_JP' : 'en_US',
      symbol: currency == 'JPY' ? '¥' : '\$',
    ).format(amount);
  }

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Icons.check_circle;
      case TransactionStatus.pending:
        return Icons.hourglass_empty;
      case TransactionStatus.failed:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return Colors.green;
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('決済チャネル台帳'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<PaymentChannel>>(
        future: _channelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('利用可能な決済チャネルがありません。'));
          }

          final channels = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _channelsFuture = _paymentChannelService.getPaymentChannels();
              });
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[100],
                      child: const Icon(Icons.account_balance_wallet,
                          color: Colors.green),
                    ),
                    title: Text(
                      channel.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(channel.description),
                    trailing: Text(
                      _formatCurrency(channel.balance, channel.currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    children: [
                      _buildTransactionList(channel.transactions, channel.currency),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions, String currency) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('このチャネルの取引履歴はありません。')),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('状態')),
          DataColumn(label: Text('日時')),
          DataColumn(label: Text('内容')),
          DataColumn(label: Text('金額'), numeric: true),
        ],
        rows: transactions.map((tx) {
          final isIncoming = tx.type == TransactionType.incoming;
          return DataRow(
            cells: [
              DataCell(
                Icon(
                  _getStatusIcon(tx.status),
                  color: _getStatusColor(tx.status),
                  size: 20,
                ),
              ),
              DataCell(Text(DateFormat('MM/dd HH:mm').format(tx.date))),
              DataCell(Text(tx.description, overflow: TextOverflow.ellipsis)),
              DataCell(
                Text(
                  '${isIncoming ? '+' : '-'} ${_formatCurrency(tx.amount, currency)}',
                  style: TextStyle(
                    color: isIncoming ? Colors.blue : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}