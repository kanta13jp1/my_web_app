import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import 'note_editor_page.dart'; // CKO
import 'ai_status_page.dart'; // CSO
import 'danshari_page.dart'; // CSO (Tinder-style)
import 'gemini_university_page.dart'; // CKO
import 'emergency_meeting_page.dart'; // CEO
import 'real_world_danshari_page.dart'; // CSO (Real)

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    const Color primaryColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark ? Colors.black87 : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('自分株式会社 経営コックピット'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeService.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
                'CEO OFFICE', Icons.business_center, Colors.redAccent),
            _buildCeoCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader('CSO OFFICE', Icons.flag, Colors.orange),
            _buildGridMenu(context, [
              _MenuData('断捨離 (デジタル)', Icons.cleaning_services, Colors.orange,
                  () => _nav(context, const DanshariPage())),
              _MenuData('断捨離 (リアル)', Icons.camera_alt, Colors.deepOrange,
                  () => _nav(context, const RealWorldDanshariPage())),
              _MenuData('AI稼働モニター', Icons.monitor_heart, Colors.orange,
                  () => _nav(context, const AiStatusPage())),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('CKO OFFICE', Icons.school, Colors.blue),
            _buildGridMenu(context, [
              _MenuData('新規事業起案', Icons.edit_note, Colors.blue,
                  () => _nav(context, const NoteEditorPage())),
              _MenuData('Gemini大学', Icons.menu_book, Colors.blue,
                  () => _nav(context, const GeminiUniversityPage())),
            ]),
          ],
        ),
      ),
    );
  }

  void _nav(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCeoCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        leading: const CircleAvatar(
            backgroundColor: Colors.redAccent,
            radius: 28,
            child: Icon(Icons.emergency, color: Colors.white, size: 30)),
        title: const Text('緊急役員会議',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text('CEOとして全AI役員を招集し、直面している課題を解決します。'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const EmergencyMeetingPage())),
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, List<_MenuData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(item.icon, color: item.color, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuData(this.title, this.icon, this.color, this.onTap);
}
