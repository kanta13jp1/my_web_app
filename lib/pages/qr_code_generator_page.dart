import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// QR コード生成ページ
/// tools-hub:generate_qr で QR コードを生成
class QrCodeGeneratorPage extends StatefulWidget {
  const QrCodeGeneratorPage({super.key});

  @override
  State<QrCodeGeneratorPage> createState() => _QrCodeGeneratorPageState();
}

class _QrCodeGeneratorPageState extends State<QrCodeGeneratorPage> {
  final _supabase = Supabase.instance.client;
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = [];
  String? _generatedUrl;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() => _history = []);
  }

  Future<void> _generateQr() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedUrl = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'generate_qr', 'text': url},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _generatedUrl = data['qr_url']?.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'QR コードの生成に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('QR コード生成'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL または テキスト',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateQr,
              icon: const Icon(Icons.qr_code),
              label: const Text('QR コードを生成'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (_generatedUrl != null) ...[
              const SizedBox(height: 12),
              const Text(
                '生成された QR コード:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFB0B0B0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _generatedUrl!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_history.isNotEmpty) ...[
              const Text(
                '生成履歴',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final url = item['url']?.toString() ?? 'URL ${index + 1}';
                    final createdAt = item['created_at']?.toString();
                    return ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(url),
                      subtitle: createdAt != null ? Text(createdAt) : null,
                    );
                  },
                ),
              ),
            ] else
              const Center(child: Text('生成履歴はありません')),
          ],
        ),
      ),
    );
  }
}
