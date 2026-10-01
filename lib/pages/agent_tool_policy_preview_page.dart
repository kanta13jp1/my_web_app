import 'package:flutter/material.dart';
import 'package:my_web_app/services/agent_tool_policy_preview_service.dart';

class AgentToolPolicyPreviewPage extends StatefulWidget {
  const AgentToolPolicyPreviewPage({super.key, this.preview});

  final Future<Map<String, dynamic>> Function(String, String)? preview;

  @override
  State<AgentToolPolicyPreviewPage> createState() =>
      _AgentToolPolicyPreviewPageState();
}

class _AgentToolPolicyPreviewPageState
    extends State<AgentToolPolicyPreviewPage> {
  final _scopes = TextEditingController(text: 'read');
  final _service = AgentToolPolicyPreviewService();
  String _role = 'cfo';
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _scopes.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result =
          await (widget.preview ?? _service.preview)(_role, _scopes.text);
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = '確認できませんでした。ログイン状態と通信を確認して、再試行してください。操作を許可した扱いにはしません。',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _explain(String? reason) => switch (reason) {
        'invalid_requested_scope' => '未知の操作名、空欄、または不正な入力が含まれています。',
        'empty_requested_scope' => '確認する操作を入力してください。',
        'missing_scope' => 'この役割には、要求した操作の権限がありません。',
        'approval_required' => 'この操作には人の承認が必要です。この画面では承認できません。',
        null => '選択した役割の既定の権限では、要求を満たします。',
        _ => '操作は許可されません。入力を確認してください。',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('操作権限を試して確認')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AIに頼む操作が、役割の既定の権限で認められるかを確認します。ログインが必要です。入力や結果は保存せず、操作も実行しません。実際の利用者の権限を変更・付与する画面ではありません。',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: '試す役割'),
                    items: const [
                      DropdownMenuItem(value: 'cfo', child: Text('財務担当')),
                      DropdownMenuItem(value: 'cmo', child: Text('広報担当')),
                      DropdownMenuItem(value: 'ceo', child: Text('代表')),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) => setState(() {
                              _role = value!;
                              _result = null;
                            }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _scopes,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: '操作名（複数はカンマで区切る）',
                      hintText: 'read, send',
                    ),
                    onChanged: (_) => setState(() => _result = null),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'read＝読む、suggest＝提案、create＝作成、update＝更新、delete＝削除、send＝送信、purchase＝購入、discount＝値引き、external_share＝外部共有。削除・送信・購入・値引き・外部共有は人の承認が必要です。',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _preview,
                    child: Text(_loading ? '確認中…' : '保存せずに確認'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!),
                    ),
                  if (_result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _result!['allowed'] == true
                                ? '試し判定：要求を満たします'
                                : '試し判定：操作を止めます',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _explain(
                              _result!['blocked_reason'] as String?,
                            ),
                          ),
                          const Text('これは試し判定です。実行時には別途権限を確認します。'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
