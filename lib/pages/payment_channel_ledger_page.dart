import 'package:flutter/material.dart';

class PaymentChannelLedgerPage extends StatelessWidget {
  const PaymentChannelLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('決済チャネル台帳'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('決済チャネル台帳ページ'),
      ),
    );
  }
}
