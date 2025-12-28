import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';

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

  //  判定結果を通常のメモとして保存
  Future<void> _saveAsNote() async {
    if (_analysisResult == null) return;

    setState(() => _isRegistering = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final itemName = _extractItemName(_analysisResult!);
      final now = DateTime.now().toIso8601String();

      await supabase.from('notes').insert({
        'user_id': userId,
        'title': ' 判定: $itemName',
        'content': _analysisResult,
        'is_archived': false, // アーカイブせず、アクティブなメモとして保存
        'created_at': now,
        'updated_at': now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('判定結果をメモに保存しました！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        setState(() {
          _image = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  //  実際に捨ててポイント獲得（アーカイブ済みとして保存）
  Future<void> _executeRealWorldDanshari() async {
    if (_analysisResult == null) return;

    setState(() => _isRegistering = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final itemName = _extractItemName(_analysisResult!);
      final now = DateTime.now().toIso8601String();

      await supabase.from('notes').insert({
        'user_id': userId,
        'title': ' 断捨離: $itemName',
        'content': _analysisResult,
        'is_archived': true, // 最初からアーカイブ済み
        'created_at': now,
        'updated_at': now,
      });

      const pointsReward = 100;
      try {
        await supabase.rpc('increment_points',
            params: {'user_id': userId, 'points_to_add': pointsReward});
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「$itemName」を断捨離しました！\n+100pt & ノルマ達成カウント +1'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
        setState(() {
          _image = null;
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _shareResult(String result) {
    final shortResult = result.split('\n').take(5).join('\n');
    final box = context.findRenderObject() as RenderBox?;

    final modelInfo =
        _usedModel != null ? "(担当AI: $_usedModel)" : "(担当AI: Gemini 14モデル総力戦)";

    final patterns = [
      {
        'text':
            '私のゴミを判定するためだけに、Gemini 3.0含む『14種類のAI』を総動員するアプリを作りました\n1つがダメでも残りの13体が絶対に判定を通す...この執念、まさに鬼コーチ。',
        'ref': 'share_pattern_a_tech_overkill'
      },
      {
        'text':
            'AI鬼コーチが14人に増殖しました\nGemini 3.0 / 2.5 / Pro... 最新モデル14種の「総当たり判定」からは、どんなゴミも逃げられません。',
        'ref': 'share_pattern_b_demon_coach'
      },
      {
        'text':
            '【エンジニアの断捨離】\nAPI Rate Limitを回避するため、14種類のGeminiモデルをラウンドロビンで総当たり実装しました。\n世界一（無駄に）可用性が高い断捨離アプリです。',
        'ref': 'share_pattern_c_engineer'
      },
      {
        'text':
            '片付けられない私 vs 14体のAI \n「どれか1つくらい許してくれるだろう」と思ったら、全員に「捨てろ」と言われました。',
        'ref': 'share_pattern_d_desperate'
      },
      {
        'text':
            '私の部屋のガラクタを判定するために、Googleの最新AIリソースを湯水のように使っています。\nコスト度外視の全力判定結果がこちら',
        'ref': 'share_pattern_e_high_cost'
      },
      {
        'text': '1対1なら無視できたけど、1対14は無理。\nGeminiの歴代モデル全員による「合議制」で、断捨離を迫られています。',
        'ref': 'share_pattern_f_majority'
      },
      {
        'text':
            'Gemini 3.0 Previewを含む最新AI軍団に、私の部屋を晒しました。\n未来の技術で、過去の遺物を捨てています。',
        'ref': 'share_pattern_g_future_tech'
      },
      {
        'text': 'AIに忖度は通用しない。\n14種類のモデルが「それはゴミです」と即答してきました。ぐうの音も出ない判定結果',
        'ref': 'share_pattern_h_no_mercy'
      },
      {
        'text': '見てください。\nこれが14種類の超高性能AIに「汚部屋」と認定された、伝説のアイテムです。',
        'ref': 'share_pattern_i_shame'
      },
      {
        'text': '断捨離の最終兵器。\nスマホをかざすだけで、14のAIが「捨てる理由」を論理的に叩きつけてきます。',
        'ref': 'share_pattern_j_weapon'
      },
    ];

    final random = Random();
    final selected = patterns[random.nextInt(patterns.length)];
    final shareText =
        '${selected['text']}\n\n$modelInfo\n$shortResult\n...\n\nあなたも無料で診断\n#マイメモ #Gemini #断捨離';
    final shareUrl = 'https://my-web-app-b67f4.web.app/?ref=${selected['ref']}';

    Share.share(
      '$shareText\n$shareUrl',
      subject: 'AI断捨離コーチの判定',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  void _showAnalysisResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, color: Colors.indigo),
              SizedBox(width: 8),
              Text('鬼コーチの判定'),
            ],
          ),
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '担当AI: $_usedModel',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  result,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => _shareResult(result),
                  child: const Icon(Icons.share),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            //  ボタンエリア
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // メモに保存（未アーカイブ）
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
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.note_add),
                  label: const Text('メモとして保存する'),
                ),
                const SizedBox(height: 8),

                // 実際に捨てる（アーカイブ＆ポイント）
                ElevatedButton.icon(
                  onPressed: _isRegistering
                      ? null
                      : () async {
                          setDialogState(() => _isRegistering = true);
                          await _executeRealWorldDanshari();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isRegistering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_forever),
                  label: const Text('実際に捨てて +100pt'),
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
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '捨てられないモノを撮影してください。\n14種類の最新AIモデルが、あなたの代わりに断捨離を即決します。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 300,
                  child: kIsWeb
                      ? Image.network(_image!.path, fit: BoxFit.cover)
                      : Image.file(File(_image!.path), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 32),
            ],
            if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('14種類のAI脳みそに問い合わせ中...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () => _getImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.camera_alt, size: 32),
                label: const Text('カメラで撮影', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
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
