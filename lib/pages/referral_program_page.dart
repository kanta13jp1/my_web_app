import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 紹介プログラムページ
/// referral-program Edge Function と連携して紹介コード・報酬・リーダーボードを提供
class ReferralProgramPage extends StatefulWidget {
  const ReferralProgramPage({super.key});

  @override
  State<ReferralProgramPage> createState() => _ReferralProgramPageState();
}

class _ReferralProgramPageState extends State<ReferralProgramPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _myCode;
  List<dynamic> _referrals = [];

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
      final codeRes = await _supabase.functions.invoke(
        'referral-program',
        queryParameters: {'view': 'my_code'},
      );
      final refRes = await _supabase.functions.invoke(
        'referral-program',
        queryParameters: {'view': 'referrals'},
      );
      final codeData = codeRes.data;
      final refData = refRes.data;
      setState(() {
        _myCode = codeData is Map<String, dynamic> ? codeData : null;
        final refs =
            refData is Map<String, dynamic> ? refData['referrals'] : null;
        _referrals = refs is List ? refs : [];
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('紹介プログラム'),
        backgroundColor: const Color(0xFF3D5AFE),
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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_myCode != null) ...[
                      Card(
                        color: const Color(0xFFE8EAF6),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'あなたの紹介コード',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _myCode!['code']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3D5AFE),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '紹介数: ${_myCode!['totalReferrals'] ?? 0}人',
                                style:
                                    const TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      '紹介履歴',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_referrals.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            '紹介履歴はありません',
                            style: TextStyle(color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_referrals.length, (i) {
                        final item = _referrals[i] as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x1A3F51B5),
                              child: Icon(
                                Icons.person_add,
                                color: Color(0xFF3D5AFE),
                              ),
                            ),
                            title: Text(
                              item['referred_email']?.toString() ??
                                  item['email']?.toString() ??
                                  '匿名ユーザー',
                            ),
                            subtitle: Text(
                              item['status']?.toString() ?? 'pending',
                            ),
                            trailing: Text(
                              item['createdAt']?.toString().substring(0, 10) ??
                                  '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
