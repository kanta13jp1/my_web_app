import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_university_department_select_page.dart';

class AiUniversityFacultySelectPage extends StatefulWidget {
  const AiUniversityFacultySelectPage({super.key});

  @override
  State<AiUniversityFacultySelectPage> createState() =>
      _AiUniversityFacultySelectPageState();
}

class _AiUniversityFacultySelectPageState
    extends State<AiUniversityFacultySelectPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _faculties = [];

  static const List<Map<String, dynamic>> _fallback = [
    {
      'faculty_code': 'hardware',
      'name_ja': 'ハードウェア学部',
      'emoji': '⚙️',
      'sort_order': 2,
    },
    {'faculty_code': 'os', 'name_ja': 'OS 学部', 'emoji': '💿', 'sort_order': 5},
    {'faculty_code': 'ai', 'name_ja': 'AI 学部', 'emoji': '🤖', 'sort_order': 10},
    {
      'faculty_code': 'mobile',
      'name_ja': 'モバイル学部',
      'emoji': '📱',
      'sort_order': 15,
    },
    {
      'faculty_code': 'cloud',
      'name_ja': 'クラウド学部',
      'emoji': '☁️',
      'sort_order': 20,
    },
    {
      'faculty_code': 'devtools',
      'name_ja': '開発ツール学部',
      'emoji': '🛠️',
      'sort_order': 30,
    },
    {
      'faculty_code': 'swe',
      'name_ja': 'ソフトウェアエンジニアリング学部',
      'emoji': '👷',
      'sort_order': 35,
    },
    {
      'faculty_code': 'data',
      'name_ja': 'データ基盤学部',
      'emoji': '💾',
      'sort_order': 40,
    },
    {
      'faculty_code': 'certification',
      'name_ja': '資格試験学部',
      'emoji': '🎓',
      'sort_order': 45,
    },
    {
      'faculty_code': 'research',
      'name_ja': '学術研究学部',
      'emoji': '📚',
      'sort_order': 50,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadFaculties();
  }

  Future<void> _loadFaculties() async {
    try {
      final rows = await Supabase.instance.client
          .from('university_faculties')
          .select('faculty_code, name_ja, emoji, sort_order, description')
          .eq('is_active', true)
          .order('sort_order');
      if (mounted) {
        setState(() {
          _faculties =
              rows.isEmpty ? _fallback : List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _faculties = _fallback;
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
        title: const Text('🎓 AI大学 — 学部選択'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading
                ? null
                : () {
                    setState(() => _loading = true);
                    _loadFaculties();
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _faculties.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final f = _faculties[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        f['emoji'] as String? ?? '🎓',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  title: Text(
                    f['name_ja'] as String? ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  subtitle: f['description'] != null
                      ? Text(
                          f['description'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            height: 1.5,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiUniversityDepartmentSelectPage(
                        facultyCode: f['faculty_code'] as String,
                        facultyName: f['name_ja'] as String? ?? '',
                        facultyEmoji: f['emoji'] as String? ?? '🎓',
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
