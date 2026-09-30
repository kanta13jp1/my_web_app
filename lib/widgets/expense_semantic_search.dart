import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/jev_client.dart';
import '../services/jev_expense_proxy_client.dart';
import '../services/jev_semantic_expense_search_service.dart';

/// Read-only search of already loaded memos. No storage or mutation callback.
class ExpenseSemanticSearch extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String periodLabel;
  final JevClient? client;
  final Stream<String?>? sessionIdentities;

  const ExpenseSemanticSearch({
    super.key,
    required this.items,
    required this.periodLabel,
    this.client,
    this.sessionIdentities,
  });

  @override
  State<ExpenseSemanticSearch> createState() => _ExpenseSemanticSearchState();
}

class _ExpenseSemanticSearchState extends State<ExpenseSemanticSearch> {
  final _query = TextEditingController();
  final _exclude = TextEditingController();
  final _localClient = JevClient(
    apiKey: null,
    endpoint: JevClient.defaultEndpoint,
  );
  late JevClient _client;
  late JevSemanticExpenseSearchService _service;
  final Map<int, SemanticSearchResult> _results = {};
  bool _busy = false;
  int _revision = 0;
  StreamSubscription<String?>? _authSubscription;
  bool _sessionChanged = false;

  List<Map<String, dynamic>> get _items => widget.items.take(5).map((item) {
        return <String, dynamic>{'title': item['title']?.toString() ?? ''};
      }).toList();

  @override
  void initState() {
    super.initState();
    _configure();
    _watchSession();
  }


  void _watchSession() {
    Stream<String?>? identities = widget.sessionIdentities;
    String? previous;
    var initialized = false;
    if (identities == null && widget.client == null) {
      try {
        final auth = Supabase.instance.client.auth;
        previous = auth.currentUser?.id;
        initialized = true;
        identities = auth.onAuthStateChange.map((event) => event.session?.user.id);
      } catch (_) {
        return;
      }
    }
    _authSubscription = identities?.listen((identity) {
      if (!initialized) {
        previous = identity;
        initialized = true;
        return;
      }
      if (identity == previous || !mounted) return;
      previous = identity;
      setState(() {
        _revision++;
        _results.clear();
        _service.clearCache();
        // Do not reuse the previous account's already loaded memo list.
        _sessionChanged = true;
      });
    });
  }

  void _configure() {
    _client = widget.client ??
        JevExpenseProxyClient.forCurrentSession(semanticSearch: true);
    _service = JevSemanticExpenseSearchService(client: _client);
  }

  @override
  void didUpdateWidget(covariant ExpenseSemanticSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      if (oldWidget.client == null) _client.dispose();
      _configure();
    }
    if (oldWidget.client != widget.client ||
        oldWidget.items.toString() != widget.items.toString() ||
        oldWidget.periodLabel != widget.periodLabel) {
      _revision++;
      _results.clear();
      _service.clearCache();
    }
  }

  void _changed(String _) {
    setState(() {
      _revision++;
      _results.clear();
    });
  }

  Future<void> _search({int? aiIndex}) async {
    if (_busy || _sessionChanged) return;
    final revision = ++_revision;
    final items = _items;
    final query = _query.text.trim();
    final exclude = _exclude.text.trim();
    setState(() => _busy = true);
    final service = aiIndex == null
        ? JevSemanticExpenseSearchService(client: _localClient)
        : _service;
    try {
      final results = await service.search(
        items: aiIndex == null ? items : <Map<String, dynamic>>[items[aiIndex]],
        meaningQuery: query,
        excludeQuery: exclude,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        if (aiIndex != null) {
          _results[aiIndex] = results.single;
        } else {
          // The service sorts results; recover input positions without relying
          // on memo uniqueness (two transactions may have identical memos).
          for (var i = 0; i < items.length; i++) {
            _results[i] = results.firstWhere((r) => identical(r.item, items[i]));
          }
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _revision++;
    _authSubscription?.cancel();
    _query.dispose();
    _exclude.dispose();
    _localClient.dispose();
    if (widget.client == null) _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionChanged) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('アカウントが切り替わりました。この画面を開き直すと支出メモを検索できます。'),
      );
    }
    final items = _items;
    final canAsk = _client.isConfigured && _query.text.trim().isNotEmpty;
    return ExpansionTile(
      key: const Key('expense_semantic_search'),
      title: const Text('支出メモを条件で探す'),
      subtitle: Text('${widget.periodLabel}の支出 ${items.length}件（先頭5件まで）'),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        const Text('取得済みの支出メモだけを確認します。記録や金額は変更しません。'),
        TextField(
          key: const Key('expense_search_query'),
          controller: _query,
          maxLength: 80,
          onChanged: _changed,
          decoration: const InputDecoration(
            labelText: '探したい条件',
            hintText: '例：返金を求めている',
          ),
        ),
        TextField(
          key: const Key('expense_search_exclude'),
          controller: _exclude,
          maxLength: 80,
          onChanged: _changed,
          decoration: const InputDecoration(
            labelText: '除外したい条件（任意）',
            hintText: '例：返金が完了した',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _busy || items.isEmpty ? null : () => _search(),
            child: const Text('語句で探す（送信なし）'),
          ),
        ),
        Text(_client.isLocalMode
            ? 'AI確認は選んだ1件のメモと条件を設定済みのローカル接続先へ送ります。接続先によって外部AIを利用する場合があります。'
            : 'AI確認は選んだ1件のメモと条件をTypeSafe AIへ送ります。下のメモを確認してから押してください。'),
        const Text('AI確認は1件ずつ、除外条件を含め最大2回の判定です。既存の利用回数枠を使います。'),
        if (!_client.isConfigured)
          const Text('AI確認にはログインが必要です。語句検索は送信せず使えます。'),
        if (items.isEmpty) const Text('この月の支出メモはありません。'),
        if (_busy) const LinearProgressIndicator(),
        for (var i = 0; i < items.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(items[i]['title'] as String),
                  if (_results[i] case final result?) ...[
                    Text(result.source == 'jev'
                        ? 'AI判定・要確認'
                        : result.source == 'empty_query'
                            ? '条件なし・全件表示'
                            : '語句一致・AI判定ではありません'),
                    Text(result.isMatch ? '条件に合う候補' : '条件に合わない候補'),
                    if (result.source == 'jev')
                      const Text('AIは誤ることがあります。メモと条件を照合してください。')
                    else if (result.source == 'local_fallback')
                      const Text('単語での判定です。意味の判定やAIの確信度ではありません。AIが使えない場合もこの方式になります。'),
                  ] else
                    const Text('未確認'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      key: Key('expense_search_ai_$i'),
                      onPressed: _busy || !canAsk ? null : () => _search(aiIndex: i),
                      child: const Text('このメモをAIに送って確認'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
