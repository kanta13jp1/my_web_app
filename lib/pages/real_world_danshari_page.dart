import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../services/attachment_service.dart';

class RealWorldDanshariPage extends StatefulWidget {
  const RealWorldDanshariPage({super.key});

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  XFile? _image;
  final picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _isRegistering = false;
  String? _analysisResult;
  String? _usedModel;
  List<String> _attemptLogs = []; // 失敗ログ保存用

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _analysisResult = null;
        _usedModel = null;
        _attemptLogs = [];
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final imageBytes = await _image!.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_image',
          'imageBase64': base64Image,
        },
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }

      final data = response.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      setState(() {
        _analysisResult = data['result'];
        _usedModel = data['used_model'];
        _attemptLogs = List<String>.from(data['attempt_logs'] ?? []); // ログ取得
      });

      if (mounted) {
        _showAnalysisResultDialog(_analysisResult!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI解析エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  String _extractItemName(String text) {
    try {
      final regex = RegExp(r'【物体名】\s*\n?([^\n]+)');
      final match = regex.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim() ?? '謎の物体';
      }
    } catch (_) {}
    return '断捨離アイテム';
  }

  Future<void> _uploadImageAsAttachment(int noteId) async {
    if (_image == null) return;

    try {
      final bytes = await _image!.readAsBytes();
      final size = await _image!.length();

      final file = PlatformFile(
        name: _image!.name,
        size: size,
        bytes: bytes,
      );

      await AttachmentService.uploadFile(
        noteId: noteId,
        file: file,
      );
    } catch (e) {
      debugPrint('画像アップロードエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('画像の保存に失敗しました: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _saveAsNote() async {
    if (_analysisResult == null) return;
    setState(() => _isRegistering = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final itemName = _extractItemName(_analysisResult!);
      final now = DateTime.now().toIso8601String();
      final noteData = await supabase
          .from('notes')
          .insert({
            'user_id': userId,
            'title': ' 判定: $itemName',
            'content': _analysisResult,
            'is_archived': false,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();
      final noteId = noteData['id'] as int;
      await _uploadImageAsAttachment(noteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('判定結果と画像を保存しました！'), backgroundColor: Colors.green));
        Navigator.pop(context);
        setState(() {
          _image = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _executeRealWorldDanshari() async {
    if (_analysisResult == null) return;
    setState(() => _isRegistering = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final itemName = _extractItemName(_analysisResult!);
      final now = DateTime.now().toIso8601String();
      final noteData = await supabase
          .from('notes')
          .insert({
            'user_id': userId,
            'title': ' 断捨離: $itemName',
            'content': _analysisResult,
            'is_archived': true,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();
      final noteId = noteData['id'] as int;
      await _uploadImageAsAttachment(noteId);
      const pointsReward = 100;
      try {
        await supabase.rpc('increment_points',
            params: {'user_id': userId, 'points_to_add': pointsReward});
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('「$itemName」を断捨離しました！\n画像も記録しました (+100pt)'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
        setState(() {
          _image = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登録エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _shareResult(String result) {
    final shortResult = result.split('\n').take(5).join('\n');
    final box = context.findRenderObject() as RenderBox?;

    // 文言修正
    final modelInfo =
        _usedModel != null ? "(担当AI: $_usedModel)" : "(担当AI: 五賢帝システム)";

    final patterns = [
      {
        'text':
            '私のゴミを判定するためだけに、世界最高峰のAI『五賢帝』を総動員するアプリを作りました\n1つがダメでも残りが判定を通す...この執念、まさに鬼コーチ。',
        'ref': 'share_pattern_a_tech_overkill'
      },
      {
        'text':
            'AI鬼コーチが最強体制になりました\nOpenAI / Gemini / Claude... 全モデル総力戦の「総当たり判定」からは、どんなゴミも逃げられません。',
        'ref': 'share_pattern_b_demon_coach'
      },
      {
        'text':
            '【エンジニアの断捨離】\nAPI Rate Limitを回避するため、5種類のAIプロバイダをラウンドロビンで総当たり実装しました。\n世界一（無駄に）可用性が高い断捨離アプリです。',
        'ref': 'share_pattern_c_engineer'
      },
      {
        'text': '片付けられない私 vs AI五賢帝 \n「どれか1つくらい許してくれるだろう」と思ったら、全員に「捨てろ」と言われました。',
        'ref': 'share_pattern_d_desperate'
      },
    ];
    final random = Random();
    final selected = patterns[random.nextInt(patterns.length)];
    final shareText =
        '${selected['text']}\n\n$modelInfo\n$shortResult\n...\n\nあなたも無料で診断\n#自分株式会社 #AI #断捨離';
    final shareUrl = 'https://my-web-app-b67f4.web.app/?ref=${selected['ref']}';
    Share.share('$shareText\n$shareUrl',
        subject: 'AI断捨離コーチの判定',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null);
  }

  void _showAnalysisResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.psychology, color: Colors.indigo),
            SizedBox(width: 8),
            Text('鬼コーチの判定')
          ]),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_usedModel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('担当AI: $_usedModel',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold)),
                  ),

                //  失敗ログの表示エリア
                if (_attemptLogs.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      ' ${_attemptLogs.length}つのモデルが脱落しました',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold),
                    ),
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    children: _attemptLogs
                        .map((log) => Padding(
                              padding:
                                  const EdgeInsets.only(left: 16, bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.close,
                                      size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(log,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          fontFamily: 'monospace')),
                                ],
                              ),
                            ))
                        .toList(),
                  ),

                Text(result, style: const TextStyle(fontSize: 16, height: 1.5)),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                    onPressed: () => _shareResult(result),
                    child: const Icon(Icons.share)),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる')),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          setDialogState(() => _isRegistering = true);
                          await _saveAsNote();
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 0),
                  icon: const Icon(Icons.note_add),
                  label: const Text('画像付きでメモに保存'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          setDialogState(() => _isRegistering = true);
                          await _executeRealWorldDanshari();
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  icon: _isRegistering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_forever),
                  label: const Text('画像付きで捨てる (+100pt)'),
                ),
              ],
            )
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(' リアル断捨離判定'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                '捨てられないモノを撮影してください。\nOpenAI, Gemini, Claudeなど最新のAIが、あなたの代わりに断捨離を即決します。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            if (_image != null) ...[
              ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                      height: 300,
                      child: kIsWeb
                          ? Image.network(_image!.path, fit: BoxFit.cover)
                          : Image.file(File(_image!.path), fit: BoxFit.cover))),
              const SizedBox(height: 32),
            ],
            if (_isAnalyzing)
              const Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('五賢帝（最新AIモデル群）に問い合わせ中...',
                    style: TextStyle(fontWeight: FontWeight.bold))
              ])
            else ...[
              ElevatedButton.icon(
                onPressed: () => _getImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.camera_alt, size: 32),
                label: const Text('カメラで撮影', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20)),
                icon: const Icon(Icons.photo_library),
                label: const Text('アルバムから選択'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
