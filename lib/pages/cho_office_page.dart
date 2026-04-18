import 'package:flutter/material.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../widgets/agent_workspace_panel.dart';
import 'health_page.dart';
import 'medical_notes_page.dart';
import 'mental_check_page.dart';

class ChoOfficePage extends StatefulWidget {
  const ChoOfficePage({super.key});

  @override
  State<ChoOfficePage> createState() => _ChoOfficePageState();
}

class _ChoOfficePageState extends State<ChoOfficePage> {
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
      final workspace = await _agentOrgService.loadWorkspaceBySlug('cho');
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
      ).showSnackBar(SnackBar(content: Text('CHO task updated: $status')));
      await _loadWorkspace();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update CHO task: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHO OFFICE'),
        backgroundColor: const Color(0xFF009688)[700],
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkspace,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AgentWorkspacePanel(
              officeLabel: 'CHO',
              accentColor: const Color(0xFF009688),
              isLoading: _isLoadingWorkspace,
              workspace: _workspace,
              onProcessTask: _processTask,
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              'Health Log',
              'Track health routines, sleep, and condition records.',
              Icons.favorite,
              const HealthPage(),
            ),
            _buildMenuCard(
              context,
              'Mental Check',
              'Review stress and focus signals and keep a simple health check.',
              Icons.psychology,
              const MentalCheckPage(),
            ),
            _buildMenuCard(
              context,
              'Medical Notes',
              'Keep treatment notes and review health-related actions.',
              Icons.medical_services,
              const MedicalNotesPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget? page,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF009688)[100],
          child: Icon(icon, color: const Color(0xFF009688)[800]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: page != null
            ? () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => page))
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                ),
      ),
    );
  }
}
