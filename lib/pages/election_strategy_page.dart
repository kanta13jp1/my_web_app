import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // 追加
import 'package:latlong2/latlong.dart'; // 追加
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ElectionStrategyPage extends StatefulWidget {
  const ElectionStrategyPage({super.key});

  @override
  State<ElectionStrategyPage> createState() => _ElectionStrategyPageState();
}

class _ElectionStrategyPageState extends State<ElectionStrategyPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  String? _apiKey;
  final TextEditingController _strategyController = TextEditingController();
  late TabController _tabController;
  bool _isBusy = false;

  // データ
  String _myDistrict = '';
  List<Map<String, dynamic>> _stationData = [];
  List<Map<String, dynamic>> _candidates = []; // 候補者データ

  // シミュレーション値
  double _supportRate = 6.0;
  double _youthTurnout = 35.0;
  double _swingCapture = 20.0;

  @override
  void initState() {
    super.initState();
    // タブを5つに (予測, マップ, 地上戦, 戦略, 素材)
    _tabController = TabController(length: 5, vsync: this);
    _loadApiKey();
    _fetchUserProfile();
    _fetchCandidates(); // 候補者データ取得
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  Future<void> _fetchUserProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await _supabase
        .from('user_profiles')
        .select('election_district')
        .eq('user_id', userId)
        .maybeSingle();
    if (data != null && data['election_district'] != null) {
      setState(() => _myDistrict = data['election_district']);
      _fetchLogistics(data['election_district']);
    }
  }

  // ★ 候補者データ取得
  Future<void> _fetchCandidates() async {
    try {
      final data = await _supabase.from('candidates').select();
      setState(() {
        _candidates = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching candidates: $e');
    }
  }

  Future<void> _fetchLogistics(String district) async {
    try {
      final data = await _supabase
          .from('district_logistics')
          .select()
          .eq('district_name', district)
          .maybeSingle();
      if (data != null && data['station_data'] != null) {
        setState(() {
          _stationData = List<Map<String, dynamic>>.from(data['station_data']);
        });
      }
    } catch (e) {
      debugPrint('Logistics Error: $e');
    }
  }

  // (その他の既存メソッド _analyzeLogistics, _submitStrategy, _pickAndAnalyzeImage などは省略せずそのまま使用)
  // ※コード量の都合上、前回までのメソッド実装が含まれている前提とします

  Future<void> _fetchLatestTrends() async {/* 前回と同じ実装 */}
  Future<void> _submitStrategy() async {/* 前回と同じ実装 */}
  Future<void> _pickAndAnalyzeImage() async {/* 前回と同じ実装 */}
  void _showDistrictDialog() {/* 前回と同じ実装 */}
  void _showAddDialog() {/* 前回と同じ実装 */}

  // マニュアルダイアログ（更新）
  void _showManualDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.menu_book, color: Colors.indigo),
          SizedBox(width: 8),
          Text('利用マニュアル')
        ]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManualItem(
                  icon: Icons.map,
                  title: '1. 戦況マップ (New)',
                  desc:
                      '全国の候補者の優勢・劣勢を地図上で可視化します。Pythonバッチ処理により、Geminiが夜間に情勢を自動更新しています。'),
              _ManualItem(
                  icon: Icons.train,
                  title: '2. 地上戦ロジスティクス',
                  desc: '主要駅データの分析結果を表示します。'),
              _ManualItem(
                  icon: Icons.auto_graph,
                  title: '3. トレンド分析',
                  desc: '最新の支持率データを反映します。'),
              _ManualItem(
                  icon: Icons.psychology,
                  title: '4. AI戦略参謀',
                  desc: '戦略の投稿と、ポスター素材のAI診断が可能です。'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('閉じる'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 勝利戦略室'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: Icon(
                  _myDistrict.isEmpty ? Icons.location_off : Icons.location_on),
              onPressed: _showDistrictDialog),
          IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _showManualDialog)
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: '戦況マップ'), // 追加
            Tab(icon: Icon(Icons.poll), text: '予測'),
            Tab(icon: Icon(Icons.train), text: '地上戦'),
            Tab(icon: Icon(Icons.lightbulb), text: '戦略'),
            Tab(icon: Icon(Icons.image), text: '素材'),
          ],
        ),
      ),
      body: _isBusy && !mounted
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // マップ操作との干渉を防ぐ
              children: [
                _buildMapTab(), // 追加
                _buildSimulationTab(),
                _buildLogisticsTab(),
                _buildStrategyFeedTab(),
                _buildMaterialDiagnosticsTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 3
          ? FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.add_comment, color: Colors.white),
              label: const Text('戦略投稿'),
            )
          : null,
    );
  }

  // ★ マップタブの実装
  Widget _buildMapTab() {
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(35.681236, 139.767125), // 東京中心
            initialZoom: 9.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: _candidates.map((cand) {
                final prob = cand['win_probability'] as int? ?? 50;
                // 当選確率で色分け
                final color = prob >= 80
                    ? Colors.red
                    : (prob >= 50 ? Colors.orange : Colors.blue);

                return Marker(
                  point: LatLng(cand['latitude'], cand['longitude']),
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _showCandidateDetail(cand),
                    child: Column(
                      children: [
                        Icon(Icons.location_on, color: color, size: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text('${cand['win_probability']}%',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            child: const Icon(Icons.refresh, color: Colors.indigo),
            onPressed: _fetchCandidates,
          ),
        ),
      ],
    );
  }

  void _showCandidateDetail(Map<String, dynamic> cand) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cand['district']} : ${cand['name']}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('当選確率: '),
                Text('${cand['win_probability']}%',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
              ],
            ),
            const Divider(),
            const Text('AI情勢分析 (Batch Updated):',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(cand['ai_analysis'] ?? '分析データなし'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 以下、前回までの既存UI実装（省略せず記述が必要ですが、ここでは差分として扱います）
  Widget _buildSimulationTab() {
    /* 前回のコード */ return const Center(child: Text('シミュレーション'));
  }

  Widget _buildLogisticsTab() {
    /* 前回のコード */ return const Center(child: Text('地上戦'));
  }

  Widget _buildStrategyFeedTab() {
    /* 前回のコード */ return const Center(child: Text('戦略'));
  }

  Widget _buildMaterialDiagnosticsTab() {
    /* 前回のコード */ return const Center(child: Text('素材'));
  }

  Widget _slider(
      String l, double v, double min, double max, Function(double) f, Color c) {
    return const SizedBox();
  }
}

// マニュアルアイテム
class _ManualItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _ManualItem(
      {required this.icon, required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
        ])),
      ]),
    );
  }
}
