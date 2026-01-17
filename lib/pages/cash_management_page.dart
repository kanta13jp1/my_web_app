import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class CashManagementPage extends StatefulWidget {
  const CashManagementPage({super.key});

  @override
  _CashManagementPageState createState() => _CashManagementPageState();
}

class _CashManagementPageState extends State<CashManagementPage> {
  final TextEditingController _cashController = TextEditingController();
  List<FlSpot> _spots = [];
  Map<String, double> _cashData = {};

  @override
  void initState() {
    super.initState();
    _loadCashData();
  }

  Future<void> _loadCashData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cashDataString = prefs.getString('cash_data');
    if (cashDataString != null) {
      final Map<String, dynamic> decodedData = jsonDecode(cashDataString);
      setState(() {
        _cashData =
            decodedData.map((key, value) => MapEntry(key, value.toDouble()));
        _updateSpots();
      });
    }
  }

  Future<void> _saveCashData() async {
    if (_cashController.text.isEmpty) return;

    final double amount = double.tryParse(_cashController.text) ?? 0.0;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    setState(() {
      _cashData[today] = amount;
      _updateSpots();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cash_data', jsonEncode(_cashData));
    _cashController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('現金を登録しました。')),
    );
  }

  void _updateSpots() {
    final sortedEntries = _cashData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    _spots = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.value;
      return FlSpot(index.toDouble(), value);
    }).toList();
  }

  String _getTooltipText(LineBarSpot spot) {
    final sortedEntries = _cashData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final entry = sortedEntries[spot.spotIndex];
    final date = DateFormat('MM/dd').format(DateTime.parse(entry.key));
    final amount =
        NumberFormat.simpleCurrency(locale: 'ja_JP').format(entry.value);
    return '$date\n$amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('現金管理'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCashInputCard(),
            const SizedBox(height: 24),
            _buildChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCashInputCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の現金残高を登録',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '現金残高 (円)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wallet),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveCashData,
                icon: const Icon(Icons.save),
                label: const Text('登録'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '現金残高推移',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _spots.isEmpty
                ? const Center(child: Text('登録データがありません。'))
                : SizedBox(
                    height: 250,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  _getTooltipText(spot),
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
