/// 債権者連絡テンプレート種別 (#3292 / #3288)。
enum CreditorContactTemplateKind {
  changeDueDate,
  reduceMinimum,
  installmentOrGrace;

  String get label => switch (this) {
        CreditorContactTemplateKind.changeDueDate => '支払日変更',
        CreditorContactTemplateKind.reduceMinimum => '最低額減額',
        CreditorContactTemplateKind.installmentOrGrace => '分割・一時猶予',
      };
}

/// 債権者への連絡チャネル (#3292 / #3288)。
enum CreditorContactChannel {
  phone,
  email,
  webForm,
  chat;

  String get label => switch (this) {
        CreditorContactChannel.phone => '電話',
        CreditorContactChannel.email => 'メール',
        CreditorContactChannel.webForm => 'Webフォーム',
        CreditorContactChannel.chat => 'チャット',
      };
}

/// 債権者への連絡・合意記録 (#3292 / #3288)。
class CreditorContactLog {
  final String id;
  final String accountId;
  final String accountName;
  final DateTime contactedAt;
  final CreditorContactChannel channel;
  final CreditorContactTemplateKind templateKind;
  final String representative;
  final String agreedSummary;
  final DateTime? nextFollowUpDate;
  final String note;

  const CreditorContactLog({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.contactedAt,
    required this.channel,
    required this.templateKind,
    this.representative = '',
    this.agreedSummary = '',
    this.nextFollowUpDate,
    this.note = '',
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'account_id': accountId,
        'account_name': accountName,
        'contacted_at': contactedAt.toIso8601String(),
        'channel': channel.name,
        'template_kind': templateKind.name,
        'representative': representative,
        'agreed_summary': agreedSummary,
        'next_follow_up_date': nextFollowUpDate?.toIso8601String(),
        'note': note,
      };

  static CreditorContactLog? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final accountId = json['account_id']?.toString().trim() ??
        json['accountId']?.toString().trim() ??
        '';
    final accountName = json['account_name']?.toString().trim() ??
        json['accountName']?.toString().trim() ??
        '';
    final contactedAtText =
        json['contacted_at']?.toString() ?? json['contactedAt']?.toString();
    final contactedAt =
        contactedAtText == null ? null : DateTime.tryParse(contactedAtText);
    if (id.isEmpty || accountId.isEmpty || contactedAt == null) {
      return null;
    }

    final channelName = json['channel']?.toString().trim() ?? 'phone';
    final channel = CreditorContactChannel.values.firstWhere(
      (item) => item.name == channelName,
      orElse: () => CreditorContactChannel.phone,
    );

    final templateName = json['template_kind']?.toString().trim() ??
        json['templateKind']?.toString().trim() ??
        'changeDueDate';
    final templateKind = CreditorContactTemplateKind.values.firstWhere(
      (item) => item.name == templateName,
      orElse: () => CreditorContactTemplateKind.changeDueDate,
    );

    final followUpText = json['next_follow_up_date']?.toString() ??
        json['nextFollowUpDate']?.toString();
    final followUpDate =
        followUpText == null ? null : DateTime.tryParse(followUpText);

    return CreditorContactLog(
      id: id,
      accountId: accountId,
      accountName: accountName.isEmpty ? accountId : accountName,
      contactedAt: contactedAt,
      channel: channel,
      templateKind: templateKind,
      representative: json['representative']?.toString() ?? '',
      agreedSummary: json['agreed_summary']?.toString() ??
          json['agreedSummary']?.toString() ??
          '',
      nextFollowUpDate: followUpDate,
      note: json['note']?.toString() ?? '',
    );
  }
}

/// 債権者連絡タスクの進行状態 (#3288)。
enum CreditorContactTaskStatus {
  pending,
  contacted;

  String get label => switch (this) {
        CreditorContactTaskStatus.pending => '未連絡',
        CreditorContactTaskStatus.contacted => '連絡済み',
      };
}

/// 期限超過・高金利先に対する債権者連絡タスク (#3288)。
class CreditorContactTask {
  final String accountId;
  final String accountName;
  final DateTime? dueDate;
  final double annualRate;
  final double scheduledPaymentAmount;
  final bool isOverdue;
  final bool isHighInterest;
  final CreditorContactTaskStatus status;
  final DateTime? contactedAt;
  final DateTime? nextFollowUpDate;
  final String note;
  final CreditorContactLog? latestLog;

  const CreditorContactTask({
    required this.accountId,
    required this.accountName,
    required this.dueDate,
    required this.annualRate,
    required this.scheduledPaymentAmount,
    required this.isOverdue,
    required this.isHighInterest,
    required this.status,
    this.contactedAt,
    this.nextFollowUpDate,
    this.note = '',
    this.latestLog,
  });

  bool get isContacted => status == CreditorContactTaskStatus.contacted;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'account_id': accountId,
        'account_name': accountName,
        'due_date': dueDate?.toIso8601String(),
        'annual_rate': annualRate,
        'scheduled_payment_amount': scheduledPaymentAmount,
        'is_overdue': isOverdue,
        'is_high_interest': isHighInterest,
        'status': status.name,
        'contacted_at': contactedAt?.toIso8601String(),
        'next_follow_up_date': nextFollowUpDate?.toIso8601String(),
        'note': note,
        'contact_log_id': latestLog?.id,
      };
}

/// 次回期日前に前回合意内容を表示するためのリマインダー (#3292)。
class CreditorContactReminder {
  final String accountId;
  final String accountName;
  final DateTime? dueDate;
  final DateTime? nextFollowUpDate;
  final String agreedSummary;
  final int daysUntilReminder;
  final bool isUrgent;

  const CreditorContactReminder({
    required this.accountId,
    required this.accountName,
    required this.dueDate,
    required this.nextFollowUpDate,
    required this.agreedSummary,
    required this.daysUntilReminder,
    required this.isUrgent,
  });
}
