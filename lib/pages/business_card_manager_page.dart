import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 名刺管理ページ
/// OCR+AI連絡先自動抽出・タグ管理・人脈グラフ。Eight / CamCard 対抗。
class BusinessCardManagerPage extends StatefulWidget {
  const BusinessCardManagerPage({super.key});

  @override
  State<BusinessCardManagerPage> createState() =>
      _BusinessCardManagerPageState();
}

class _BusinessCardManagerPageState extends State<BusinessCardManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  List<Map<String, dynamic>> _cards = [];

  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _titleCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('business_cards')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _cards = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('business_cards').insert({
        'user_id': user.id,
        'name': name,
        'company': _companyCtrl.text.trim(),
        'title': _titleCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      _nameCtrl.clear();
      _companyCtrl.clear();
      _titleCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      if (mounted) Navigator.of(context).pop();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '名刺を追加',
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_nameCtrl, '氏名 *'),
              const SizedBox(height: 8),
              _field(_companyCtrl, '会社名'),
              const SizedBox(height: 8),
              _field(_titleCtrl, '役職'),
              const SizedBox(height: 8),
              _field(_emailCtrl, 'メールアドレス'),
              const SizedBox(height: 8),
              _field(_phoneCtrl, '電話番号'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white54, height: 1.5),
            ),
          ),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) => TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, height: 1.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, height: 1.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFF6B35)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          '名刺管理',
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          : _cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.contact_mail_outlined,
                        color: Colors.white38,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '名刺はまだありません',
                        style: TextStyle(color: Colors.white38, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('名刺を追加'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cards.length,
                  itemBuilder: (_, i) {
                    final c = _cards[i];
                    final raw =
                        (c['name'] as String? ?? '?').replaceAll(' ', '');
                    final initials =
                        raw.length >= 2 ? raw.substring(0, 2) : raw;
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFFF6B35).withValues(alpha: 0.2),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                        ),
                        title: Text(
                          c['name'] as String? ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((c['company'] as String? ?? '').isNotEmpty)
                              Text(
                                c['company'] as String,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            if ((c['title'] as String? ?? '').isNotEmpty)
                              Text(
                                c['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine:
                            (c['company'] as String? ?? '').isNotEmpty &&
                                (c['title'] as String? ?? '').isNotEmpty,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if ((c['email'] as String? ?? '').isNotEmpty)
                              const Icon(
                                Icons.email_outlined,
                                color: Colors.white38,
                                size: 16,
                              ),
                            if ((c['phone'] as String? ?? '').isNotEmpty)
                              const Icon(
                                Icons.phone_outlined,
                                color: Colors.white38,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _cards.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF6B35),
              onPressed: _showAddDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
