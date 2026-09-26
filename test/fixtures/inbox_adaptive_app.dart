import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/widgets/inbox_quick_capture_dialog.dart';

// Synthetic callback only. This entrypoint is never used by production builds.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const InboxFixture());
}

class InboxFixture extends StatefulWidget {
  const InboxFixture({super.key});
  @override
  State<InboxFixture> createState() => _InboxFixtureState();
}

class _InboxFixtureState extends State<InboxFixture> {
  String result = '未保存';
  int calls = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData(
            platform: Uri.base.queryParameters['platform'] == 'ios'
                ? TargetPlatform.iOS
                : TargetPlatform.android,),
        home: Builder(
            builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Inbox検証用画面')),
                  body: Column(children: [
                    Text(result),
                    Text('保存呼出: $calls'),
                    TextButton(
                        onPressed: () => showDialog<bool>(
                            context: context,
                            builder: (_) =>
                                InboxQuickCaptureDialog(onSave: (text) async {
                                  setState(() => calls++);
                                  await Future<void>.delayed(
                                      const Duration(milliseconds: 1200),);
                                  if (text == '失敗') {
                                    throw Exception('synthetic failure');
                                  }
                                  setState(() => result = '保存済み: $text');
                                },),),
                        child: const Text('Inboxへメモを開く'),),
                  ],),
                ),),
      );
}
