import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';
import 'package:my_web_app/widgets/micro_survey_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// チームワークスペースページ
/// チームの作成・参加・共有ノートの閲覧
class TeamWorkspacePage extends StatefulWidget {
  const TeamWorkspacePage({super.key});

  @override
  State<TeamWorkspacePage> createState() => _TeamWorkspacePageState();
}

class _TeamWorkspacePageState extends State<TeamWorkspacePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['my-teams', 'joined'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  List<Map<String, dynamic>> _myTeams = [];
  List<Map<String, dynamic>> _memberTeams = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final owned = await _supabase
          .from('teams')
          .select('*, team_memberships(count)')
          .eq('owner_id', userId)
          .order('created_at', ascending: false);

      final memberships = await _supabase
          .from('team_memberships')
          .select('team_id, teams(*)')
          .eq('user_id', userId);

      final ownedList = List<Map<String, dynamic>>.from(owned as List);
      final membershipList =
          List<Map<String, dynamic>>.from(memberships as List);
      final ownedIds = ownedList.map((t) => t['id'] as String).toSet();

      // Teams where user is member but not owner
      final memberTeams = membershipList
          .where((m) => !ownedIds.contains(m['team_id'] as String))
          .map((m) {
        final raw = m['teams'];
        return (raw is Map<String, dynamic>)
            ? raw
            : Map<String, dynamic>.from(raw as Map);
      }).toList();

      if (mounted) {
        setState(() {
          _myTeams = ownedList;
          _memberTeams = List<Map<String, dynamic>>.from(memberTeams);
          _isLoading = false;
        });
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込みエラー: $e')),
        );
      }
    }
  }

  Future<void> _createTeam() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    String name = '';
    String description = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateTeamDialog(
        onConfirm: (n, d) {
          name = n;
          description = d;
        },
      ),
    );
    if (result != true || name.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('teams').insert({
        'name': name.trim(),
        'description': description.trim(),
        'owner_id': userId,
      });
      await _loadTeams();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チームを作成しました')),
        );
        await presentMicroSurveyIfEligible(
          context: context,
          repository: SupabaseMicroSurveyRepository(_supabase),
          surveyContext: const MicroSurveyContext(
            trigger: MicroSurveyTrigger.resourceCreated,
            route: '/team-workspace',
            resourceType: 'team',
          ),
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成エラー: $e')),
        );
      }
    }
  }

  Future<void> _joinByInviteCode() async {
    if (_supabase.auth.currentUser == null) return;

    String code = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _JoinTeamDialog(
        onConfirm: (c) => code = c,
      ),
    );
    if (result != true || code.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await _supabase.rpc(
        'join_team_with_invite_code',
        params: {'p_invite_code': code.trim()},
      );
      final teams = response as List<dynamic>;
      if (teams.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('招待コードが見つかりません')),
          );
        }
        return;
      }
      final team = teams.first as Map<String, dynamic>;
      await _loadTeams();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${team['team_name']}」に参加しました')),
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('参加エラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteTeam(String teamId, String teamName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チームを削除'),
        content: Text('「$teamName」を削除しますか？\nすべての共有ノートの関連も解除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('teams').delete().eq('id', teamId).select();
      await _loadTeams();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チームを削除しました')),
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  Future<void> _leaveTeam(String teamId, String teamName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チームを退出'),
        content: Text('「$teamName」から退出しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('team_memberships')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .select();
      await _loadTeams();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チームから退出しました')),
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退出エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チームワークスペース'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '自分のチーム'),
            Tab(text: '参加中'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _loadTeams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OwnedTeamsTab(
                  teams: _myTeams,
                  onDelete: _deleteTeam,
                ),
                _MemberTeamsTab(
                  teams: _memberTeams,
                  onLeave: _leaveTeam,
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'join',
            tooltip: '招待コードで参加',
            onPressed: _joinByInviteCode,
            child: const Icon(Icons.person_add_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: _createTeam,
            icon: const Icon(Icons.group_add),
            label: const Text('チームを作成'),
          ),
        ],
      ),
    );
  }
}

class _OwnedTeamsTab extends StatelessWidget {
  const _OwnedTeamsTab({
    required this.teams,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> teams;
  final void Function(String id, String name) onDelete;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'まだチームがありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '右下のボタンから最初のチームを作成しましょう',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final team = teams[i];
          return _TeamCard(
            team: team,
            isOwner: true,
            onDelete: () => onDelete(
              team['id'] as String,
              team['name'] as String,
            ),
          );
        },
      ),
    );
  }
}

class _MemberTeamsTab extends StatelessWidget {
  const _MemberTeamsTab({
    required this.teams,
    required this.onLeave,
  });

  final List<Map<String, dynamic>> teams;
  final void Function(String id, String name) onLeave;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '参加中のチームはありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '招待コードを使ってチームに参加できます',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: teams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final team = teams[i];
        return _TeamCard(
          team: team,
          isOwner: false,
          onLeave: () => onLeave(
            team['id'] as String,
            team['name'] as String,
          ),
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.isOwner,
    this.onDelete,
    this.onLeave,
  });

  final Map<String, dynamic> team;
  final bool isOwner;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final name = team['name'] as String? ?? '';
    final description = team['description'] as String? ?? '';
    final inviteCode = team['invite_code'] as String? ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFC5CAE9),
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D5AFE),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      if (isOwner)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1A1A2E)
                                    : const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'オーナー',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF3D5AFE),
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isOwner && onDelete != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFE53935),
                    ),
                    tooltip: 'チームを削除',
                    onPressed: onDelete,
                  )
                else if (!isOwner && onLeave != null)
                  IconButton(
                    icon:
                        const Icon(Icons.exit_to_app, color: Color(0xFF9CA3AF)),
                    tooltip: 'チームを退出',
                    onPressed: onLeave,
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (isOwner && inviteCode.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.vpn_key_outlined,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '招待コード: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      inviteCode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('招待コードをコピーしました'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateTeamDialog extends StatefulWidget {
  const _CreateTeamDialog({required this.onConfirm});

  final void Function(String name, String description) onConfirm;

  @override
  State<_CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<_CreateTeamDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新規チーム作成'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'チーム名 *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: '説明 (任意)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            widget.onConfirm(
              _nameController.text,
              _descController.text,
            );
            Navigator.pop(context, true);
          },
          child: const Text('作成'),
        ),
      ],
    );
  }
}

class _JoinTeamDialog extends StatefulWidget {
  const _JoinTeamDialog({required this.onConfirm});

  final void Function(String code) onConfirm;

  @override
  State<_JoinTeamDialog> createState() => _JoinTeamDialogState();
}

class _JoinTeamDialogState extends State<_JoinTeamDialog> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('チームに参加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'チームオーナーから招待コードを受け取り、入力してください。',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: '招待コード (8文字または32文字)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9A-Z]')),
              LengthLimitingTextInputFormatter(32),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            widget.onConfirm(_codeController.text);
            Navigator.pop(context, true);
          },
          child: const Text('参加'),
        ),
      ],
    );
  }
}
