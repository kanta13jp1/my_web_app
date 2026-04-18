import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ホーム画面でプロフィール未設定ユーザーに設定を促すバナー。
/// display_name または bio が未設定の場合に表示される。
class ProfileCompletionBanner extends StatefulWidget {
  const ProfileCompletionBanner({super.key});

  @override
  State<ProfileCompletionBanner> createState() =>
      _ProfileCompletionBannerState();
}

class _ProfileCompletionBannerState extends State<ProfileCompletionBanner> {
  bool _loading = true;
  bool _needsProfile = false;
  List<String> _missingFields = [];
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'display_name, bio, avatar_url, location, twitter_handle, github_handle, website_url',
          )
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (data == null) {
        // No profile row at all
        setState(() {
          _needsProfile = true;
          _missingFields = [
            '表示名',
            '自己紹介',
            'プロフィール画像',
            '場所',
          ];
          _loading = false;
        });
        return;
      }

      final fields = <String>[];
      if ((data['display_name']?.toString() ?? '').isEmpty) {
        fields.add('表示名');
      }
      if ((data['bio']?.toString() ?? '').isEmpty) {
        fields.add('自己紹介');
      }
      if ((data['avatar_url']?.toString() ?? '').isEmpty) {
        fields.add('プロフィール画像');
      }
      if ((data['location']?.toString() ?? '').isEmpty) {
        fields.add('場所');
      }
      if ((data['twitter_handle']?.toString() ?? '').isEmpty) {
        fields.add('Twitter/X');
      }
      if ((data['github_handle']?.toString() ?? '').isEmpty) {
        fields.add('GitHub');
      }
      if ((data['website_url']?.toString() ?? '').isEmpty) {
        fields.add('ウェブサイト');
      }

      setState(() {
        _missingFields = fields;
        _needsProfile = fields.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_needsProfile || _dismissed) {
      return const SizedBox.shrink();
    }

    // Show up to 3 missing field names, then "他N件" if more
    final displayFields = _missingFields.length <= 3
        ? _missingFields.join('、')
        : '${_missingFields.take(3).join('、')}　他${_missingFields.length - 3}件';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Color(0xFF4B5563) : Color(0xFFE0E7FF),
        ),
      ),
      color: isDark
          ? Color(0xFF1E1B4B).withAlpha(80)
          : Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    isDark ? Color(0xFF4B5563) : Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.person_outline,
                color: isDark ? Colors.white70 : Color(0xFF4338CA),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'プロフィールを完成させましょう',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Color(0xFF3730A3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$displayFieldsが未設定です。',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '設定すると他のユーザーに見つけてもらいやすくなります。',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/profile-settings'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.white70 : Color(0xFF4338CA),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '設定する',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: const Text(
                    '後で',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
