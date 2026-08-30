import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/space_sharing_service.dart';
import 'note_editor_page.dart';

class SpaceSharingPage extends StatefulWidget {
  const SpaceSharingPage({
    super.key,
    this.dataSource,
    this.initialSpaceId,
  });

  final SpaceSharingDataSource? dataSource;
  final int? initialSpaceId;

  @override
  State<SpaceSharingPage> createState() => _SpaceSharingPageState();
}

class _SpaceSharingPageState extends State<SpaceSharingPage> {
  late final SpaceSharingDataSource _dataSource;
  SpaceSharingSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        SupabaseSpaceSharingDataSource(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _dataSource.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _mutate(
    Future<void> Function() operation,
    String success,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('space_sharing_page'),
      appBar: AppBar(
        title: const Text('Space共有'),
        actions: [
          IconButton(
            key: const Key('space_sharing_reload'),
            tooltip: '再読み込み',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text('Space共有情報を読み込めませんでした。\n$_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('再試行')),
            ],
          ),
        ),
      );
    }
    final snapshot = _snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = _buildContent(snapshot);
        if (constraints.maxWidth < 920) {
          return KeyedSubtree(
            key: const Key('space_sharing_narrow'),
            child: content,
          );
        }
        return Row(
          key: const Key('space_sharing_wide'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 300, child: _buildSummary(snapshot)),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildSummary(SpaceSharingSnapshot snapshot) {
    final managed =
        snapshot.spaces.where((space) => space.permission.canManage).length;
    final shared = snapshot.spaces
        .where((space) => space.permission != SpacePermission.owner)
        .length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('共有状況', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _metric('利用可能なSpace', snapshot.spaces.length),
        _metric('管理できるSpace', managed),
        _metric('共有されたSpace', shared),
        _metric('保留中の招待', snapshot.incomingInvitations.length),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Space内のノートとノートブックは同じ権限を継承します。'
              '閲覧のみのメンバーは内容を変更できません。',
            ),
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, int value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        '$value',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildContent(SpaceSharingSnapshot snapshot) {
    final spaces = [...snapshot.spaces];
    if (widget.initialSpaceId != null) {
      spaces.sort((left, right) {
        if (left.id == widget.initialSpaceId) return -1;
        if (right.id == widget.initialSpaceId) return 1;
        return left.name.compareTo(right.name);
      });
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('space_sharing_list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (snapshot.incomingInvitations.isNotEmpty) ...[
            Text(
              'あなたへの招待',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final invitation in snapshot.incomingInvitations)
              _invitationCard(invitation),
            const SizedBox(height: 16),
          ],
          if (spaces.isEmpty && snapshot.incomingInvitations.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '共有Spaceはまだありません。'
                  'コレクション画面でSpaceを作成してから招待できます。',
                ),
              ),
            ),
          for (final space in spaces) _spaceCard(snapshot, space),
        ],
      ),
    );
  }

  Widget _invitationCard(SpaceInvitationRecord invitation) {
    return Card(
      key: ValueKey<String>('space_invitation_${invitation.id}'),
      child: ListTile(
        leading: const Icon(Icons.mark_email_unread_outlined),
        title: Text(invitation.spaceName),
        subtitle: Text('${invitation.permission.label}として招待されています'),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            TextButton(
              key: ValueKey<String>(
                'space_invitation_decline_${invitation.id}',
              ),
              onPressed: _saving
                  ? null
                  : () => _mutate(
                        () => _dataSource.declineInvitation(invitation.id),
                        '招待を辞退しました。',
                      ),
              child: const Text('辞退'),
            ),
            FilledButton(
              key: ValueKey<String>(
                'space_invitation_accept_${invitation.id}',
              ),
              onPressed: _saving
                  ? null
                  : () => _mutate(
                        () => _dataSource.acceptInvitation(invitation.id),
                        'Spaceに参加しました。',
                      ),
              child: const Text('参加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spaceCard(
    SpaceSharingSnapshot snapshot,
    SpaceAccessRecord space,
  ) {
    final highlighted = space.id == widget.initialSpaceId;
    return Card(
      key: ValueKey<String>('space_${space.id}'),
      color:
          highlighted ? Theme.of(context).colorScheme.secondaryContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: highlighted,
        leading: const Icon(Icons.workspaces_outline),
        title: Text(space.name),
        subtitle: Text(
          '${space.permission.label} ・ ${space.notes.length}ノート'
          ' ・ ${space.members.length}メンバー',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (space.description.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(space.description),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (space.permission.canManage)
                OutlinedButton.icon(
                  key: ValueKey<String>('space_invite_${space.id}'),
                  onPressed: _saving ? null : () => _showInviteDialog(space),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('招待'),
                ),
              if (space.permission.canEdit)
                FilledButton.tonalIcon(
                  key: ValueKey<String>('space_create_note_${space.id}'),
                  onPressed: _saving ? null : () => _createDirectNote(space),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('直接ノート'),
                ),
              if (space.permission != SpacePermission.owner)
                TextButton.icon(
                  key: ValueKey<String>('space_leave_${space.id}'),
                  onPressed: _saving
                      ? null
                      : () => _confirmRemove(
                            space,
                            snapshot.currentUserId,
                            leaving: true,
                          ),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionTitle('メンバー'),
          if (space.members.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('招待済みメンバーはいません。'),
            ),
          for (final member in space.members) _memberTile(space, member),
          if (space.pendingInvitations.isNotEmpty) ...[
            _sectionTitle('保留中'),
            for (final invitation in space.pendingInvitations)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule_send_outlined),
                title: Text(invitation.email),
                subtitle: Text(invitation.permission.label),
                trailing: space.permission.canManage
                    ? IconButton(
                        key: ValueKey<String>(
                          'space_invitation_revoke_${invitation.id}',
                        ),
                        tooltip: '招待を取り消す',
                        onPressed: _saving
                            ? null
                            : () => _mutate(
                                  () => _dataSource
                                      .revokeInvitation(invitation.id),
                                  '招待を取り消しました。',
                                ),
                        icon: const Icon(Icons.cancel_outlined),
                      )
                    : null,
              ),
          ],
          _sectionTitle('ノート'),
          if (space.notes.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('このSpaceにはノートがありません。'),
            ),
          for (final note in space.notes) _noteTile(space, note),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }

  Widget _memberTile(
    SpaceAccessRecord space,
    SpaceMemberRecord member,
  ) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.person_outline),
      title: Text(member.email),
      subtitle: Text(member.permission.label),
      trailing: !space.permission.canManage
          ? null
          : Wrap(
              spacing: 2,
              children: [
                PopupMenuButton<SpacePermission>(
                  key: ValueKey<String>(
                    'space_member_permission_${member.userId}',
                  ),
                  tooltip: '権限を変更',
                  enabled: !_saving,
                  onSelected: (permission) => _mutate(
                    () => _dataSource.updateMemberPermission(
                      spaceId: space.id,
                      memberUserId: member.userId,
                      permission: permission,
                    ),
                    'メンバー権限を更新しました。',
                  ),
                  itemBuilder: (context) => [
                    for (final permission in const [
                      SpacePermission.fullAccess,
                      SpacePermission.edit,
                      SpacePermission.view,
                    ])
                      PopupMenuItem(
                        value: permission,
                        child: Text(permission.label),
                      ),
                  ],
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'space_member_remove_${member.userId}',
                  ),
                  tooltip: 'メンバーを削除',
                  onPressed: _saving
                      ? null
                      : () => _confirmRemove(space, member.userId),
                  icon: const Icon(Icons.person_remove_outlined),
                ),
              ],
            ),
    );
  }

  Widget _noteTile(
    SpaceAccessRecord space,
    SpaceNoteRecord note,
  ) {
    final notebookName = space.notebooks
        .where((item) => item.id == note.notebookId)
        .map((item) => item.name)
        .firstOrNull;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.description_outlined),
      title: Text(note.title.isEmpty ? '無題' : note.title),
      subtitle: Text(notebookName ?? 'Space直下'),
      onTap: () => _openNote(note.id),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            key: ValueKey<String>('space_note_open_${note.id}'),
            tooltip: '開く',
            onPressed: () => _openNote(note.id),
            icon: const Icon(Icons.open_in_new),
          ),
          if (space.permission.canEdit)
            IconButton(
              key: ValueKey<String>('space_note_move_${note.id}'),
              tooltip: '移動',
              onPressed: _saving ? null : () => _showMoveDialog(space, note),
              icon: const Icon(Icons.drive_file_move_outline),
            ),
        ],
      ),
    );
  }

  Future<void> _showInviteDialog(SpaceAccessRecord space) async {
    final emailController = TextEditingController();
    var permission = SpacePermission.edit;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${space.name}に招待'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('space_invite_email'),
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SpacePermission>(
                  key: const Key('space_invite_permission'),
                  initialValue: permission,
                  decoration: const InputDecoration(labelText: '権限'),
                  items: const [
                    SpacePermission.fullAccess,
                    SpacePermission.edit,
                    SpacePermission.view,
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => permission = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('space_invite_submit'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('招待'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.invite(
        spaceId: space.id,
        email: emailController.text,
        permission: permission,
      ),
      '招待を送信しました。',
    );
  }

  Future<void> _createDirectNote(SpaceAccessRecord space) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final noteId = await _dataSource.createDirectNote(spaceId: space.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NoteEditorPage(noteId: noteId.toString()),
        ),
      );
      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('共有ノートを作成できませんでした: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openNote(int noteId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(noteId: noteId.toString()),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _showMoveDialog(
    SpaceAccessRecord space,
    SpaceNoteRecord note,
  ) async {
    int? destination = note.notebookId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('共有ノートを移動'),
          content: DropdownButtonFormField<int?>(
            key: const Key('space_note_destination'),
            initialValue: destination,
            decoration: const InputDecoration(labelText: '移動先'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Space直下'),
              ),
              for (final notebook in space.notebooks)
                DropdownMenuItem<int?>(
                  value: notebook.id,
                  child: Text(notebook.name),
                ),
            ],
            onChanged: (value) => setDialogState(() => destination = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('space_note_move_submit'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('移動'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.moveNote(
        noteId: note.id,
        destinationNotebookId: destination,
      ),
      '共有ノートを移動しました。',
    );
  }

  Future<void> _confirmRemove(
    SpaceAccessRecord space,
    String memberUserId, {
    bool leaving = false,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          leaving ? '${space.name}から退出しますか？' : 'メンバーを削除しますか？',
        ),
        content: const Text(
          '共有権限は直ちに失われます。既に作成されたノートはSpaceに残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('space_member_remove_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(leaving ? '退出' : '削除'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.removeMember(
        spaceId: space.id,
        memberUserId: memberUserId,
      ),
      leaving ? 'Spaceから退出しました。' : 'メンバーを削除しました。',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
