import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../services/gamification_service.dart';
import '../widgets/agent_workspace_panel.dart';
import '../widgets/chro_gamification_summary_card.dart';
import 'people_help_page.dart';
import 'rewards_page.dart';

class ChroOfficePage extends StatefulWidget {
  final GamificationService? gamificationService;
  final AgentOrgService? agentOrgService;
  final AgentWorkspaceSnapshot? initialWorkspace;

  const ChroOfficePage({
    super.key,
    this.gamificationService,
    this.agentOrgService,
    this.initialWorkspace,
  });

  @override
  State<ChroOfficePage> createState() => _ChroOfficePageState();
}

class _ChroOfficePageState extends State<ChroOfficePage> {
  AgentOrgService? _ownedAgentOrgService;
  GamificationService? _ownedGamificationService;
  late GamificationService _gamificationService;
  bool _gamificationResolved = false;

  AgentWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = true;
  bool _isEvaluatingAchievements = false;
  List<Achievement> _unlockedAchievements = <Achievement>[];

  AgentOrgService get _resolvedAgentOrgService =>
      widget.agentOrgService ?? (_ownedAgentOrgService ??= AgentOrgService());

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkspace != null) {
      _workspace = widget.initialWorkspace;
      _isLoadingWorkspace = false;
    } else {
      _loadWorkspace();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gamificationResolved) {
      _gamificationResolved = true;
      if (widget.gamificationService != null) {
        _gamificationService = widget.gamificationService!;
      } else {
        try {
          _gamificationService =
              Provider.of<GamificationService>(context, listen: false);
        } catch (_) {
          _ownedGamificationService = GamificationService();
          _gamificationService = _ownedGamificationService!;
        }
      }
      _unlockedAchievements = _gamificationService.recentUnlocked;
      _refreshAchievements();
    }
  }

  @override
  void dispose() {
    _ownedGamificationService?.dispose();
    super.dispose();
  }

  Future<void> _refreshAchievements({bool evaluateNow = false}) async {
    if (evaluateNow && mounted) {
      setState(() => _isEvaluatingAchievements = true);
    }
    try {
      if (evaluateNow) {
        await _gamificationService.checkAchievements(
          contextNote: 'CHROオフィスでの再評価',
        );
      }
      final unlocked = await _gamificationService.getUserAchievements();
      if (!mounted) {
        return;
      }
      setState(() {
        _unlockedAchievements = unlocked;
        _isEvaluatingAchievements = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isEvaluatingAchievements = false);
    }
  }

  Future<void> _loadWorkspace() async {
    try {
      final workspace =
          await _resolvedAgentOrgService.loadWorkspaceBySlug('chro');
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
      await _resolvedAgentOrgService.processTask(task: task, status: status);
      if (status == 'completed') {
        await _gamificationService.recordActivity(
          tasksCompletedDelta: 1,
          contextNote: task.title,
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CHRO task updated: $status')));
      await _loadWorkspace();
      await _refreshAchievements();
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
        onRefresh: () async {
          await _loadWorkspace();
          await _refreshAchievements();
        },
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
            ListenableBuilder(
              listenable: _gamificationService,
              builder: (context, _) {
                final summary = _gamificationService.buildChroSummary();
                final unlocked = _gamificationService.recentUnlocked.isNotEmpty
                    ? _gamificationService.recentUnlocked
                    : _unlockedAchievements;
                return ChroGamificationSummaryCard(
                  summary: summary,
                  unlockedAchievements: unlocked,
                  isEvaluating: _isEvaluatingAchievements,
                  onEvaluate: () => _refreshAchievements(evaluateNow: true),
                );
              },
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
