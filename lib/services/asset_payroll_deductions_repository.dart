import 'package:supabase_flutter/supabase_flutter.dart';

class PayrollDeductionsYear {
  const PayrollDeductionsYear(this.rows, {required this.complete});
  final List<Map<String, dynamic>> rows;
  final bool complete;
}

class AssetPayrollDeductionsRepository {
  const AssetPayrollDeductionsRepository(this.client);
  final SupabaseClient client;

  Future<PayrollDeductionsYear> loadYear(int year) async {
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('給与明細を見るにはログインしてください。');
    final rows = <Map<String, dynamic>>[];
    const pageSize = 100;
    const maximumRows = 2000;
    for (var offset = 0; offset < maximumRows; offset += pageSize) {
      if (client.auth.currentUser?.id != ownerId) throw StateError('利用者が切り替わりました。再読込してください。');
      final page = await client.from('payslips').select(
        'id,user_id,pay_date,gross_amount,net_amount,social_insurance_total,deductions,review_status',
      ).eq('user_id', ownerId).gte('pay_date', '$year-01-01').lt('pay_date', '${year + 1}-01-01').order('pay_date').order('id').range(offset, offset + pageSize - 1);
      if (client.auth.currentUser?.id != ownerId) throw StateError('利用者が切り替わりました。再読込してください。');
      rows.addAll(page.map((row) => Map<String, dynamic>.from(row)));
      if (page.length < pageSize) return PayrollDeductionsYear(List.unmodifiable(rows), complete: true);
    }
    return PayrollDeductionsYear(List.unmodifiable(rows), complete: false);
  }
}
