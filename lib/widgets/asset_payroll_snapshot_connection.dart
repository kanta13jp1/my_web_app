import 'package:flutter/material.dart';
import '../services/asset_payroll_snapshot_store.dart';
import 'asset_payroll_snapshot_section.dart';

/// Resolve authentication before creating any owner-bound store or Future.
class AssetPayrollSnapshotConnection extends StatelessWidget {
  const AssetPayrollSnapshotConnection({
    super.key,
    required this.ownerId,
    required this.initialMonth,
    required this.createStore,
  });

  final String? ownerId;
  final DateTime initialMonth;
  final PayrollSnapshotStore Function(String ownerId) createStore;

  @override
  Widget build(BuildContext context) {
    final owner = ownerId;
    if (owner == null || owner.trim().isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('給与入金直後の残高を記録するにはログインしてください。'),
        ),
      );
    }
    return AssetPayrollSnapshotSection(
      key: ValueKey('payroll-confirmed-snapshot-$owner'),
      store: createStore(owner),
      initialMonth: initialMonth,
    );
  }
}
