class PaymentSource {
  final String id;
  final String name;
  final DateTime? lastAuditedAt;

  PaymentSource({
    required this.id,
    required this.name,
    this.lastAuditedAt,
  });

  factory PaymentSource.fromMap(Map<String, dynamic> map) {
    return PaymentSource(
      id: map['id'] as String,
      name: map['name'] as String,
      lastAuditedAt: map['last_audited_at'] == null
          ? null
          : DateTime.parse(map['last_audited_at'] as String),
    );
  }
}
