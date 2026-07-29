import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/elearning_course.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// eラーニングコース管理ページ
/// コース一覧・学習進捗・クイズ・証明書。
/// elearning-course-manager Edge Function と連携。
class ElearningCourseManagerPage extends StatefulWidget {
  const ElearningCourseManagerPage({super.key});

  @override
  State<ElearningCourseManagerPage> createState() =>
      _ElearningCourseManagerPageState();
}

class _ElearningCourseManagerPageState extends State<ElearningCourseManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['courses', 'learning', 'certificates'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<ELearningCourse> _courses = [];
  List<ELearningCourse> _inProgress = [];
  List<Map<String, dynamic>> _certificates = [];

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
      final coursesRes = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'course.list'},
      );
      final progressRes = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'course.progress'},
      );
      final certRes = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'course.certificates'},
      );

      final courses = ELearningCourse.listFromResponse(coursesRes.data);
      final progressById = ELearningCourse.progressByCourseId(progressRes.data);
      setState(() {
        _courses = courses;
        _inProgress = ELearningCourse.inProgress(courses, progressById);
        _certificates = _extractList(certRes.data, 'certificates');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic data, String key) {
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
        title: const Text('eラーニング'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'コース'),
            Tab(icon: Icon(Icons.play_circle), text: '学習中'),
            Tab(icon: Icon(Icons.workspace_premium), text: '証明書'),
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
                    _buildCoursesTab(_courses),
                    _buildCoursesTab(_inProgress, showProgress: true),
                    _buildCertificatesTab(),
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

  Widget _buildCoursesTab(
    List<ELearningCourse> courses, {
    bool showProgress = false,
  }) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school, size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              showProgress ? '学習中のコースがありません' : 'コースがありません',
              style: const TextStyle(
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
      itemCount: courses.length,
      itemBuilder: (ctx, i) {
        final c = courses[i];
        final title = c.title.isNotEmpty ? c.title : 'コース ${i + 1}';
        final language = c.language;
        final level = c.level;
        final progress = c.progress.toDouble();
        final enrolled = c.progress > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Text(
                    '📚',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.5,
                    ),
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                subtitle: language.isNotEmpty ? Text('言語: $language') : null,
                trailing: level.isNotEmpty
                    ? Chip(
                        label: Text(
                          level,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                      )
                    : null,
              ),
              if (showProgress && progress > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${progress.toInt()}% 完了',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!enrolled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await _supabase.functions.invoke(
                              'social-commerce-hub',
                              body: {
                                'action': 'course.enroll',
                                'course_id': c.id,
                              },
                            );
                            await _fetchData();
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('受講する'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCertificatesTab() {
    if (_certificates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '証明書がありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'コースを修了すると証明書が発行されます',
              style: TextStyle(
                fontSize: 12,
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
      itemCount: _certificates.length,
      itemBuilder: (ctx, i) {
        final cert = _certificates[i];
        final title = cert['courseTitle'] as String? ?? '';
        final date = cert['issuedAt'] as String? ?? '';
        final id = cert['certificateId'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(
              Icons.workspace_premium,
              color: Color(0xFFFFC107),
              size: 36,
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(
              '${date.length >= 10 ? date.substring(0, 10) : date}'
              '${id.isNotEmpty ? "\nID: $id" : ""}',
            ),
            isThreeLine: id.isNotEmpty,
          ),
        );
      },
    );
  }
}
