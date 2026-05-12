import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiPlaygroundPage extends StatefulWidget {
  const ApiPlaygroundPage({super.key});

  @override
  State<ApiPlaygroundPage> createState() => _ApiPlaygroundPageState();
}

class _ApiPlaygroundPageState extends State<ApiPlaygroundPage> {
  String? _apiKey;
  List<Map<String, dynamic>> _models = [];
  Map<String, dynamic>? _selectedModel;
  String? _selectedMethod;
  final TextEditingController _inputController = TextEditingController();
  String _responseBody = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadApiKeyAndFetchModels();
  }

  Future<void> _loadApiKeyAndFetchModels() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key');

    if (key == null) {
      setState(() => _responseBody = 'APIキーが設定されていません。');
      return;
    }

    setState(() {
      _apiKey = key;
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        final models = (data['models'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((model) => Map<String, dynamic>.from(model))
            .toList();
        setState(() {
          _models = models;
          // デフォルトでリストの先頭を選択（もしあれば）
          if (_models.isNotEmpty) {
            _onModelSelected(_models.first);
          }
        });
      } else {
        setState(
          () => _responseBody =
              'モデル一覧の取得に失敗しました: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _responseBody = 'エラーが発生しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onModelSelected(Map<String, dynamic> model) {
    setState(() {
      _selectedModel = model;
      // モデルを変更したら、そのモデルがサポートするメソッドのリストを取得して、最初のものをデフォルト選択
      final methodsRaw = model['supportedGenerationMethods'];
      final List<String> methods = methodsRaw is List
          ? methodsRaw.cast<Object>().map((m) => m.toString()).toList()
          : <String>[];
      // 利用頻度の高いメソッドを優先的にデフォルトにするロジック
      if (methods.contains('generateContent')) {
        _selectedMethod = 'generateContent';
      } else if (methods.contains('embedContent')) {
        _selectedMethod = 'embedContent';
      } else if (methods.contains('embedText')) {
        _selectedMethod = 'embedText';
      } else if (methods.isNotEmpty) {
        _selectedMethod = methods.first.toString();
      } else {
        _selectedMethod = null;
      }
    });
  }

  Future<void> _executeApi() async {
    if (_apiKey == null || _selectedModel == null || _selectedMethod == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _responseBody = 'Sending request...';
    });

    try {
      final modelName = (_selectedModel!['name'] ?? '').toString();
      final method = _selectedMethod!;

      // エンドポイントの構築
      // 例: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=...
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/$modelName:$method?key=$_apiKey',
      );

      // メソッドに応じたリクエストボディの作成
      Map<String, dynamic> body;
      final text = _inputController.text;

      switch (method) {
        case 'generateContent':
        case 'countTokens':
          // 一般的なチャットモデル用
          body = {
            'contents': [
              {
                'parts': [
                  {'text': text},
                ],
              }
            ],
          };
          break;
        case 'embedContent':
          // 新しいEmbeddingモデル用
          body = {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          };
          break;
        case 'embedText':
          // レガシーなEmbeddingモデル用 (PaLM系など)
          body = {'text': text};
          break;
        default:
          // サポート外または汎用的なメソッドの場合、単純にtextを送ってみる（エラーになる可能性あり）
          body = {
            'contents': [
              {
                'parts': [
                  {'text': text},
                ],
              }
            ],
          };
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      // JSONを整形して表示
      try {
        final decoded = json.decode(response.body);
        const encoder = JsonEncoder.withIndent('  ');
        setState(() {
          _responseBody = encoder.convert(decoded);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _responseBody = response.body;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _responseBody = 'Request Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Playground'),
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // モデル選択ドロップダウン
            if (_models.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Model',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: _selectedModel?['name'],
                items: _models.map<DropdownMenuItem<String>>((model) {
                  final modelName = (model['name'] ?? '').toString();
                  return DropdownMenuItem<String>(
                    value: modelName,
                    child: Text(
                      modelName.replaceAll('models/', ''),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue == null) return;
                  final model = _models.firstWhere(
                    (m) => (m['name'] ?? '').toString() == newValue,
                    orElse: () => _models.first,
                  );
                  _onModelSelected(model);
                },
                isExpanded: true,
              ),
            const SizedBox(height: 16),

            // メソッド選択ドロップダウン
            if (_selectedModel != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Method',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                initialValue: _selectedMethod,
                items: ((_selectedModel!['supportedGenerationMethods']
                            as List<dynamic>?) ??
                        const <dynamic>[])
                    .cast<Object>()
                    .map<DropdownMenuItem<String>>((method) {
                  final methodName = method.toString();
                  return DropdownMenuItem<String>(
                    value: methodName,
                    child: Text(methodName),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedMethod = newValue;
                  });
                },
                isExpanded: true,
              ),
            const SizedBox(height: 16),

            // 入力エリア
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'Input Text / Prompt',
                border: OutlineInputBorder(),
                hintText: 'Enter your text here...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 実行ボタン
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    (_isLoading || _selectedModel == null) ? null : _executeApi,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Execute API'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5AFE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 結果表示エリア
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _responseBody.isEmpty
                        ? 'Response will appear here...'
                        : _responseBody,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
