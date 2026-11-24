import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../pages/admin_dashboard_signals.dart';

class AdminUsersCard extends StatefulWidget {
  const AdminUsersCard({
    super.key,
    required this.users,
    required this.totalUsers,
    required this.loading,
    required this.onRefresh,
    required this.onUpdateUserProfile,
  });

  final List<Map<String, dynamic>> users;
  final int totalUsers;
  final bool loading;
  final VoidCallback onRefresh;
  final Future<void> Function(
    String userId,
    Map<String, dynamic> updates,
  ) onUpdateUserProfile;

  @override
  State<AdminUsersCard> createState() => _AdminUsersCardState();
}

class _AdminUsersCardState extends State<AdminUsersCard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Widget _buildProfileCompletionSummary() {
    // R19: 旧サマリは未fetch の completionPct(全員0)で「0完成/0途中/44未設定」を
    // 捏造していた。email 空=匿名 auth を信頼プロキシに「実ユーザー/匿名テスト」へ
    // 誠実に分割する(合計44 vs 実CVR4 の乖離=匿名を実登録と誤認する虚栄を防ぐ)。
    final split = summarizeAdminUsers(widget.users);
    return Row(
      children: [
        _profileStatChip(
          Icons.verified_user_outlined,
          '実ユーザー ${split.real}人',
          const Color(0xFF0D9488),
        ),
        const SizedBox(width: 8),
        _profileStatChip(
          Icons.help_outline,
          '匿名テスト ${split.anon}人',
          const Color(0xFF9CA3AF),
        ),
      ],
    );
  }

  Widget _profileStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _showUserProfileDialog(Map<String, dynamic> user) {
    showDialog<void>(
      context: context,
      builder: (_) => _AdminUserProfileDialog(
        user: user,
        onUpdateUserProfile: widget.onUpdateUserProfile,
        onUpdated: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.users;
    final split = summarizeAdminUsers(users);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Color(0xFF3949AB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    users.isEmpty
                        ? '登録ユーザー管理 (合計 ${widget.totalUsers} 人)'
                        : '登録ユーザー管理 (合計 ${widget.totalUsers} 人 / '
                            '実 ${split.real}・'
                            '匿名 ${split.anon})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: widget.onRefresh,
                  tooltip: '更新',
                ),
              ],
            ),
            if (users.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildProfileCompletionSummary(),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const Key('admin_users_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'メール・表示名で検索...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        key: const Key('admin_users_search_clear'),
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
              style: const TextStyle(fontSize: 13, height: 1.6),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 8),
            if (widget.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'ユーザーが取得できませんでした',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final filteredUsers = _searchQuery.isEmpty
                      ? users
                      : users.where((u) {
                          final q = _searchQuery.toLowerCase();
                          final email =
                              u['email']?.toString().toLowerCase() ?? '';
                          final name =
                              u['displayName']?.toString().toLowerCase() ?? '';
                          return email.contains(q) || name.contains(q);
                        }).toList();
                  if (filteredUsers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '該当するユーザーが見つかりません',
                        style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final email = user['email']?.toString() ?? '';
                      final displayName = user['displayName']?.toString();
                      final bio = user['bio']?.toString();
                      final location = user['location']?.toString();
                      final provider = user['provider']?.toString() ?? 'email';
                      // R19: edge は created_at(snake)を返すのに旧UIは createdAt
                      // (camel)を読み全行の登録日が空だった。snake 優先で吸収する。
                      final createdAt = adminUserCreatedRaw(user);
                      final lastSignIn = user['lastSignInAt']?.toString() ?? '';
                      // R19: email 空 = Supabase 匿名 auth(headless 検証)の信頼プロキシ。
                      final isAnonymous = adminUserIsAnonymous(user);

                      // R19: 登録日=parse 不可なら「日付なし」、最終ログインは edge が
                      // 未送出のため「ログイン記録なし」と正直に出す(空欄で誤魔化さない)。
                      String createdStr = '日付なし';
                      String lastSignInStr = 'ログイン記録なし';
                      try {
                        createdStr = DateFormat(
                          'yyyy/MM/dd',
                        ).format(DateTime.parse(createdAt).toLocal());
                      } catch (_) {}
                      try {
                        lastSignInStr = DateFormat(
                          'MM/dd HH:mm',
                        ).format(DateTime.parse(lastSignIn).toLocal());
                      } catch (_) {}

                      final isGoogle = provider.contains('google');
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isGoogle
                                  ? (isDark
                                      ? const Color(0xFF0D2E1A)
                                      : const Color(0xFFE8F5E9))
                                  : (isDark
                                      ? const Color(0xFF1A1E3A)
                                      : const Color(0xFFE8EAF6)),
                              child: Text(
                                email.isNotEmpty
                                    ? email[0].toUpperCase()
                                    : (isAnonymous ? '匿' : '?'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isGoogle
                                      ? const Color(0xFF388E3C)
                                      : const Color(0xFF3949AB),
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName != null &&
                                                  displayName.isNotEmpty
                                              ? displayName
                                              : (email.isNotEmpty
                                                  ? email
                                                  : '匿名ユーザー'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isGoogle
                                              ? (isDark
                                                  ? const Color(0xFF0D2E1A)
                                                  : const Color(0xFFE8F5E9))
                                              : (isDark
                                                  ? const Color(0xFF1A1E3A)
                                                  : const Color(0xFFE8EAF6)),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          // R30: edge users.list は provider を
                                          // 返さない → isGoogle は常に false で
                                          // 全員 'Email' と誤表示していた。
                                          // 判別不能なので中立の '登録済' にする。
                                          isAnonymous ? '匿名' : '登録済',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isGoogle
                                                ? const Color(0xFF388E3C)
                                                : const Color(0xFF3949AB),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (displayName != null &&
                                      displayName.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        height: 1.5,
                                      ),
                                    ),
                                  if (bio != null && bio.isNotEmpty)
                                    Text(
                                      bio,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (location != null && location.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 11,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        Text(
                                          location,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  // R19: completionPct は users.list が未送出で常に0。
                                  // 「プロフィール 0%」バーは捏造なので出さず、未取得を
                                  // 正直に表示する(R17 の display-truthfulness 規律)。
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'プロフィール情報 未取得',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '登録: $createdStr　最終ログイン: $lastSignInStr',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showUserProfileDialog(user),
                                      icon: const Icon(
                                        Icons.person_outline,
                                        size: 13,
                                      ),
                                      label: const Text(
                                        'プロフィール詳細',
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF3949AB,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
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
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserProfileDialog extends StatefulWidget {
  const _AdminUserProfileDialog({
    required this.user,
    required this.onUpdateUserProfile,
    required this.onUpdated,
  });

  final Map<String, dynamic> user;
  final Future<void> Function(
    String userId,
    Map<String, dynamic> updates,
  ) onUpdateUserProfile;
  final VoidCallback onUpdated;

  @override
  State<_AdminUserProfileDialog> createState() =>
      _AdminUserProfileDialogState();
}

class _AdminUserProfileDialogState extends State<_AdminUserProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _twitterCtrl;
  late final TextEditingController _githubCtrl;
  late final TextEditingController _websiteCtrl;

  bool _editMode = false;
  bool _saving = false;
  late bool _editIsPublic;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameCtrl = TextEditingController(
      text: user['displayName']?.toString() ?? '',
    );
    _bioCtrl = TextEditingController(text: user['bio']?.toString() ?? '');
    _locationCtrl = TextEditingController(
      text: user['location']?.toString() ?? '',
    );
    _twitterCtrl = TextEditingController(
      text: user['twitterHandle']?.toString() ?? '',
    );
    _githubCtrl = TextEditingController(
      text: user['githubHandle']?.toString() ?? '',
    );
    _websiteCtrl = TextEditingController(
      text: user['websiteUrl']?.toString() ?? '',
    );
    _editIsPublic = user['isPublic'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _twitterCtrl.dispose();
    _githubCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Widget _profileFieldRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  /// Profile detail row that shows "未設定" with a muted style for empty values.
  Widget _profileDetailRow(IconData icon, String label, String value) {
    final isEmpty = value.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: isEmpty ? const Color(0xFFF87171) : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            isEmpty ? '未設定' : value,
            style: TextStyle(
              fontSize: 12,
              color: isEmpty ? const Color(0xFFF87171) : null,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              height: 1.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Future<void> _saveProfile(String userId) async {
    setState(() => _saving = true);
    try {
      await widget.onUpdateUserProfile(userId, <String, dynamic>{
        'display_name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'twitter_handle': _twitterCtrl.text.trim(),
        'github_handle': _githubCtrl.text.trim(),
        'website_url': _websiteCtrl.text.trim(),
        'is_public': _editIsPublic,
      });
      if (!mounted) return;
      setState(() {
        _editMode = false;
        _saving = false;
      });
      widget.onUpdated();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final userId = user['id']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final displayName = user['displayName']?.toString() ?? '';
    final bio = user['bio']?.toString() ?? '';
    final location = user['location']?.toString() ?? '';
    final twitterHandle = user['twitterHandle']?.toString() ?? '';
    final githubHandle = user['githubHandle']?.toString() ?? '';
    final websiteUrl = user['websiteUrl']?.toString() ?? '';
    final avatarUrl = user['avatarUrl']?.toString() ?? '';
    final isPublic = user['isPublic'] as bool? ?? true;
    final completionPct = _AdminUsersCardState._toInt(user['completionPct']);
    final hasProfile = user['hasProfile'] as bool? ?? false;
    final provider = user['provider']?.toString() ?? 'email';
    final isGoogle = provider.contains('google');
    final createdAt = adminUserCreatedRaw(user);
    final lastSignIn = user['lastSignInAt']?.toString() ?? '';

    String createdStr = '';
    String lastSignInStr = '';
    try {
      createdStr = DateFormat(
        'yyyy/MM/dd HH:mm',
      ).format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}
    try {
      lastSignInStr = DateFormat(
        'yyyy/MM/dd HH:mm',
      ).format(DateTime.parse(lastSignIn).toLocal());
    } catch (_) {}

    Color profileColor;
    if (!hasProfile || completionPct < 34) {
      profileColor = const Color(0xFFB91C1C);
    } else if (completionPct < 67) {
      profileColor = const Color(0xFFFF6B35);
    } else {
      profileColor = const Color(0xFF0D9488);
    }

    final missingFields = <String>[];
    if (displayName.isEmpty) missingFields.add('表示名');
    if (bio.isEmpty) missingFields.add('自己紹介');
    if (avatarUrl.isEmpty) missingFields.add('アバター');
    if (location.isEmpty) missingFields.add('場所');
    if (twitterHandle.isEmpty) missingFields.add('Twitter/X');
    if (githubHandle.isEmpty) missingFields.add('GitHub');
    if (websiteUrl.isEmpty) missingFields.add('ウェブサイト');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          if (avatarUrl.isNotEmpty)
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(avatarUrl),
              onBackgroundImageError: (_, __) {},
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: isGoogle
                  ? (isDark ? const Color(0xFF0D2E1A) : const Color(0xFFE8F5E9))
                  : (isDark
                      ? const Color(0xFF1A1E3A)
                      : const Color(0xFFE8EAF6)),
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isGoogle
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF3949AB),
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                if (displayName.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      isPublic ? Icons.public : Icons.lock_outlined,
                      size: 12,
                      color: const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isPublic ? '公開プロフィール' : '非公開プロフィール',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_editMode)
            Chip(
              label: const Text(
                '編集中',
                style: TextStyle(fontSize: 10, height: 1.5),
              ),
              backgroundColor:
                  isDark ? const Color(0xFF0A1A2E) : const Color(0xFFE3F2FD),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completionPct / 100,
                        minHeight: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          profileColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'プロフィール $completionPct%',
                    style: TextStyle(
                      fontSize: 12,
                      color: profileColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (!_editMode) ...[
                _profileDetailRow(
                  Icons.person_outlined,
                  '表示名',
                  displayName,
                ),
                const SizedBox(height: 8),
                _profileDetailRow(Icons.notes_outlined, '自己紹介', bio),
                const SizedBox(height: 8),
                _profileDetailRow(
                  Icons.image_outlined,
                  'アバター画像',
                  avatarUrl,
                ),
                const SizedBox(height: 8),
                _profileDetailRow(
                  Icons.location_on_outlined,
                  '場所',
                  location,
                ),
                const SizedBox(height: 8),
                _profileDetailRow(
                  Icons.alternate_email,
                  'Twitter/X',
                  twitterHandle.isNotEmpty ? '@$twitterHandle' : '',
                ),
                const SizedBox(height: 8),
                _profileDetailRow(
                  Icons.code,
                  'GitHub',
                  githubHandle.isNotEmpty ? '@$githubHandle' : '',
                ),
                const SizedBox(height: 8),
                _profileDetailRow(
                  Icons.link_outlined,
                  'ウェブサイト',
                  websiteUrl,
                ),
                const SizedBox(height: 8),
                _profileDetailRow(
                  isPublic ? Icons.public : Icons.lock_outlined,
                  '公開設定',
                  isPublic ? '公開' : '非公開',
                ),
                if (!hasProfile || missingFields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            !hasProfile
                                ? 'プロフィールが未作成です。'
                                : '未設定の項目: ${missingFields.join('、')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '表示名',
                    prefixIcon: Icon(Icons.person_outlined, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: '自己紹介',
                    prefixIcon: Icon(Icons.notes_outlined, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: '場所',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _twitterCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Twitter/X (@なし)',
                    prefixIcon: Icon(Icons.alternate_email, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _githubCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GitHub (@なし)',
                    prefixIcon: Icon(Icons.code, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _websiteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ウェブサイト URL',
                    prefixIcon: Icon(Icons.link_outlined, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.public,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '公開プロフィール',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                    const Spacer(),
                    Switch(
                      value: _editIsPublic,
                      onChanged: (v) => setState(() => _editIsPublic = v),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _profileFieldRow(
                Icons.calendar_today_outlined,
                '登録日',
                createdStr,
              ),
              const SizedBox(height: 4),
              _profileFieldRow(
                Icons.login_outlined,
                '最終ログイン',
                lastSignInStr,
              ),
              const SizedBox(height: 4),
              _profileFieldRow(
                isGoogle ? Icons.g_mobiledata : Icons.email_outlined,
                '認証方法',
                isGoogle ? 'Google OAuth' : 'メール/パスワード',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_editMode) {
              setState(() => _editMode = false);
            } else {
              Navigator.pop(context);
            }
          },
          child: Text(_editMode ? 'キャンセル' : '閉じる'),
        ),
        if (!_editMode)
          TextButton.icon(
            onPressed: () => setState(() => _editMode = true),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('編集'),
          )
        else
          FilledButton.icon(
            onPressed: _saving ? null : () => _saveProfile(userId),
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE5E7EB),
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 16),
            label: Text(_saving ? '保存中...' : '保存'),
          ),
      ],
    );
  }
}
