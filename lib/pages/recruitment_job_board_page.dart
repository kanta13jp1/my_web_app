import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 採用・求人ボードページ
/// 求人掲載・応募者管理・選考フロー。
/// recruitment-job-board Edge Function と連携。
class RecruitmentJobBoardPage extends StatefulWidget {
  const RecruitmentJobBoardPage({super.key});

  @override
  State<RecruitmentJobBoardPage> createState() =>
      _RecruitmentJobBoardPageState();
}

class _RecruitmentJobBoardPageState extends State<RecruitmentJobBoardPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['jobs', 'applicants'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _applicants = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final jobsRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'recruit.list_jobs'},
      );
      final appRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'recruit.list_applicants'},
      );
      setState(() {
        _jobs = _toList(jobsRes.data, 'jobs');
        _applicants = _toList(appRes.data, 'applicants');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('採用・求人ボード'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.work), text: '求人 (${_jobs.length})'),
            Tab(
              icon: const Icon(Icons.people),
              text: '応募者 (${_applicants.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildJobsTab(), _buildApplicantsTab()],
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

  Widget _buildJobsTab() {
    if (_jobs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '求人がありません',
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
      itemCount: _jobs.length,
      itemBuilder: (ctx, i) {
        final job = _jobs[i];
        final title = job['title'] as String? ?? '求人 ${i + 1}';
        final dept = job['department'] as String? ?? '';
        final type = job['employmentType'] as String? ?? '';
        final location = job['location'] as String? ?? '';
        final appCount = job['applicantCount'] as int? ?? 0;
        final status = job['status'] as String? ?? 'open';
        final salary = job['salaryRange'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'open'
                  ? const Color(0xFFC8E6C9)
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Icon(
                Icons.work,
                color: status == 'open'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF9CA3AF),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(
              [
                if (dept.isNotEmpty) dept,
                if (type.isNotEmpty) type,
                if (location.isNotEmpty) location,
                if (salary.isNotEmpty) salary,
              ].join(' · '),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$appCount 名',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const Text(
                  '応募者',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildApplicantsTab() {
    if (_applicants.isEmpty) {
      return const Center(
        child: Text(
          '応募者がいません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _applicants.length,
      itemBuilder: (ctx, i) {
        final a = _applicants[i];
        final name = a['name'] as String? ?? '応募者 ${i + 1}';
        final jobTitle = a['jobTitle'] as String? ?? '';
        final stage = a['stage'] as String? ?? 'applied';
        final date = a['appliedAt'] as String? ?? '';
        final stageColors = <String, Color>{
          'applied': const Color(0xFF3D5AFE),
          'screening': const Color(0xFFFF6B35),
          'interview': const Color(0xFF3D5AFE),
          'offer': const Color(0xFF009688),
          'hired': const Color(0xFF4CAF50),
          'rejected': const Color(0xFFE53935),
        };
        final stageLabels = <String, String>{
          'applied': '応募済',
          'screening': '書類選考',
          'interview': '面接',
          'offer': 'オファー',
          'hired': '採用',
          'rejected': '不採用',
        };
        final color = stageColors[stage] ?? const Color(0xFF9CA3AF);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(name),
            subtitle: Text(jobTitle),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Chip(
                  label: Text(
                    stageLabels[stage] ?? stage,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                  backgroundColor: color.withValues(alpha: 0.15),
                  padding: EdgeInsets.zero,
                ),
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
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
}
