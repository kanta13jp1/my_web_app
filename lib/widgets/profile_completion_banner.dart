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
  String? _displayName;
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
          .select('display_name, bio')
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (data == null) {
        // No profile row at all
        setState(() {
          _needsProfile = true;
          _loading = false;
        });
        return;
      }
      final displayName = data['display_name']?.toString() ?? '';
      final bio = data['bio']?.toString() ?? '';
      setState(() {
        _displayName = displayName.isNotEmpty ? displayName : null;
        _needsProfile = displayName.isEmpty || bio.isEmpty;
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

    final missingFields = <String>[];
    if (_displayName == null || _displayName!.isEmpty) {
      missingFields.add('表示名');
    }
    missingFields.add('自己紹介');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE0E7FF)),
      ),
      color: const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFF4338CA),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'プロフィールを完成させましょう',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${missingFields.join('・')}を設定すると、他のユーザーに見つけてもらいやすくなります。',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
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
                    foregroundColor: const Color(0xFF4338CA),
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
