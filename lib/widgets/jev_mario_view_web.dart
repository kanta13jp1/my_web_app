import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

class JevMarioView extends StatefulWidget {
  const JevMarioView({super.key});

  @override
  State<JevMarioView> createState() => _JevMarioViewState();
}

class _JevMarioViewState extends State<JevMarioView> {
  late final web.HTMLIFrameElement _frame;
  late final JSFunction _listener;
  late final String _viewId;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _viewId = 'jev-mario-${identityHashCode(this)}';
    _frame = web.HTMLIFrameElement()
      ..src = '/labs/jev-mario/index.html?v=revalidate-1'
      ..title = 'Jev Mario応答速度検証'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0';
    _listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin ||
          event.source != _frame.contentWindow) {
        return;
      }
      final data = event.data.dartify();
      if (data is! Map) return;
      if (data['type'] == 'jev-mario-hello') {
        _send({'type': 'jev-mario-ready'});
      } else if (data['type'] == 'jev-mario-request') {
        _request(data);
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (_) => _frame);
  }

  void _send(Map<String, dynamic> body) {
    if (!mounted) return;
    _frame.contentWindow
        ?.postMessage(body.jsify(), web.window.location.origin.toJS);
  }

  Future<void> _request(Map<dynamic, dynamic> data) async {
    final id = data['id'];
    if (id is! num || !id.isFinite || data['consent'] != true) return;
    void fail(String message) => _send({
          'type': 'jev-mario-response',
          'id': id,
          'error': message,
        });
    if (_pending) return fail('前のリクエストが終了するまでお待ちください。');
    if (jsonEncode(data).length > 6000) return fail('ゲーム状態が大きすぎます。');
    _pending = true;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        fail('my_web_appへログインしてから再試行してください。');
        return;
      }
      final response = await client.functions.invoke(
        'ai-hub',
        body: {
          'action': 'mario.jev_decide',
          'state': data['state'],
          'consent': true,
        },
      );
      if (!mounted || client.auth.currentUser?.id != user.id) {
        fail('ログイン状態が変わりました。測定を再開してください。');
        return;
      }
      if (response.status != 200 || response.data is! Map) {
        fail('測定できませんでした。ログイン・検証機能の設定・利用上限を確認してください。');
        return;
      }
      _send({'type': 'jev-mario-response', 'id': id, 'result': response.data});
    } on FunctionException catch (e) {
      final invalidAnswer = e.details is Map &&
          (e.details as Map)['error'] == 'invalid_provider_response';
      final message = switch (e.status) {
        401 => 'ログインが必要です。アプリへ戻ってログインしてください。',
        403 => 'このアカウントでは検証機能が未有効です。管理者の設定が必要です。',
        429 => 'API利用上限に達しました。時間をおいて再試行してください。',
        502 => invalidAnswer
            ? 'Jevの回答形式を検証できず停止しました（502）。停止後に再試行してください。'
            : 'Jev側の通信に失敗しました（502）。停止後に再試行してください。',
        503 => '検証サーバーが未設定または利用できません。管理者に確認してください。',
        _ => 'Jev応答を取得できませんでした。停止後に再試行してください。',
      };
      fail(message);
    } catch (_) {
      fail('通信できませんでした。接続を確認して再試行してください。');
    } finally {
      _pending = false;
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frame.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
