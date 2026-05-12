import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart'; // ファイル選択のために必要
import 'package:mime/mime.dart';
import '../main.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// プロフィール設定ページ
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();

  // Form controllers
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _locationController = TextEditingController();
  final _twitterHandleController = TextEditingController();
  final _githubHandleController = TextEditingController();
  // ✅ 追加: 生年月日と目標寿命のコントローラー
  final _birthDateController = TextEditingController();
  final _targetDeathAgeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublic = true;
  UserProfile? _currentProfile;
  // ✅ 追加: 生年月日の状態管理
  DateTime? _birthDate;

  // 画像アップロード関連の状態
  Uint8List? _pickedAvatarBytes;
  String? _avatarUrl; // 現在表示するアバター画像のURL

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _websiteUrlController.dispose();
    _locationController.dispose();
    _twitterHandleController.dispose();
    _githubHandleController.dispose();
    _birthDateController.dispose();
    _targetDeathAgeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final profile = await _profileService.getProfile(userId);

      if (profile != null && mounted) {
        if (!mounted) return;
        setState(() {
          _currentProfile = profile;
          _displayNameController.text = profile.displayName ?? '';
          _bioController.text = profile.bio ?? '';
          _websiteUrlController.text = profile.websiteUrl ?? '';
          _locationController.text = profile.location ?? '';
          _twitterHandleController.text = profile.twitterHandle ?? '';
          _githubHandleController.text = profile.githubHandle ?? '';
          _isPublic = profile.isPublic;
          _avatarUrl = profile.avatarUrl;

          // ✅ 追加: 生年月日の読み込みとフォーマット
          if (profile.birthDate != null) {
            _birthDate = profile.birthDate;
            _birthDateController.text =
                "${_birthDate!.year}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.day.toString().padLeft(2, '0')}";
          }

          // ✅ 追加: 目標寿命の読み込み（デフォルト80）
          _targetDeathAgeController.text =
              (profile.targetDeathAge ?? 80).toString();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  // ✅ 追加: 日付選択ピッカーの表示
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ja'), // 日本語ロケール（必要に応じて）
      helpText: '生年月日を選択',
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text =
            "${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // 画像選択・アップロード処理
  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.bytes != null) {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;
      final userId = currentUser.id;

      final file = result.files.single;
      final fileBytes = file.bytes!;
      // 5MB limit
      if (fileBytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ファイルサイズは5MB以下にしてください')),
          );
        }
        return;
      }
      final fileName = file.name;
      final fileExtension =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      const allowedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
      if (!allowedExtensions.contains(fileExtension.toLowerCase())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('画像ファイル（png, jpg, jpeg, webp, gif）のみアップロードできます'),
            ),
          );
        }
        return;
      }
      final contentType =
          lookupMimeType(fileName) ?? 'application/octet-stream';

      setState(() {
        _isSaving = true;
        _pickedAvatarBytes = fileBytes;
      });

      try {
        final newUrl = await _profileService.uploadAvatar(
          userId: userId,
          fileBytes: fileBytes,
          fileExtension: fileExtension,
          contentType: contentType,
        );

        if (mounted) {
          setState(() {
            _avatarUrl = newUrl;
            _isSaving = false;
            _pickedAvatarBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィール画像を更新しました')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _pickedAvatarBytes = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('画像アップロードに失敗しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      // ✅ 追加: 目標寿命のパース
      final targetAge = int.tryParse(_targetDeathAgeController.text) ?? 80;

      final updatedProfile = UserProfile(
        userId: userId,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        websiteUrl: _websiteUrlController.text.trim().isEmpty
            ? null
            : _websiteUrlController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        twitterHandle: _twitterHandleController.text.trim().isEmpty
            ? null
            : _twitterHandleController.text.trim(),
        githubHandle: _githubHandleController.text.trim().isEmpty
            ? null
            : _githubHandleController.text.trim(),
        isPublic: _isPublic,
        avatarUrl: _avatarUrl,
        // ✅ 追加: 生年月日と目標寿命を保存
        birthDate: _birthDate,
        targetDeathAge: targetAge,

        createdAt: _currentProfile?.createdAt,
        updatedAt: DateTime.now(),
      );

      await _profileService.updateProfile(updatedProfile);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィールを保存しました'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  Widget _buildShareProfileCard() {
    final userId = supabase.auth.currentUser?.id ?? '';
    final url = 'https://my-web-app-b67f4.web.app/u?id=$userId';
    return Card(
      color: const Color(0xFF6366F1).withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF6366F1).withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.share, size: 16, color: Color(0xFF6366F1)),
                SizedBox(width: 8),
                Text(
                  '公開プロフィールURL',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text(
                    'コピー',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('URLをコピーしました'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
              tooltip: '保存',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // プロフィール画像プレースホルダー
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            backgroundImage: _pickedAvatarBytes != null
                                ? MemoryImage(_pickedAvatarBytes!)
                                : (_avatarUrl != null
                                    ? NetworkImage(_avatarUrl!)
                                    : null) as ImageProvider<Object>?,
                            child: (_pickedAvatarBytes == null &&
                                    _avatarUrl == null)
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Theme.of(context).primaryColor,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              radius: 20,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 20),
                                color: Colors.white,
                                onPressed:
                                    _isSaving ? null : _pickAndUploadAvatar,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 表示名
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: '表示名',
                        hintText: 'リーダーボードに表示される名前',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '表示名を入力してください';
                        }
                        if (value.trim().length > 50) {
                          return '表示名は50文字以内で入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ✅ 追加: 生年月日設定 (読み取り専用・タップでピッカー表示)
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: () => _selectBirthDate(context),
                      decoration: const InputDecoration(
                        labelText: '生年月日',
                        hintText: 'YYYY/MM/DD',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                        helperText: '「死生観クロック」の残り時間計算に使用されます',
                      ),
                      validator: (value) {
                        // 必須にする場合はここでチェック
                        if (value == null || value.isEmpty) {
                          return '生年月日を設定してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ✅ 追加: 目標寿命設定
                    TextFormField(
                      controller: _targetDeathAgeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '目標寿命 (歳)',
                        hintText: '80',
                        prefixIcon: Icon(Icons.hourglass_bottom),
                        border: OutlineInputBorder(),
                        helperText: 'デフォルトは80歳です',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '目標寿命を入力してください';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 1 || age > 150) {
                          return '有効な年齢を入力してください (1-150)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // 自己紹介
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: '自己紹介',
                        hintText: 'あなたについて簡単に紹介してください',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                      validator: (value) {
                        if (value != null && value.trim().length > 200) {
                          return '自己紹介は200文字以内で入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ウェブサイト
                    TextFormField(
                      controller: _websiteUrlController,
                      decoration: const InputDecoration(
                        labelText: 'ウェブサイト',
                        hintText: 'https://example.com',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (!value.startsWith('http://') &&
                              !value.startsWith('https://')) {
                            return 'URLはhttp://またはhttps://で始まる必要があります';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // 場所
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: '場所',
                        hintText: '東京, 日本',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().length > 50) {
                          return '場所は50文字以内で入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Twitterハンドル
                    TextFormField(
                      controller: _twitterHandleController,
                      decoration: const InputDecoration(
                        labelText: 'Twitterハンドル',
                        hintText: '@username',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final handle = value.trim();
                          if (!handle.startsWith('@')) {
                            return 'Twitterハンドルは@で始まる必要があります';
                          }
                          if (handle.length > 16) {
                            return 'Twitterハンドルは15文字以内で入力してください';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // GitHubハンドル
                    TextFormField(
                      controller: _githubHandleController,
                      decoration: const InputDecoration(
                        labelText: 'GitHubハンドル',
                        hintText: 'username',
                        prefixIcon: Icon(Icons.code),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().length > 39) {
                          return 'GitHubハンドルは39文字以内で入力してください';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // 公開設定
                    Card(
                      child: SwitchListTile(
                        title: const Text('プロフィールを公開する'),
                        subtitle: const Text('他のユーザーがあなたのプロフィールを見ることができます'),
                        value: _isPublic,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 保存ボタン（モバイル用）
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? '保存中...' : 'プロフィールを保存'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 公開プロフィールURLシェアカード
                    if (_isPublic) _buildShareProfileCard(),

                    const SizedBox(height: 16),

                    // ヒントカード
                    const Card(
                      color: Color(0xFFE3F2FD),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Color(0xFF1976D2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'ヒント',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '表示名を設定すると、リーダーボードであなたの名前が表示されます。\n'
                              '「生年月日」を設定すると、ダッシュボードの死生観クロックが有効になります。',
                              style: TextStyle(
                                color: Color(0xFF0D47A1),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
