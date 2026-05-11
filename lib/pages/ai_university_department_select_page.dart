import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_university_content_page.dart';

class AiUniversityDepartmentSelectPage extends StatefulWidget {
  final String facultyCode;
  final String facultyName;
  final String facultyEmoji;

  const AiUniversityDepartmentSelectPage({
    super.key,
    required this.facultyCode,
    required this.facultyName,
    required this.facultyEmoji,
  });

  @override
  State<AiUniversityDepartmentSelectPage> createState() =>
      _AiUniversityDepartmentSelectPageState();
}

class _AiUniversityDepartmentSelectPageState
    extends State<AiUniversityDepartmentSelectPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _departments = [];

  static const Map<String, List<Map<String, dynamic>>> _fallbackByFaculty = {
    'ai': [
      {'department_code': 'llm', 'name_ja': 'LLM 学科', 'emoji': '🧠'},
      {'department_code': 'image', 'name_ja': '画像生成学科', 'emoji': '🎨'},
      {'department_code': 'voice', 'name_ja': '音声・音楽学科', 'emoji': '🎵'},
      {'department_code': 'video', 'name_ja': '動画生成学科', 'emoji': '🎬'},
      {'department_code': 'agent', 'name_ja': 'エージェント学科', 'emoji': '🤖'},
      {'department_code': 'embedding', 'name_ja': '埋め込み・検索学科', 'emoji': '🔍'},
      {'department_code': 'framework', 'name_ja': 'フレームワーク学科', 'emoji': '🛠️'},
      {
        'department_code': 'fintech_trading_ai',
        'name_ja': 'FinTech disruption / Trading x AI 学科',
        'emoji': '📈',
      },
    ],
    'cloud': [
      {'department_code': 'aws', 'name_ja': 'AWS 学科', 'emoji': '🟠'},
      {'department_code': 'gcp', 'name_ja': 'GCP 学科', 'emoji': '🔵'},
      {'department_code': 'azure', 'name_ja': 'Azure 学科', 'emoji': '🟦'},
      {
        'department_code': 'oracle',
        'name_ja': 'Oracle Cloud 学科',
        'emoji': '🔴',
      },
      {'department_code': 'edge', 'name_ja': 'エッジ・新興クラウド学科', 'emoji': '⚡'},
    ],
    'devtools': [
      {'department_code': 'iac', 'name_ja': 'IaC 学科', 'emoji': '🏗️'},
      {'department_code': 'cicd', 'name_ja': 'CI/CD 学科', 'emoji': '🔄'},
      {'department_code': 'container', 'name_ja': 'コンテナ学科', 'emoji': '📦'},
      {'department_code': 'monitoring', 'name_ja': '監視・観測学科', 'emoji': '📊'},
    ],
    'data': [
      {'department_code': 'database', 'name_ja': 'データベース学科', 'emoji': '🗄️'},
      {'department_code': 'warehouse', 'name_ja': 'データウェアハウス学科', 'emoji': '🏭'},
      {'department_code': 'stream', 'name_ja': 'ストリーム処理学科', 'emoji': '🌊'},
    ],
    'research': [
      {'department_code': 'benchmark', 'name_ja': 'ベンチマーク学科', 'emoji': '📏'},
      {'department_code': 'paper', 'name_ja': '研究論文学科', 'emoji': '📄'},
      {'department_code': 'lab', 'name_ja': '研究機関学科', 'emoji': '🔬'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final rows = await Supabase.instance.client
          .from('university_departments')
          .select(
            'department_code, name_ja, emoji, sort_order, description, university_faculties!inner(faculty_code)',
          )
          .eq('is_active', true)
          .eq('university_faculties.faculty_code', widget.facultyCode)
          .order('sort_order');
      if (mounted) {
        final result = List<Map<String, dynamic>>.from(rows);
        setState(() {
          _departments = result.isEmpty
              ? (_fallbackByFaculty[widget.facultyCode] ?? [])
              : result;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _departments = _fallbackByFaculty[widget.facultyCode] ?? [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.facultyEmoji} ${widget.facultyName}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'AI大学 › ${widget.facultyName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (_departments.isEmpty)
                  const Expanded(
                    child: Center(child: Text('学科データなし')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _departments.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final d = _departments[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                d['emoji'] as String? ?? '📘',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          title: Text(
                            d['name_ja'] as String? ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          subtitle: d['description'] != null
                              ? Text(
                                  d['description'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiUniversityContentPage(
                                facultyCode: widget.facultyCode,
                                facultyName: widget.facultyName,
                                facultyEmoji: widget.facultyEmoji,
                                departmentCode:
                                    d['department_code'] as String? ?? '',
                                departmentName: d['name_ja'] as String? ?? '',
                                departmentEmoji: d['emoji'] as String? ?? '📘',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
