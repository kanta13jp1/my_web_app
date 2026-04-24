import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アドレス帳ページ
/// address-book Edge Function と連携して連絡先を管理
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'address.list',
          if (query != null && query.isNotEmpty) 'query': query,
        },
      );
      final data = response.data;
      final cList = data is Map<String, dynamic>
          ? (data['contacts'] ?? data['addresses'])
          : null;
      if (cList is List) {
        setState(() => _contacts = cList);
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
        title: const Text('アドレス帳'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchContacts(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '連絡先を検索',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      _fetchContacts(query: _searchController.text.trim()),
                ),
              ),
              onSubmitted: (v) => _fetchContacts(query: v.trim()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                      ? const Center(child: Text('連絡先はありません'))
                      : ListView.builder(
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final item = _contacts[index];
                            final name = item is Map
                                ? (item['name'] ?? item['full_name'] ?? '名前なし')
                                : item.toString();
                            final email =
                                item is Map ? (item['email'] ?? '') : '';
                            final phone =
                                item is Map ? (item['phone'] ?? '') : '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    name.toString().isNotEmpty
                                        ? name.toString()[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(name.toString()),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (email.toString().isNotEmpty)
                                      Text(email.toString()),
                                    if (phone.toString().isNotEmpty)
                                      Text(phone.toString()),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContactDialog(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('連絡先を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'メール'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'tools-hub',
                  body: {
                    'action': 'address.add',
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                  },
                );
                await _fetchContacts();
              } catch (e) {
                if (mounted) {
                  setState(() => _errorMessage = '連絡先の追加に失敗しました: $e');
                }
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
