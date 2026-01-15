enum TransactionType {
  incoming,
  outgoing,
}

enum TransactionStatus {
  pending,
  completed,
  failed,
}

class Transaction {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.status,
  });
}

class PaymentChannel {
  final String id;
  final String name;
  final String description;
  final double balance;
  final String currency;
  final List<Transaction> transactions;

  PaymentChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.balance,
    required this.currency,
    required this.transactions,
  });
}
