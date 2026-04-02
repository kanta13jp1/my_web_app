import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DNS・ドメイン管理ページ
/// dns-domain-manager Edge Function と連携してドメイン設定を管理
class DnsDomainManagerPage extends StatefulWidget {
  const DnsDomainManagerPage({super.key});

  @override
  State<DnsDomainManagerPage> createState() => _DnsDomainManagerPageState();
}

class _DnsDomainManagerPageState extends State<DnsDomainManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _domains = [];

  @override
  void initState() {
    super.initState();
    _fetchDomains();
  }

  Future<void> _fetchDomains() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'dns-domain-manager',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['domains'] is List) {
        setState(() => _domains = (data['domains'] as List).cast<Map<String, dynamic>>());
      } else if (data is List) {
        setState(() => _domains = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _domains = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ドメイン情報の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS・ドメイン管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDomains,
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
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDomains,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _domains.isEmpty
                  ? const Center(child: Text('ドメインデータがありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _domains.length,
                      itemBuilder: (context, index) {
                        final domain = _domains[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.dns),
                            title: Text(domain['name']?.toString() ?? ''),
                            subtitle: Text(domain['status']?.toString() ?? ''),
                          ),
                        );
                      },
                    ),
    );
  }
}
