import '../models/payment_channel.dart';

class PaymentChannelService {
  Future<List<PaymentChannel>> getPaymentChannels() async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 1));

    return [
      PaymentChannel(
        id: 'pc_001',
        name: 'Stripe Connect',
        description: '売上入金用のメインチャネル',
        balance: 15200.50,
        currency: 'JPY',
        transactions: [
          Transaction(
              id: 'txn_001',
              date: DateTime.now().subtract(const Duration(days: 1)),
              description: 'オンラインストア売上',
              amount: 5000,
              type: TransactionType.incoming,
              status: TransactionStatus.completed),
          Transaction(
              id: 'txn_002',
              date: DateTime.now().subtract(const Duration(days: 2)),
              description: '開発者への支払い',
              amount: 2500,
              type: TransactionType.outgoing,
              status: TransactionStatus.completed),
          Transaction(
              id: 'txn_003',
              date: DateTime.now().subtract(const Duration(days: 3)),
              description: '広告費用',
              amount: 1000,
              type: TransactionType.outgoing,
              status: TransactionStatus.pending),
        ],
      ),
      PaymentChannel(
        id: 'pc_002',
        name: 'PayPal',
        description: '海外送金・受金用チャネル',
        balance: 850.00,
        currency: 'USD',
        transactions: [
          Transaction(
              id: 'txn_004',
              date: DateTime.now().subtract(const Duration(hours: 5)),
              description: 'デザイン委託料',
              amount: 150,
              type: TransactionType.outgoing,
              status: TransactionStatus.completed),
          Transaction(
              id: 'txn_005',
              date: DateTime.now().subtract(const Duration(days: 4)),
              description: '海外クライアントからの入金',
              amount: 1000,
              type: TransactionType.incoming,
              status: TransactionStatus.completed),
        ],
      ),
      PaymentChannel(
        id: 'pc_003',
        name: '銀行振込 (三菱UFJ)',
        description: '国内取引先への支払い用',
        balance: 500000,
        currency: 'JPY',
        transactions: [
          Transaction(
              id: 'txn_006',
              date: DateTime.now().subtract(const Duration(days: 5)),
              description: 'オフィス賃料',
              amount: 150000,
              type: TransactionType.outgoing,
              status: TransactionStatus.completed),
          Transaction(
              id: 'txn_007',
              date: DateTime.now().subtract(const Duration(days: 10)),
              description: '資本金受入',
              amount: 1000000,
              type: TransactionType.incoming,
              status: TransactionStatus.completed),
          Transaction(
              id: 'txn_008',
              date: DateTime.now().subtract(const Duration(days: 12)),
              description: '税理士報酬',
              amount: 50000,
              type: TransactionType.outgoing,
              status: TransactionStatus.failed),
        ],
      ),
    ];
  }
}
