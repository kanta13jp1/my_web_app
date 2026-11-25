import 'package:flutter/material.dart';
import 'package:my_web_app/widgets/business_execution_panel.dart';

/// Browser fixture only: real panel, device storage and Web Locks.
/// No Supabase session, production account, test-only store or seeded records.
void main() {
  const enabled = bool.fromEnvironment('BUSINESS_EXECUTION_E2E');
  const allowedHosts = {'localhost', '127.0.0.1', '::1'};
  if (!enabled || !allowedHosts.contains(Uri.base.host)) {
    throw StateError('This synthetic fixture is restricted to loopback E2E.');
  }
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final monthEnd = Uri.base.queryParameters['monthEnd'] == '1';
  final today = monthEnd ? DateTime(2026, 11, 1) : DateTime(2026, 10, 30);
  runApp(
    MaterialApp(
      theme: ThemeData(fontFamily: 'NotoSansJP'),
      home: Scaffold(
        appBar: AppBar(title: const Text('架空データ検証：経営の実行記録')),
        body: BusinessExecutionPanel(
          userId: 'business-execution-browser-fixture',
          currentUserId: () => 'business-execution-browser-fixture',
          now: () => today,
        ),
      ),
    ),
  );
}
