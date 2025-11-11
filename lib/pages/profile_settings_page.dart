import 'package:flutter/material.dart';
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

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublic = true;
  UserProfile? _currentProfile;

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
        setState(() {
          _currentProfile = profile;
          _displayNameController.text = profile.displayName ?? '';
          _bioController.text = profile.bio ?? '';
          _websiteUrlController.text = profile.websiteUrl ?? '';
          _locationController.text = profile.location ?? '';
          _twitterHandleController.text = profile.twitterHandle ?? '';
          _githubHandleController.text = profile.githubHandle ?? '';
          _isPublic = profile.isPublic;
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
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
            backgroundColor: Colors.green,
          ),
        );
        // 前の画面に戻る
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
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Theme.of(context).primaryColor,
                            ),
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
                                onPressed: () {
                                  // TODO: 画像アップロード機能を実装
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('画像アップロード機能は近日実装予定です'),
                                    ),
                                  );
                                },
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
                          if (!value.startsWith('http://') && !value.startsWith('https://')) {
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

                    // ヒントカード
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'ヒント',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '表示名を設定すると、リーダーボードであなたの名前が表示されます。\n'
                              'プロフィールを充実させて、他のユーザーとつながりましょう！',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 13,
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
