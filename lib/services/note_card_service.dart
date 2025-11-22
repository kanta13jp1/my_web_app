import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/note.dart';
import '../models/category.dart';
import '../models/card_template.dart' as template;
import '../widgets/note_card_widget.dart';
import '../utils/app_logger.dart';

class NoteCardService {
  // Widgetを画像に変換
  static Future<Uint8List?> captureWidget(Widget widget) async {
    try {
      // RepaintBoundaryを使用してWidgetをラップ
      final repaintBoundary = RepaintBoundary(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(1080, 1080),
            devicePixelRatio: 1.0,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              child: widget,
            ),
          ),
        ),
      );

      // RenderRepaintBoundaryを取得
      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());

      final renderRepaintBoundary = RenderRepaintBoundary();

      final renderView = RenderView(
        view: WidgetsBinding.instance.platformDispatcher.views.first,
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: renderRepaintBoundary,
        ),
        configuration: const ViewConfiguration(),
      );

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: renderRepaintBoundary,
        child: repaintBoundary,
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      // 画像として変換
      final ui.Image image =
          await renderRepaintBoundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error capturing widget',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // GlobalKeyを使ってWidgetをキャプチャする簡易版（Web版対応）
  static Future<Uint8List?> captureWidgetSimple(
    GlobalKey key,
  ) async {
    try {
      AppLogger.debug('Starting capture process...');

      // まず、currentContextが存在するまで待つ
      for (int i = 0; i < 20; i++) {
        if (key.currentContext != null) {
          AppLogger.debug('Context found on attempt ${i + 1}');
          break;
        }
        AppLogger.debug('Waiting for context... attempt ${i + 1}/20');
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (key.currentContext == null) {
        AppLogger.warning('Context is null after waiting');
        return null;
      }

      // RenderObjectを取得
      final renderObject = key.currentContext!.findRenderObject();
      if (renderObject == null) {
        AppLogger.warning('RenderObject is null');
        return null;
      }

      if (renderObject is! RenderRepaintBoundary) {
        AppLogger.warning('RenderObject is not RepaintBoundary');
        return null;
      }

      AppLogger.debug('RenderRepaintBoundary found, waiting for render...');

      // 複数フレームを待つ（Web版では必須）
      for (int i = 0; i < 3; i++) {
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        WidgetsBinding.instance.scheduleFrame();
        await completer.future;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      AppLogger.debug('Post frame callback fired');

      // レンダリングが完全に完了するまで待つ
      await Future.delayed(const Duration(milliseconds: 500));

      AppLogger.debug('Attempting to capture image...');

      // 画像として変換（リトライロジック付き）
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          AppLogger.debug('Capture attempt ${attempt + 1}/3');

          // レンダーオブジェクトが有効かチェック
          if (!renderObject.attached) {
            AppLogger.debug('RenderObject is not attached, waiting...');
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }

          final image = await renderObject.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);

          if (byteData != null) {
            AppLogger.info(
              'Image captured successfully on attempt ${attempt + 1}',
            );
            final result = byteData.buffer.asUint8List();

            // 画像オブジェクトを破棄してWebGLリソースを解放
            image.dispose();

            return result;
          } else {
            AppLogger.warning('ByteData is null on attempt ${attempt + 1}');
            // エラーの場合も画像を破棄
            image.dispose();
          }
        } catch (e) {
          AppLogger.warning(
            'Error during toImage attempt ${attempt + 1}',
            error: e,
          );
          if (attempt < 2) {
            AppLogger.debug('Waiting before retry...');
            // WebGLコンテキストのリカバリーのため、より長い待機時間
            await Future.delayed(const Duration(milliseconds: 2000));
          }
        }
      }

      AppLogger.error('All capture attempts exhausted');
      return null;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Fatal error capturing widget',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // メモカードを生成
  static Future<Uint8List?> generateNoteCard({
    required Note note,
    Category? category,
    required template.CardStyle cardStyle,
  }) async {
    // 文字数と単語数を計算
    final characterCount = note.content.length;
    final wordCount = note.content.split(RegExp(r'\s+')).length;

    final cardWidget = NoteCardWidget(
      note: note,
      category: category,
      cardStyle: cardStyle,
      wordCount: wordCount,
      characterCount: characterCount,
    );

    return await captureWidget(cardWidget);
  }

  // 画像を共有
  static Future<void> shareNoteCard({
    required Uint8List imageBytes,
    required String noteTitle,
  }) async {
    try {
      // 一時ファイルとして保存
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/note_card_$timestamp.png');
      await file.writeAsBytes(imageBytes);

      // 共有
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📝 $noteTitle\n\n#マイメモ #メモ習慣',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error sharing note card',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // 画像をダウンロード（デバイスに保存）
  static Future<String> saveNoteCard({
    required Uint8List imageBytes,
    required String noteTitle,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedTitle = noteTitle.replaceAll(RegExp(r'[^\w\s-]'), '');
      final fileName = 'note_${sanitizedTitle}_$timestamp.png';
      final file = File('${appDocDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      return file.path;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error saving note card',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // 統計カードを生成（ストリーク、総メモ数など）
  static Future<Uint8List?> generateStatsCard({
    required int totalNotes,
    required int streakDays,
    required int totalWords,
    required String userName,
  }) async {
    final widget = Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // タイトル
          const Text(
            'マイメモ統計',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 80),

          // 統計情報
          _buildStatItem(
            Icons.note_alt,
            '$totalNotes',
            '総メモ数',
          ),

          const SizedBox(height: 60),

          _buildStatItem(
            Icons.local_fire_department,
            '$streakDays日',
            '連続記録',
          ),

          const SizedBox(height: 60),

          _buildStatItem(
            Icons.text_fields,
            '$totalWords',
            '総文字数',
          ),

          const Spacer(),

          // フッター
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_alt, color: Colors.white, size: 40),
                SizedBox(width: 12),
                Text(
                  'マイメモで記録を続けよう',
                  style: TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return await captureWidget(widget);
  }

  static Widget _buildStatItem(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 60),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
