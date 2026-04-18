import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// バーチャルペットページ
/// virtual-pet Edge Function と連携してバーチャルペットを管理
class VirtualPetPage extends StatefulWidget {
  const VirtualPetPage({super.key});

  @override
  State<VirtualPetPage> createState() => _VirtualPetPageState();
}

class _VirtualPetPageState extends State<VirtualPetPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _pet;
  List<Map<String, dynamic>> _actions = [];

  @override
  void initState() {
    super.initState();
    _fetchPet();
  }

  Future<void> _fetchPet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'virtual-pet',
        body: {'action': 'status'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _pet = data['pet'] as Map<String, dynamic>? ?? data;
          _actions = (data['available_actions'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ペット情報の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doAction(String action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'virtual-pet',
        body: {'action': action},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _pet = data['pet'] as Map<String, dynamic>? ?? _pet;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message']?.toString() ?? '$action しました'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'アクションに失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatBar(String label, dynamic value, Color color) {
    final val = (value is num ? value.toDouble() : 0.0).clamp(0.0, 100.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: val / 100,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: color,
              minHeight: 10,
            ),
          ),
          const SizedBox(width: 8),
          Text('${val.toInt()}%', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バーチャルペット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchPet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_pet != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.pets,
                              size: 64,
                              color: Color(0xFFFF6B35),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pet!['name']?.toString() ?? 'ペット',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_pet!['level'] != null)
                              Text(
                                'Lv. ${_pet!['level']}',
                                style:
                                    const TextStyle(color: Color(0xFFB0B0B0)),
                              ),
                            const SizedBox(height: 16),
                            _buildStatBar(
                              '空腹',
                              _pet!['hunger'],
                              const Color(0xFFFF6B35),
                            ),
                            _buildStatBar(
                              '幸福',
                              _pet!['happiness'],
                              const Color(0xFFFF6B35),
                            ),
                            _buildStatBar('体力', _pet!['energy'], Colors.green),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : () => _doAction('feed'),
                          icon: const Icon(Icons.restaurant),
                          label: const Text('ご飯をあげる'),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : () => _doAction('play'),
                          icon: const Icon(Icons.sports_esports),
                          label: const Text('遊ぶ'),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : () => _doAction('sleep'),
                          icon: const Icon(Icons.bedtime),
                          label: const Text('寝かせる'),
                        ),
                        ..._actions.map((a) {
                          final name = a['name']?.toString() ?? '';
                          final label = a['label']?.toString() ?? name;
                          return OutlinedButton(
                            onPressed: _isLoading || name.isEmpty
                                ? null
                                : () => _doAction(name),
                            child: Text(label),
                          );
                        }),
                      ],
                    ),
                  ] else
                    const Center(child: Text('ペット情報がありません')),
                ],
              ),
            ),
    );
  }
}
