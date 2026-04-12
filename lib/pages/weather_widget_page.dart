import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 天気ウィジェットページ
/// weather-widget Edge Function と連携して天気情報を表示
class WeatherWidgetPage extends StatefulWidget {
  const WeatherWidgetPage({super.key});

  @override
  State<WeatherWidgetPage> createState() => _WeatherWidgetPageState();
}

class _WeatherWidgetPageState extends State<WeatherWidgetPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _weather;
  List<Map<String, dynamic>> _forecast = [];

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'get_weather', 'city': 'Tokyo'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final weatherData = data['weather'] as Map<String, dynamic>?;
        final currentConditions = weatherData?['current_condition'];
        setState(() {
          _weather = currentConditions is List && currentConditions.isNotEmpty
              ? currentConditions.first as Map<String, dynamic>
              : null;
          final hourly = weatherData?['weather'];
          _forecast = hourly is List
              ? hourly.cast<Map<String, dynamic>>()
              : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '天気情報の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _weatherIcon(String? condition) {
    switch (condition?.toLowerCase()) {
      case 'sunny':
      case 'clear':
        return Icons.wb_sunny;
      case 'cloudy':
        return Icons.cloud;
      case 'rainy':
      case 'rain':
        return Icons.grain;
      case 'snowy':
      case 'snow':
        return Icons.ac_unit;
      default:
        return Icons.wb_cloudy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('天気ウィジェット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchWeather,
            tooltip: '更新',
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchWeather,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_weather != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _weatherIcon(
                                        _weather!['condition']
                                            ?.toString(),
                                      ),
                                      size: 64,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_weather!['temperature'] ?? '-'}°C',
                                          style: Theme.of(context)
                                              .textTheme
                                              .displaySmall,
                                        ),
                                        Text(
                                          _weather!['condition']
                                                  ?.toString() ??
                                              '-',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildWeatherDetail(
                                      Icons.water_drop,
                                      '湿度',
                                      '${_weather!['humidity'] ?? '-'}%',
                                    ),
                                    _buildWeatherDetail(
                                      Icons.air,
                                      '風速',
                                      '${_weather!['wind_speed'] ?? '-'}m/s',
                                    ),
                                    _buildWeatherDetail(
                                      Icons.location_on,
                                      '地点',
                                      _weather!['location']?.toString() ?? '-',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.blue[900]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.wb_cloudy,
                                size: 64,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 8),
                              Text('天気データがありません'),
                            ],
                          ),
                        ),
                      ],
                      if (_forecast.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '週間予報',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _forecast.length,
                          itemBuilder: (context, index) {
                            final day = _forecast[index];
                            return ListTile(
                              leading: Icon(
                                _weatherIcon(day['condition']?.toString()),
                                color: Colors.blue,
                              ),
                              title: Text(day['date']?.toString() ?? '-'),
                              trailing: Text(
                                '${day['high'] ?? '-'}° / ${day['low'] ?? '-'}°',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
