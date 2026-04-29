import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ファミリー共有管理ページ
/// family-sharing-manager Edge Function と連携してファミリーグループを管理
class FamilySharingManagerPage extends StatefulWidget {
  const FamilySharingManagerPage({super.key});

  @override
  State<FamilySharingManagerPage> createState() =>
      _FamilySharingManagerPageState();
}

class _FamilySharingManagerPageState extends State<FamilySharingManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'family.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['members'] is List) {
        setState(
          () =>
              _members = (data['members'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _members = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _members = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ファミリー共有管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMembers,
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
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchMembers,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _members.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 64,
                            color: Color(0xFFB0B0B0),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ファミリーメンバーがいません',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFB0B0B0),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final name =
                            (member['name'] ?? member['email'] ?? 'メンバー $index')
                                .toString();
                        final role = (member['role'] ?? 'member').toString();
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(role),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
    );
  }
}
