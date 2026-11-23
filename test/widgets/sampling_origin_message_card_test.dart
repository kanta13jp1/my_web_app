import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/chat_message_origin.dart';
import 'package:my_web_app/widgets/sampling_origin_message_card.dart';

void main() {
  group('SamplingOriginMessageCard (#2682)', () {
    testWidgets(
        'clearly distinguishes MCP sampling/createMessage from user input in light and dark themes',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final theme in <ThemeData>[ThemeData.light(), ThemeData.dark()]) {
          for (final size in const <Size>[Size(1280, 900), Size(390, 844)]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            var inspected = false;
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SamplingOriginMessageCard(
                          origin: ChatMessageOrigin.user(),
                          messageText: '今日の予定と残高を確認して',
                        ),
                        const SizedBox(height: 12),
                        SamplingOriginMessageCard(
                          origin: const ChatMessageOrigin.mcpSampling(
                            sourceServer: 'external-mcp-analytics',
                            toolName: 'fetch_report',
                          ),
                          messageText: '外部サーバーからのサンプリング要求プロンプト',
                          onInspectOrigin: () => inspected = true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.byKey(const Key('sampling_origin_card_user')),
              findsOneWidget,
            );
            expect(
              find.byKey(const Key('sampling_origin_card_mcp')),
              findsOneWidget,
            );
            expect(find.text('ユーザー入力'), findsOneWidget);
            expect(find.text('MCP Sampling要求'), findsOneWidget);
            expect(
              find.text('出所: external-mcp-analytics'),
              findsOneWidget,
            );
            expect(find.text('ツール: fetch_report'), findsOneWidget);
            expect(
              find.text('メソッド: sampling/createMessage'),
              findsOneWidget,
            );

            await tester.ensureVisible(
              find.byKey(const Key('sampling_origin_inspect_btn')),
            );
            await tester.tap(
              find.byKey(const Key('sampling_origin_inspect_btn')),
            );
            await tester.pumpAndSettle();
            expect(inspected, isTrue);

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        handle.dispose();
      }
    });
  });
}
