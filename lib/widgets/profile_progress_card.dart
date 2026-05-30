import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ホーム画面に常時表示するプロフィール完成度カード。
///
/// LinkedIn 型のプロフィール進捗バーで、未設定項目を明示し
/// ユーザーに設定を促す。完成度 100% になると非表示になる
/// 代わりにミニプロフィールバッジを表示する。
class ProfileProgressCard extends StatefulWidget {
  const ProfileProgressCard({super.key});

  @override
  State<ProfileProgressCard> createState() => _ProfileProgressCardState();
}

class _ProfileProgressCardState extends State<ProfileProgressCard> {
  bool _loading = true;
  _ProfileData? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select(
            'display_name, bio, avatar_url, website_url, location, '
            'twitter_handle, github_handle, birth_date, gender, occupation, '
            'annual_income, address, education, career_history, hobbies, '
            'alcohol_use, smoking_use, favorite_foods, is_public',
          )
          .eq('user_id', uid)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profile = _ProfileData.fromMap(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final profile = _profile;
    if (profile == null) return _buildEmptyState(context);

    final pct = profile.completionPct;

    // 100% 完了の場合は小さなバッジのみ表示
    if (pct >= 100) {
      return _buildCompleteBadge(context, profile);
    }

    return _buildProgressCard(context, profile, pct);
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE0E7FF),
        ),
      ),
      color: isDark
          ? const Color(0xFF1E1B4B).withAlpha(80)
          : const Color(0xFFF5F3FF),
      child: ListTile(
        leading: Icon(
          Icons.person_add,
          color: isDark ? Colors.white70 : const Color(0xFF4338CA),
        ),
        title: Text(
          'プロフィールを作成しましょう',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF3730A3),
            height: 1.5,
          ),
        ),
        subtitle: const Text(
          '他のユーザーに見つけてもらいやすくなります',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDark ? Colors.white70 : const Color(0xFF4338CA),
        ),
        onTap: () => Navigator.of(context)
            .pushNamed('/profile-settings')
            .then((_) => _load()),
      ),
    );
  }

  Widget _buildCompleteBadge(BuildContext context, _ProfileData profile) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .pushNamed('/profile-settings')
          .then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 16, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            Text(
              profile.displayName != null && profile.displayName!.isNotEmpty
                  ? '${profile.displayName} — プロフィール完成 🎉'
                  : 'プロフィール完成 🎉',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF065F46),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    _ProfileData profile,
    int pct,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final missingFields = profile.missingFields;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE0E7FF),
        ),
      ),
      color: isDark
          ? const Color(0xFF1E1B4B).withAlpha(80)
          : const Color(0xFFF5F3FF),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              children: [
                // アバター
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE0E7FF),
                  backgroundImage:
                      profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                  child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: Color(0xFF4338CA),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName != null &&
                                profile.displayName!.isNotEmpty
                            ? profile.displayName!
                            : 'プロフィール未設定',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF3730A3),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'プロフィール完成度 $pct%',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/profile-settings')
                      .then((_) => _load()),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '設定する',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 進捗バー
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor:
                    isDark ? const Color(0xFF424242) : const Color(0xFFE0E7FF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 75
                      ? const Color(0xFF059669)
                      : pct >= 50
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF4338CA),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 未設定フィールドのチップ
            if (missingFields.isNotEmpty) ...[
              Text(
                '未設定: ${missingFields.map((f) => f.label).join(' / ')}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String? websiteUrl;
  final String? location;
  final String? twitterHandle;
  final String? githubHandle;
  final String? birthDate;
  final String? gender;
  final String? occupation;
  final String? annualIncome;
  final String? address;
  final String? education;
  final String? careerHistory;
  final String? hobbies;
  final String? alcoholUse;
  final String? smokingUse;
  final String? favoriteFoods;
  final bool isPublic;

  const _ProfileData({
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.websiteUrl,
    this.location,
    this.twitterHandle,
    this.githubHandle,
    this.birthDate,
    this.gender,
    this.occupation,
    this.annualIncome,
    this.address,
    this.education,
    this.careerHistory,
    this.hobbies,
    this.alcoholUse,
    this.smokingUse,
    this.favoriteFoods,
    this.isPublic = false,
  });

  factory _ProfileData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const _ProfileData();
    return _ProfileData(
      displayName: map['display_name']?.toString(),
      bio: map['bio']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      websiteUrl: map['website_url']?.toString(),
      location: map['location']?.toString(),
      twitterHandle: map['twitter_handle']?.toString(),
      githubHandle: map['github_handle']?.toString(),
      birthDate: map['birth_date']?.toString(),
      gender: map['gender']?.toString(),
      occupation: map['occupation']?.toString(),
      annualIncome: map['annual_income']?.toString(),
      address: map['address']?.toString(),
      education: map['education']?.toString(),
      careerHistory: map['career_history']?.toString(),
      hobbies: map['hobbies']?.toString(),
      alcoholUse: map['alcohol_use']?.toString(),
      smokingUse: map['smoking_use']?.toString(),
      favoriteFoods: map['favorite_foods']?.toString(),
      isPublic: map['is_public'] == true,
    );
  }

  bool _filled(String? s) => s != null && s.trim().isNotEmpty;

  List<_FieldStatus> get missingFields => [
        if (!_filled(displayName)) const _FieldStatus('表示名', Icons.badge),
        if (!_filled(avatarUrl)) const _FieldStatus('アイコン', Icons.photo_camera),
        if (!_filled(bio)) const _FieldStatus('自己紹介', Icons.edit_note),
        if (!_filled(location)) const _FieldStatus('場所', Icons.location_on),
        if (!_filled(twitterHandle)) const _FieldStatus('Twitter', Icons.tag),
        if (!_filled(githubHandle)) const _FieldStatus('GitHub', Icons.code),
        if (!_filled(websiteUrl))
          const _FieldStatus('WebサイトURL', Icons.language),
        if (!_filled(birthDate)) const _FieldStatus('生年月日', Icons.cake),
        if (!_filled(gender)) const _FieldStatus('性別', Icons.wc),
        if (!_filled(occupation)) const _FieldStatus('職業', Icons.work),
        if (!_filled(annualIncome)) const _FieldStatus('年収', Icons.payments),
        if (!_filled(address)) const _FieldStatus('住所', Icons.home),
        if (!_filled(education)) const _FieldStatus('学歴', Icons.school),
        if (!_filled(careerHistory)) const _FieldStatus('職歴', Icons.badge),
        if (!_filled(hobbies)) const _FieldStatus('趣味', Icons.interests),
        if (!_filled(alcoholUse)) const _FieldStatus('飲酒', Icons.local_bar),
        if (!_filled(smokingUse)) const _FieldStatus('喫煙', Icons.smoke_free),
        if (!_filled(favoriteFoods))
          const _FieldStatus('好きな食べ物', Icons.restaurant),
      ];

  int get completionPct {
    const total = 18;
    final filled = [
      _filled(displayName),
      _filled(avatarUrl),
      _filled(bio),
      _filled(location),
      _filled(twitterHandle),
      _filled(githubHandle),
      _filled(websiteUrl),
      _filled(birthDate),
      _filled(gender),
      _filled(occupation),
      _filled(annualIncome),
      _filled(address),
      _filled(education),
      _filled(careerHistory),
      _filled(hobbies),
      _filled(alcoholUse),
      _filled(smokingUse),
      _filled(favoriteFoods),
    ].where((v) => v).length;
    return (filled / total * 100).round();
  }
}

class _FieldStatus {
  final String label;
  final IconData icon;
  const _FieldStatus(this.label, this.icon);
}
