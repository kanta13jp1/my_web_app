import 'package:supabase_flutter/supabase_flutter.dart';
import 'asset_payroll_deductions.dart';

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    });
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

bool _same(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _same(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_same(left[index], right[index])) return false;
    }
    return true;
  }
  return false;
}

class PayslipReviewSnapshot {
  PayslipReviewSnapshot(Map<String, dynamic> source)
      : raw = _freeze(source) as Map<String, dynamic> {
    if (id.isEmpty ||
        ownerId.isEmpty ||
        version.isEmpty ||
        projection == null) {
      throw const FormatException('Incomplete payslip review identity');
    }
  }
  final Map<String, dynamic> raw;
  String get id => raw['id'] as String? ?? '';
  String get ownerId => raw['user_id'] as String? ?? '';
  String get version => raw['updated_at'] as String? ?? '';
  String get status => raw['review_status'] as String? ?? 'unknown';
  PayrollDeductions? get projection => PayrollDeductions.fromRow(raw);
  bool get unreviewed => status == 'auto' || status == 'needs_review';
  String? get blockingReason {
    final row = projection;
    if (!unreviewed) {
      return status == 'confirmed' ? '現在は本人確認済みです。' : 'この確認状態では保存できません。';
    }
    if (row == null) return '明細の識別や日付が不完全です。';
    if (row.conflictingPensionAliases) return '厚生年金の項目名違いが競合しています。元値の訂正が必要です。';
    if (row.socialMismatchYen != null && row.socialMismatchYen != 0) {
      return '社会保険の記載合計と既知内訳が一致しません。元値の訂正が必要です。';
    }
    return null;
  }

  Map<String, dynamic> get original => Map.fromEntries(
        raw.entries.where(
          (entry) => entry.key != 'updated_at' && entry.key != 'review_status',
        ),
      );
  bool sameOriginal(PayslipReviewSnapshot other) =>
      _same(original, other.original);
  bool sameVersion(PayslipReviewSnapshot other) =>
      version == other.version && status == other.status && sameOriginal(other);
}

String payslipPrivateObjectPath(String source, String ownerId) {
  final path = source.startsWith('payslips/')
      ? source.substring('payslips/'.length)
      : source;
  if (ownerId.isEmpty ||
      !path.startsWith('$ownerId/') ||
      path.split('/').any((part) {
        final decoded = Uri.decodeComponent(part);
        return decoded.isEmpty ||
            decoded == '.' ||
            decoded == '..' ||
            decoded.contains('/') ||
            decoded.contains(r'\');
      })) {
    throw const FormatException('Private payslip source is unavailable');
  }
  return path;
}

abstract class PayslipReviewStore {
  String get ownerId;
  bool get isCurrentOwner;
  Stream<void> get ownerChanges;
  Future<PayslipReviewSnapshot> load(String id);
  Future<void> confirm(
    PayslipReviewSnapshot expected, {
    required bool confirmedDisplayedValues,
  });
  Future<Uri> originalPdf(PayslipReviewSnapshot expected);
}

class SupabasePayslipReviewStore implements PayslipReviewStore {
  SupabasePayslipReviewStore(this.client, this.ownerId);
  final SupabaseClient client;
  @override
  final String ownerId;
  @override
  bool get isCurrentOwner =>
      ownerId.isNotEmpty && client.auth.currentUser?.id == ownerId;
  @override
  Stream<void> get ownerChanges =>
      client.auth.onAuthStateChange.map<void>((_) {});
  void _checkOwner() {
    if (!isCurrentOwner) throw StateError('利用者が切り替わりました。明細を開き直してください。');
  }

  static const columns =
      'id,user_id,pay_date,company_name,gross_amount,net_amount,taxable_amount,social_insurance_total,deductions,earnings,attendance,source_pdf_path,parsed_by,confidence,raw_text_sha256,review_status,created_at,updated_at';

  @override
  Future<PayslipReviewSnapshot> load(String id) async {
    _checkOwner();
    if (id.trim().isEmpty) throw ArgumentError('Payslip identity required');
    final row = await client
        .from('payslips')
        .select(columns)
        .eq('user_id', ownerId)
        .eq('id', id)
        .maybeSingle();
    _checkOwner();
    if (row == null || row['user_id'] != ownerId || row['id'] != id) {
      throw StateError('本人の明細を取得できませんでした。');
    }
    return PayslipReviewSnapshot(row);
  }

  @override
  Future<void> confirm(
    PayslipReviewSnapshot expected, {
    required bool confirmedDisplayedValues,
  }) async {
    _checkOwner();
    if (!confirmedDisplayedValues ||
        expected.ownerId != ownerId ||
        expected.blockingReason != null) {
      throw StateError('元明細の記載内容を明示確認してください。');
    }
    final current = await load(expected.id);
    if (!expected.sameVersion(current)) {
      throw StateError('元値または確認状態が変わりました。再取得して照合してください。');
    }
    _checkOwner();
    var query = client
        .from('payslips')
        .update({'review_status': 'confirmed'})
        .eq('user_id', ownerId)
        .eq('id', expected.id)
        .eq('updated_at', expected.version)
        .eq('review_status', expected.status);
    final hash = expected.raw['raw_text_sha256'];
    query = hash == null
        ? query.isFilter('raw_text_sha256', null)
        : query.eq('raw_text_sha256', hash);
    final row = await query.select(columns).maybeSingle();
    _checkOwner();
    if (row == null) throw StateError('更新が競合しました。現在状態を照合してください。');
    final returned = PayslipReviewSnapshot(row);
    if (returned.status != 'confirmed' || !expected.sameOriginal(returned)) {
      throw StateError('保存結果が不明です。現在状態を照合してください。');
    }
  }

  @override
  Future<Uri> originalPdf(PayslipReviewSnapshot expected) async {
    _checkOwner();
    if (expected.ownerId != ownerId) throw StateError('Owner mismatch');
    final current = await load(expected.id);
    if (!expected.sameVersion(current)) {
      throw StateError('元明細が変わりました。開き直してください。');
    }
    final path = payslipPrivateObjectPath(
      expected.raw['source_pdf_path'] as String? ?? '',
      ownerId,
    );
    final url = await client.storage.from('payslips').createSignedUrl(path, 60);
    _checkOwner();
    return Uri.parse(url);
  }
}
