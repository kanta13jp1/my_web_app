import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _family = 'AtmFixtureNotoJP';
const _transfer = '振替（支出集計外）: [銀行A→現金] ATM引出し';
const _fee = 'ATM手数料';
const _viewport = Rect.fromLTWH(0, 0, 390, 844);

class _OfflineOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NoSocketClient();
}

class _NoSocketClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    throw const SocketException('Network disabled for the ATM calendar test');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('No socket transport in this fixture');
  }
}

Finder _eventRow(String label) {
  return find.byWidgetPredicate(
    (w) =>
        w is Row &&
        w.children.whereType<Expanded>().any(
              (e) => e.child is Text && (e.child as Text).data == label,
            ),
  );
}

Finder _marker(Finder cell, Color color) {
  return find.descendant(
    of: cell,
    matching: find.byWidgetPredicate((w) {
      if (w is! Container || w.decoration is! BoxDecoration) return false;
      final box = w.decoration! as BoxDecoration;
      return box.shape == BoxShape.circle && box.color == color;
    }),
  );
}

bool _contains(Rect parent, Rect child) =>
    child.width > 0 &&
    child.height > 0 &&
    child.left >= parent.left - 0.01 &&
    child.right <= parent.right + 0.01 &&
    child.top >= parent.top - 0.01 &&
    child.bottom <= parent.bottom + 0.01;

List<double> _edges(Rect box) => [box.left, box.top, box.right, box.bottom];

// This fixture scrolls the actual page in a SingleChildScrollView.
List<(RenderObject, Rect)> _rectangularClips(RenderParagraph paragraph) {
  final viewport = RenderAbstractViewport.of(paragraph);
  expect(viewport.runtimeType.toString(), '_RenderSingleChildViewport');
  final clips = <(RenderObject, Rect)>[];
  RenderObject child = paragraph;
  for (var parent = child.parent; parent != null; parent = child.parent) {
    if (parent is RenderFittedBox && parent.clipBehavior != Clip.none) {
      fail('Unexpected clipping FittedBox in the calendar row');
    }
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final knownRect = identical(parent, viewport) ||
          (parent.runtimeType == RenderClipRect &&
              (parent as RenderClipRect).clipper == null) ||
          parent.runtimeType == RenderFlex ||
          parent.runtimeType == RenderStack;
      expect(
        knownRect,
        isTrue,
        reason: 'Unsupported clip: ${parent.runtimeType}',
      );
      expect(clip, Offset.zero & (parent as RenderBox).size);
      clips.add((parent, clip));
    }
    child = parent;
  }
  expect(clips.any((entry) => identical(entry.$1, viewport)), isTrue);
  return clips;
}

List<Rect> _glyphBounds(WidgetTester tester, Finder text, String value) {
  final rich = find.descendant(of: text, matching: find.byType(RichText));
  expect(rich, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(rich);
  expect(paragraph.text.style?.fontFamily, _family);
  expect(paragraph.text.toPlainText(), value);
  expect(paragraph.didExceedMaxLines, isFalse, reason: 'Truncated event field');
  expect(paragraph, paintsExactlyCountTimes(#clipRect, 0));
  final clips = _rectangularClips(paragraph);
  final area = tester.getRect(rich);
  final boxes = <Rect>[];
  // The four fixture strings consist solely of BMP characters.
  for (var i = 0; i < value.length; i++) {
    if (value[i].trim().isEmpty) continue;
    final glyph = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    expect(glyph, hasLength(1), reason: 'Missing laid-out character $i');
    final local = glyph.single.toRect();
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      local,
    );
    expect(
      rect.isFinite && !rect.isEmpty && _viewport.intersect(rect) == rect,
      isTrue,
      reason: 'fixture="$value" index=$i codeUnit=${value.codeUnitAt(i)} '
          'local=${_edges(local)} global=${_edges(rect)} '
          'paragraph=${_edges(area)} viewport=${_edges(_viewport)}',
    );
    for (final (ancestor, clip) in clips) {
      final inAncestor = MatrixUtils.transformRect(
        paragraph.getTransformTo(ancestor),
        local,
      );
      expect(
        inAncestor.isFinite &&
            !inAncestor.isEmpty &&
            clip.intersect(inAncestor) == inAncestor,
        isTrue,
        reason: 'fixture="$value" index=$i ancestor=${ancestor.runtimeType} '
            'selection=${_edges(inAncestor)} clip=${_edges(clip)}',
      );
    }
    boxes.add(rect);
  }
  return boxes;
}

Future<void> _verifyGlyphContrast(ui.Image image, List<Rect> glyphs) async {
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  for (final rect in glyphs) {
    var darkest = 255;
    var lightest = 0;
    final sample = rect.intersect(_viewport);
    for (var y = sample.top.floor(); y < sample.bottom.ceil(); y++) {
      for (var x = sample.left.floor(); x < sample.right.ceil(); x++) {
        final i = (y * image.width + x) * 4;
        final light =
            (rgba.getUint8(i) + rgba.getUint8(i + 1) + rgba.getUint8(i + 2)) ~/
                3;
        darkest = math.min(darkest, light);
        lightest = math.max(lightest, light);
      }
    }
    expect(
      lightest - darkest,
      greaterThanOrEqualTo(24),
      reason: 'A laid-out character has no visible foreground contrast',
    );
  }
}

Rect _rowCrop(Rect row) {
  return Rect.fromLTRB(
    0,
    row.top.floorToDouble(),
    390,
    row.bottom.ceilToDouble(),
  );
}

Future<void> _saveRowCrops(
  ui.Image image,
  Rect feeRow,
  Rect transferRow,
) async {
  final dest = Platform.environment['ATM_NARROW_EVIDENCE_DIR'];
  if (dest == null || dest.isEmpty) return;
  final dir = Directory(dest);
  expect(dir.isAbsolute, isTrue);
  expect(await dir.resolveSymbolicLinks(), dir.path);
  final output = <File>[];
  try {
    for (final (name, row) in [
      ('atm-390-fee.png', feeRow),
      ('atm-390-transfer.png', transferRow),
    ]) {
      final src = _rowCrop(row);
      final top = src.top.toInt();
      final height = src.height.toInt();
      expect(height, inInclusiveRange(14, 128));
      expect(top >= 0 && top + height <= image.height, isTrue);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        image,
        src,
        src.shift(Offset(0, -top.toDouble())),
        ui.Paint()..filterQuality = ui.FilterQuality.none,
      );
      final picture = recorder.endRecording();
      try {
        final crop = await picture.toImage(390, height);
        try {
          final bytes =
              (await crop.toByteData(format: ui.ImageByteFormat.png))!;
          expect(bytes.lengthInBytes, inInclusiveRange(1, 4 * 1024 * 1024));
          final file = File.fromUri(dir.uri.resolve(name));
          await file.create(exclusive: true);
          output.add(file);
          await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
        } finally {
          crop.dispose();
        }
      } finally {
        picture.dispose();
      }
    }
  } catch (_) {
    for (final file in output) {
      await file.delete();
    }
    rethrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final offline = _OfflineOverrides();
  HttpOverrides? previous;
  var supabaseRequests = 0;
  var aiHubPosts = 0;
  setUpAll(() async {
    previous = HttpOverrides.current;
    HttpOverrides.global = offline;
    expect(HttpOverrides.current, same(offline));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        supabaseRequests++;
        if (request.method == 'POST' &&
            request.url.path == '/functions/v1/ai-hub') {
          aiHubPosts++;
        }
        throw StateError('Unauthenticated fixture attempted a Supabase call');
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    final bytes =
        await File('web/assets/fonts/NotoSansJP-Regular.ttf').readAsBytes();
    expect(
      sha256.convert(bytes).toString(),
      '6e60ad1ccbb6ce0726bbb3dfd89092692bc1e83af073dd602a323da1e9b25760',
    );
    final loader = FontLoader(_family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final iconData = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    final iconBytes = iconData.buffer.asUint8List(
      iconData.offsetInBytes,
      iconData.lengthInBytes,
    );
    expect(
      sha256.convert(iconBytes).toString(),
      'd9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453',
    );
    final icons = FontLoader('MaterialIcons')..addFont(Future.value(iconData));
    await icons.load();
  });
  tearDownAll(() async {
    try {
      await Supabase.instance.dispose();
    } finally {
      HttpOverrides.global = previous;
    }
  });

  testWidgets('ATM transfer and fee remain readable in the 390px calendar',
      (tester) async {
    expect(HttpOverrides.current, same(offline));
    expect(Supabase.instance.client.auth.currentSession, isNull);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _viewport.size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const screen = Key('atm-narrow-screen');
    await tester.pumpWidget(
      RepaintBoundary(
        key: screen,
        child: MaterialApp(
          theme: ThemeData(fontFamily: _family),
          home: AssetManagementPage(
            debugNow: DateTime(2026, 6, 20),
            debugCalendarNow: DateTime(2026, 6, 20),
            debugInitialAssetData: const {
              '2026-06-20': {'Synthetic bank': 10000},
            },
            debugInitialRecentFlows: const [
              {
                'action_type': 'transfer',
                'amount': 5000,
                'description': '[銀行A→現金] ATM引出し',
                'occurred_at': '2026-06-12T12:00:00',
              },
              {
                'action_type': 'expense',
                'amount': 220,
                'description': _fee,
                'occurred_at': '2026-06-12T12:00:00',
              },
            ],
          ),
        ),
      ),
    );
    try {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final cell = find.byKey(const Key('asset_calendar_day_12'));
      expect(cell, findsOneWidget);
      await tester.ensureVisible(cell);
      await tester.pump();
      expect(
        find.descendant(of: cell, matching: find.text('220')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('5,220')),
        findsNothing,
      );
      expect(_marker(cell, const Color(0xFF64748B)), findsOneWidget);
      expect(_marker(cell, const Color(0xFF2563EB)), findsNothing);
      await tester.tap(cell);
      await tester.pump();
      expect(find.text('6月12日 のイベント'), findsOneWidget);

      final feeRow = _eventRow(_fee);
      final transferRow = _eventRow(_transfer);
      expect(feeRow, findsOneWidget);
      expect(transferRow, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(feeRow), alignment: 0.35);
      await tester.pump(const Duration(milliseconds: 300));
      final rowFields = <(Finder, String, Finder, String, Rect, Rect)>[];
      for (final (row, label, amount, expectedIcon) in [
        (feeRow, _fee, '¥220', Icons.remove_circle_outline),
        (transferRow, _transfer, '¥5,000', Icons.swap_horiz),
      ]) {
        final icon = find.descendant(of: row, matching: find.byType(Icon));
        expect(icon, findsOneWidget);
        expect(tester.widget<Icon>(icon).icon, expectedIcon);
        final labelText = find.descendant(of: row, matching: find.text(label));
        final amountText =
            find.descendant(of: row, matching: find.text(amount));
        expect(labelText, findsOneWidget);
        expect(amountText, findsOneWidget);
        final area = tester.getRect(row);
        expect(_contains(_viewport, area), isTrue);
        final labelBox = tester.getRect(labelText);
        final amountBox = tester.getRect(amountText);
        expect(_contains(area, labelBox) && _contains(area, amountBox), isTrue);
        expect(labelBox.right, lessThanOrEqualTo(amountBox.left + 0.01));
        final iconBox = tester.getRect(icon);
        expect(_contains(area, iconBox), isTrue);
        rowFields.add((labelText, label, amountText, amount, iconBox, area));
      }
      final first = tester.getRect(feeRow);
      final second = tester.getRect(transferRow);
      expect(second.top - first.bottom, inInclusiveRange(0, 8));
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(screen));
      expect(tester.getRect(find.byKey(screen)), _viewport);
      final image = await tester.runAsync<ui.Image>(
        () => boundary.toImage(pixelRatio: 1),
      );
      expect(image, isNotNull);
      final raster = image!;
      addTearDown(raster.dispose);
      expect([raster.width, raster.height], [390, 844]);
      final cropsChecked = await tester.runAsync<bool>(() async {
        await _saveRowCrops(raster, first, second);
        return true;
      });
      expect(cropsChecked, isTrue);
      final glyphs = <Rect>[];
      for (final (label, title, amount, money, iconBox, area) in rowFields) {
        final labels = _glyphBounds(tester, label, title);
        final amounts = _glyphBounds(tester, amount, money);
        for (final rect in labels) {
          expect(amounts.any(rect.overlaps), isFalse);
        }
        final rowGlyphs = [...labels, ...amounts];
        final crop = _rowCrop(area);
        for (final glyph in rowGlyphs) {
          expect(crop.intersect(glyph), glyph, reason: 'Glyph outside row PNG');
        }
        expect(rowGlyphs.any(iconBox.overlaps), isFalse);
        glyphs.addAll(rowGlyphs);
      }
      final rasterChecked = await tester.runAsync<bool>(() async {
        await _verifyGlyphContrast(raster, glyphs);
        return true;
      });
      expect(tester.takeException(), isNull);
      expect(rasterChecked, isTrue);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(
        supabaseRequests,
        0,
        reason: 'POST /functions/v1/ai-hub=$aiHubPosts '
            'other=${supabaseRequests - aiHubPosts}',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
