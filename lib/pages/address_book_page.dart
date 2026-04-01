import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アドレス帳ページ
/// address-book Edge Function と連携して連絡先管理を提供
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'address-book',
        queryParameters: {'view': 'list'},
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
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _labelColor(String? label) {
    switch (label) {
      case 'family':
        return Colors.red;
      case 'friend':
        return Colors.green;
      case 'work':
        return Colors.blue;
      case 'school':
        return Colors.orange;
      case 'vip':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _labelIcon(String? label) {
    switch (label) {
      case 'family':
        return Icons.family_restroom;
      case 'friend':
        return Icons.people;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'vip':
        return Icons.star;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アドレス帳'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _contacts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.contacts_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '連絡先はありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _contacts[i] as Map<String, dynamic>;
                        final label = item['label']?.toString();
                        final name = item['name']?.toString() ?? '名前なし';
                        final email = item['email']?.toString();
                        final phone = item['phone']?.toString();
                        final org = item['organization']?.toString();
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _labelColor(label).withAlpha(30),
                              child: Icon(_labelIcon(label), color: _labelColor(label)),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              [if (org != null) org, if (email != null) email, if (phone != null) phone]
                                  .join(' · '),
                            ),
                            trailing: label != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _labelColor(label).withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _labelColor(label),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
