import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ペットケア管理ページ
/// ペット情報・健康記録・予防接種・食事管理。
/// pet-care-manager Edge Function と連携。
class PetCareManagerPage extends StatefulWidget {
  const PetCareManagerPage({super.key});

  @override
  State<PetCareManagerPage> createState() => _PetCareManagerPageState();
}

class _PetCareManagerPageState extends State<PetCareManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['pets', 'health', 'vaccination'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _pets = [];
  List<Map<String, dynamic>> _healthLogs = [];
  List<Map<String, dynamic>> _vaccinations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final petsRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'pet.list'},
      );
      final healthRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'pet.vet_records'},
      );

      setState(() {
        final pd = petsRes.data;
        if (pd is Map<String, dynamic>) {
          final list = pd['pets'];
          if (list is List) {
            _pets = list.map((p) => p as Map<String, dynamic>).toList();
          }
        }

        final hd = healthRes.data;
        if (hd is Map<String, dynamic>) {
          final list = hd['records'];
          if (list is List) {
            _healthLogs = list.map((h) => h as Map<String, dynamic>).toList();
          }
        }

        _vaccinations = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペットケア管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pets), text: 'ペット'),
            Tab(icon: Icon(Icons.favorite), text: '健康記録'),
            Tab(icon: Icon(Icons.vaccines), text: 'ワクチン'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPetsTab(),
                    _buildHealthTab(),
                    _buildVaccinationTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildPetsTab() {
    if (_pets.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'ペットが登録されていません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pets.length,
      itemBuilder: (ctx, i) {
        final pet = _pets[i];
        final name = pet['name'] as String? ?? 'ペット ${i + 1}';
        final species = pet['species'] as String? ?? '';
        final breed = pet['breed'] as String? ?? '';
        final age = pet['age'] as int? ?? 0;
        final emoji = pet['emoji'] as String? ?? '🐾';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                emoji,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(
              '$species${breed.isNotEmpty ? " · $breed" : ""}${age > 0 ? " · $age歳" : ""}',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _buildHealthTab() {
    if (_healthLogs.isEmpty) {
      return const Center(
        child: Text(
          '健康記録がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _healthLogs.length,
      itemBuilder: (ctx, i) {
        final log = _healthLogs[i];
        final petName = log['petName'] as String? ?? '';
        final type = log['type'] as String? ?? '';
        final note = log['note'] as String? ?? '';
        final date = log['date'] as String? ?? '';
        final weight = log['weight'] as num?;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Color(0xFFFF6B35)),
            title: Text('$petName${type.isNotEmpty ? " — $type" : ""}'),
            subtitle: Text(note.isNotEmpty ? note : '記録なし'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                if (weight != null)
                  Text(
                    '${weight}kg',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVaccinationTab() {
    if (_vaccinations.isEmpty) {
      return const Center(
        child: Text(
          'ワクチン記録がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _vaccinations.length,
      itemBuilder: (ctx, i) {
        final v = _vaccinations[i];
        final petName = v['petName'] as String? ?? '';
        final vaccine = v['vaccine'] as String? ?? '';
        final date = v['date'] as String? ?? '';
        final nextDue = v['nextDue'] as String? ?? '';
        final overdue = v['overdue'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.vaccines,
              color:
                  overdue ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
            ),
            title: Text('$petName — $vaccine'),
            subtitle: Text(
              '接種日: ${date.length >= 10 ? date.substring(0, 10) : date}',
            ),
            trailing: nextDue.isNotEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '次回: ${nextDue.length >= 10 ? nextDue.substring(0, 10) : nextDue}',
                        style: TextStyle(
                          fontSize: 11,
                          color: overdue
                              ? const Color(0xFFE53935)
                              : const Color(0xFF9CA3AF),
                          fontWeight: overdue ? FontWeight.bold : null,
                          height: 1.5,
                        ),
                      ),
                      if (overdue)
                        const Text(
                          '期限超過',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFE53935),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
