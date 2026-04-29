import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// スプレッドシート・データベースページ
/// spreadsheet-database Edge Function と連携してデータを管理
class SpreadsheetDatabasePage extends StatefulWidget {
  const SpreadsheetDatabasePage({super.key});

  @override
  State<SpreadsheetDatabasePage> createState() =>
      _SpreadsheetDatabasePageState();
}

class _SpreadsheetDatabasePageState extends State<SpreadsheetDatabasePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _sheets = [];
  List<Map<String, dynamic>> _rows = [];
  String? _selectedSheetId;

  @override
  void initState() {
    super.initState();
    _fetchSheets();
  }

  Future<void> _fetchSheets() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'sheet.list'},
      );
      if (res.data != null) {
        final data = res.data as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _sheets =
              List<Map<String, dynamic>>.from(data['sheets'] as List? ?? []);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRows(String sheetId) async {
    setState(() {
      _isLoading = true;
      _selectedSheetId = sheetId;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'sheet.list'},
      );
      if (res.data != null) {
        final data = res.data as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _rows = List<Map<String, dynamic>>.from(data['rows'] as List? ?? []);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('スプレッドシート・データベース'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSheets,
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
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchSheets,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'シート一覧',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _sheets.isEmpty
                                ? const Center(child: Text('シートなし'))
                                : ListView.builder(
                                    itemCount: _sheets.length,
                                    itemBuilder: (context, index) {
                                      final sheet = _sheets[index];
                                      final id = sheet['id']?.toString() ?? '';
                                      return ListTile(
                                        title: Text(
                                          sheet['name']?.toString() ?? id,
                                        ),
                                        selected: _selectedSheetId == id,
                                        onTap: () => _fetchRows(id),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selectedSheetId == null
                          ? const Center(child: Text('シートを選択してください'))
                          : _rows.isEmpty
                              ? const Center(child: Text('データなし'))
                              : ListView.builder(
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) {
                                    final row = _rows[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          row.entries
                                              .map(
                                                (e) => '${e.key}: ${e.value}',
                                              )
                                              .join(' | '),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}
