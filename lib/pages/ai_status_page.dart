import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class AiStatusPage extends StatefulWidget {
  const AiStatusPage({super.key});

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  List<dynamic> _models = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAvailableModels();
  }

  Future<void> _fetchAvailableModels() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      );

      if (response.status != 200)
        throw Exception('API Error: ${response.status}');

      final data =
          response.data is String ? jsonDecode(response.data) : response.data;
      setState(() {
        final List<dynamic> modelList = data['models'] ?? [];
        _models = List.from(modelList);
        _models
            .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color navy = const Color(0xFF0F172A);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI稼働モニター'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAvailableModels,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('エラーが発生しました: $_error',
                      style: const TextStyle(color: Colors.red)),
                ))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    final provider = model['provider'] as String;
                    final score = model['score'] as int;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: _buildProviderBadge(provider),
                        title: Text(model['model'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Provider: ${provider.toUpperCase()}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$score',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: score >= 1100
                                        ? Colors.blue
                                        : (score >= 900
                                            ? Colors.green
                                            : Colors.grey))),
                            const Text('Score', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildProviderBadge(String provider) {
    Color color;
    IconData icon;
    switch (provider.toLowerCase()) {
      case 'openai':
        color = Colors.green;
        icon = Icons.bolt;
        break;
      case 'anthropic':
        color = Colors.orange;
        icon = Icons.auto_awesome;
        break;
      case 'gemini':
        color = Colors.blue;
        icon = Icons.auto_graph;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    return CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20));
  }
}
