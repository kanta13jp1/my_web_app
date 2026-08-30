import 'package:flutter/material.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../widgets/agent_workspace_panel.dart';
import 'people_help_page.dart';
import 'rewards_page.dart';

class ChroOfficePage extends StatefulWidget {
  const ChroOfficePage({super.key});

  @override
  State<ChroOfficePage> createState() => _ChroOfficePageState();
}

class _ChroOfficePageState extends State<ChroOfficePage> {
  final AgentOrgService _agentOrgService = AgentOrgService();
  AgentWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    try {
      final workspace = await _agentOrgService.loadWorkspaceBySlug('chro');
      if (!mounted) {
        return;
      }
      setState(() {
        _workspace = workspace;
        _isLoadingWorkspace = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingWorkspace = false);
    }
  }

  Future<void> _processTask(AgentTask task, String status) async {
    try {
      await _agentOrgService.processTask(task: task, status: status);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CHRO task updated: $status')));
      await _loadWorkspace();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update CHRO task: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('chro_office_page_scaffold'),
      appBar: AppBar(
        title: const Text('CHRO OFFICE'),
        backgroundColor: const Color(0xFF303F9F),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkspace,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AgentWorkspacePanel(
              officeLabel: 'CHRO',
              accentColor: const Color(0xFF3D5AFE),
              isLoading: _isLoadingWorkspace,
              workspace: _workspace,
              onProcessTask: _processTask,
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              'Achievements & Rewards',
              'Review points, levels, badges, and recognition in one place.',
              Icons.card_giftcard,
              const RewardsPage(),
              '/rewards',
            ),
            _buildMenuCard(
              context,
              'People Help',
              'Keep onboarding and support notes for team operations.',
              Icons.menu_book,
              const PeopleHelpPage(),
              '/people-help',
              tileKey: const Key('chro_menu_people_help'),
            ),
          ],
        ),
      ),
    );
  }

  /// [routeName] は遷移先画面の URL。`RouteSettings.name` を付けないと
  /// Flutter Web でブラウザの URL が更新されないため必須にしている。
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget? page,
    String routeName, {
    Key? tileKey,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFC5CAE9),
          child: Icon(icon, color: const Color(0xFF283593)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: page == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: RouteSettings(name: routeName),
                    builder: (_) => page,
                  ),
                ),
      ),
    );
  }
}
