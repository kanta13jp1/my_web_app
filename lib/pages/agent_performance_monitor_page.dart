import 'package:flutter/material.dart';

class AgentPerformanceMonitorPage extends StatelessWidget {
  const AgentPerformanceMonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('エージェントパフォーマンス監視')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monitor_heart, size: 64, color: Color(0xFF6366F1)),
            SizedBox(height: 16),
            Text(
              'enterprise-hub へ移行準備中',
              style: TextStyle(fontSize: 18, height: 1.5),
            ),
            SizedBox(height: 8),
            Text(
              'エージェントパフォーマンス監視機能は近日公開予定です',
              style: TextStyle(color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
