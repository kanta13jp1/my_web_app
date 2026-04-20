import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyJudgmentPage extends StatefulWidget {
  const DailyJudgmentPage({super.key});

  @override
  State<DailyJudgmentPage> createState() => _DailyJudgmentPageState();
}

class _DailyJudgmentPageState extends State<DailyJudgmentPage> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _fetchJudgment() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'daily-judgment',
        method: HttpMethod.get,
      );
      setState(() => _result = res.data as Map<String, dynamic>?);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchJudgment();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI デイリー判定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchJudgment,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'エラー: $_error',
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchJudgment,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _result == null
                  ? const Center(child: Text('データなし'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI デイリー判定結果',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._result!.entries.map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            '${e.key}:',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text('${e.value}'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
