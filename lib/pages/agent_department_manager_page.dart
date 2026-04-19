import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentDepartmentManagerPage extends StatefulWidget {
  const AgentDepartmentManagerPage({super.key});

  @override
  State<AgentDepartmentManagerPage> createState() =>
      _AgentDepartmentManagerPageState();
}

class _AgentDepartmentManagerPageState
    extends State<AgentDepartmentManagerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _departments = [];

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'agent-department-manager',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['departments'];
        setState(() {
          _departments =
              items is List ? items.cast<Map<String, dynamic>>() : [];
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIエージェント部署管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDepartments,
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
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDepartments,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _departments.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.corporate_fare,
                            size: 64,
                            color: Color(0xFF6366F1),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '部署データなし',
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'AIエージェントの部署を管理します',
                            style: TextStyle(
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _departments.length,
                      itemBuilder: (context, index) {
                        final dept = _departments[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF6366F1),
                              child: Icon(
                                Icons.corporate_fare,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              dept['name']?.toString() ?? '部署名不明',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              dept['description']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${dept['agent_count'] ?? 0}エージェント',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
