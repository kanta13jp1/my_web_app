import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 緊急連絡先ページ
/// emergency-contacts Edge Function と連携して緊急連絡先を管理
class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  State<EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<EmergencyContactsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'emergency-contacts',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['contacts'] is List) {
        setState(() => _contacts = data['contacts'] as List);
      } else if (data is List) {
        setState(() => _contacts = data);
      } else {
        setState(() => _contacts = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '連絡先の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('緊急連絡先'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchContacts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _fetchContacts,
                          child: const Text('再試行')),
                    ],
                  ),
                )
              : _contacts.isEmpty
                  ? const Center(child: Text('緊急連絡先が登録されていません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact =
                            _contacts[index] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              contact['name']?.toString() ?? '名前不明',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              contact['relationship']?.toString() ?? '',
                            ),
                            trailing: Text(
                              contact['phone']?.toString() ?? '',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
