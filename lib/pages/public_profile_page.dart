import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// ユーザーの公開プロフィールページ。
/// /u/:userId でアクセスでき、非ログインユーザーも閲覧可能。
/// ソーシャルシェアで新規登録を促すバイラル成長ページ。
class PublicProfilePage extends StatefulWidget {
  final String userId;

  const PublicProfilePage({super.key, required this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _notFound = false;

  String? _displayName;
  String? _bio;
  String? _avatarUrl;
  String? _websiteUrl;
  String? _twitterHandle;
  String? _githubHandle;
  int _noteCount = 0;
  final int _streak = 0;
  String? _location;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _supabase
          .from('user_profiles')
          .select(
            'display_name, bio, avatar_url, website_url, twitter_handle, '
            'github_handle, location, is_public',
          )
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (profile == null || profile['is_public'] != true) {
        if (mounted) {
          setState(() {
            _notFound = true;
            _loading = false;
          });
        }
        return;
      }

      final noteRes = await _supabase
          .from('notes')
          .select('id')
          .eq('user_id', widget.userId)
          .count(CountOption.exact);

      if (!mounted) return;
      setState(() {
        _displayName = profile['display_name']?.toString();
        _bio = profile['bio']?.toString();
        _avatarUrl = profile['avatar_url']?.toString();
        _websiteUrl = profile['website_url']?.toString();
        _twitterHandle = profile['twitter_handle']?.toString();
        _githubHandle = profile['github_handle']?.toString();
        _location = profile['location']?.toString();
        _noteCount = noteRes.count;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  String get _profileUrl =>
      'https://my-web-app-b67f4.web.app/u/${widget.userId}';

  Future<void> _shareOnX() async {
    final name = _displayName ?? 'ユーザー';
    final text = Uri.encodeComponent(
      '$nameさんのプロフィール — 自分株式会社 🏢\n'
      'ノート数: $_noteCount件\n'
      '#自分株式会社 #buildinpublic\n$_profileUrl',
    );
    await launchUrl(
      Uri.parse('https://x.com/intent/tweet?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _profileUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('プロフィールURLをコピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwnProfile = _supabase.auth.currentUser?.id == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName ?? '公開プロフィール'),
        actions: [
          if (!_loading && !_notFound) ...[
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'リンクをコピー',
              onPressed: _copyLink,
            ),
            IconButton(
              icon: const Text('𝕏', style: TextStyle(fontSize: 16)),
              tooltip: 'Xでシェア',
              onPressed: _shareOnX,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? _buildNotFound(isDark)
              : _buildProfile(isDark, isOwnProfile),
    );
  }

  Widget _buildNotFound(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'プロフィールが見つかりません',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '非公開または存在しないユーザーです',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.home),
            label: const Text('トップページへ'),
            onPressed: () => Navigator.of(context).pushNamed('/'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(bool isDark, bool isOwnProfile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Name
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF6366F1).withAlpha(30),
                backgroundImage:
                    _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? Text(
                        (_displayName?.isNotEmpty == true)
                            ? _displayName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName ?? 'ユーザー',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    if (_location?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _location!,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isOwnProfile)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('編集', style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/profile-settings'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Bio
          if (_bio?.isNotEmpty == true) ...[
            Text(
              _bio!,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2233) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(label: 'ノート数', value: '$_noteCount', isDark: isDark),
                Container(
                    width: 1,
                    height: 32,
                    color: isDark ? Colors.white12 : Colors.black12,),
                _StatChip(label: 'ストリーク', value: '$_streak日', isDark: isDark),
                Container(
                    width: 1,
                    height: 32,
                    color: isDark ? Colors.white12 : Colors.black12,),
                _StatChip(label: '自分株式会社', value: '登録中', isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Social links
          if (_twitterHandle?.isNotEmpty == true)
            _SocialLink(
              icon: const Text('𝕏', style: TextStyle(fontSize: 14)),
              label: '@$_twitterHandle',
              onTap: () => launchUrl(
                Uri.parse('https://x.com/$_twitterHandle'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (_githubHandle?.isNotEmpty == true)
            _SocialLink(
              icon: const Icon(Icons.code, size: 18),
              label: _githubHandle!,
              onTap: () => launchUrl(
                Uri.parse('https://github.com/$_githubHandle'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (_websiteUrl?.isNotEmpty == true)
            _SocialLink(
              icon: const Icon(Icons.link, size: 18),
              label: _websiteUrl!,
              onTap: () => launchUrl(
                Uri.parse(_websiteUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),

          const SizedBox(height: 24),

          // CTA for non-logged-in users
          if (_supabase.auth.currentUser == null) ...[
            const Divider(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    '自分株式会社で\nあなたの成長を記録しよう',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notion・Evernote・Slack など21社の機能を1つに統合',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pushNamed('/'),
                    child: const Text(
                      '無料で始める',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _SocialLink extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _SocialLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6366F1),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
