import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/asset_payroll_deductions_repository.dart';
import 'asset_payroll_deductions_card.dart';

class AssetPayrollDeductionsSection extends StatefulWidget {
  const AssetPayrollDeductionsSection({
    super.key,
    required this.client,
    required this.initialYear,
  });
  final SupabaseClient client;
  final int initialYear;

  @override
  State<AssetPayrollDeductionsSection> createState() =>
      _AssetPayrollDeductionsSectionState();
}

class _AssetPayrollDeductionsSectionState
    extends State<AssetPayrollDeductionsSection> {
  late int _year;
  late Future<PayrollDeductionsYear> _load;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _load = _fetchYear();
  }

  Future<PayrollDeductionsYear> _fetchYear() {
    if (widget.client.auth.currentUser == null) {
      return Future.value(const PayrollDeductionsYear([], complete: true));
    }
    return AssetPayrollDeductionsRepository(widget.client).loadYear(_year);
  }

  void _reload([int? year]) {
    setState(() {
      _year = year ?? _year;
      _load = _fetchYear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = widget.client.auth.currentUser?.id;
    if (ownerId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('給与の税金・社会保険料：ログイン後に表示します。'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _year > 2000 ? () => _reload(_year - 1) : null,
              child: const Text('前年'),
            ),
            Text('$_year年 給与控除'),
            TextButton(
              onPressed: _year < widget.initialYear
                  ? () => _reload(_year + 1)
                  : null,
              child: const Text('翌年'),
            ),
            TextButton(
              onPressed: _reload,
              child: const Text('給与控除を再読込'),
            ),
          ],
        ),
        FutureBuilder<PayrollDeductionsYear>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('給与明細の控除を読み込んでいます…'),
              );
            }
            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('給与控除を取得できませんでした。再試行してください。'),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final result = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!result.complete)
                  const Text('取得件数の上限に達しました。以下は取得できた明細だけの部分集計です。'),
                AssetPayrollDeductionsCard(
                  ownerId: ownerId,
                  year: _year,
                  rows: result.rows,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
