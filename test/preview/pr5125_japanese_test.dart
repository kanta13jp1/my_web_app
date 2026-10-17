import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_cloud_stage_service.dart';
import 'package:my_web_app/widgets/evernote_cloud_migration_controls.dart';

void main() {
  const labels = ['準備中', '送信中', '内容を解析中', 'バックアップを作成中', '照合中', '完了', '失敗',];
  for (final width in [390.0, 1440.0]) {
    testWidgets('all archive states use Japanese at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var i = 0; i < EvernoteCloudStageState.values.length; i++) {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: EvernoteCloudStageStatus(
          progress: EvernoteCloudStageProgress(state: EvernoteCloudStageState.values[i], processedBytes: 50, totalBytes: 100,),
        ),),),);
        expect(find.text('非公開バックアップの保管：50%・${labels[i]}'), findsOneWidget);
        expect(find.textContaining('Private cloud archive'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },);
  }
}
