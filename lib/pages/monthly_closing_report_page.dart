import 'package:flutter/material.dart';

class MonthlyClosingReportPage extends StatelessWidget {
  const MonthlyClosingReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('月次決算レポート'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('月次決算レポートページ'),
      ),
    );
  }
}
