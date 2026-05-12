import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 旅行・旅程プランナーページ
/// travel-itinerary-planner Edge Function と連携して旅程を管理
class TravelItineraryPlannerPage extends StatefulWidget {
  const TravelItineraryPlannerPage({super.key});

  @override
  State<TravelItineraryPlannerPage> createState() =>
      _TravelItineraryPlannerPageState();
}

class _TravelItineraryPlannerPageState
    extends State<TravelItineraryPlannerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _itineraries = [];

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  Future<void> _fetchItineraries() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions
          .invoke('lifestyle-hub', body: {'action': 'travel.list'});
      if (res.data != null) {
        final data = res.data as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _itineraries = List<Map<String, dynamic>>.from(
            (data['trips'] ?? data['itineraries']) as List? ?? [],
          );
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
        title: const Text('旅行・旅程プランナー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchItineraries,
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
                        onPressed: _fetchItineraries,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _itineraries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.flight_takeoff,
                            size: 64,
                            color: Color(0xFFB0B0B0),
                          ),
                          const SizedBox(height: 16),
                          const Text('旅行プランがありません'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _fetchItineraries,
                            icon: const Icon(Icons.add),
                            label: const Text('プランを作成'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _itineraries.length,
                      itemBuilder: (context, index) {
                        final item = _itineraries[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.flight_takeoff),
                            title: Text(
                              item['title']?.toString() ?? '旅程 ${index + 1}',
                            ),
                            subtitle: Text(
                              [
                                if (item['destination'] != null)
                                  item['destination'].toString(),
                                if (item['start_date'] != null)
                                  item['start_date'].toString(),
                              ].join(' · '),
                            ),
                            trailing: Chip(
                              label: Text(
                                item['status']?.toString() ?? 'draft',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
