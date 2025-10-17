import 'package:flutter/material.dart';
import '../main.dart';
import 'auth_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'ログイン成功！',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ようこそ！',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('ログアウト'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}