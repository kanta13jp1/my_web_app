import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/palm_reading_image.dart';
import 'package:my_web_app/data/repositories/palm_reading_repository.dart';
import 'package:my_web_app/domain/models/palm_reading.dart';
import 'package:my_web_app/domain/palm_reading_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'analyze sends bounded image data and parses the persisted row',
    () async {
      late Map<String, dynamic> request;
      final repository = SupabasePalmReadingRepository(
        invoker: (body) async {
          request = body;
          return <String, dynamic>{'success': true, 'reading': _readingJson()};
        },
      );

      final reading = await repository.analyze(
        image: PalmReadingImage(
          fileName: 'right.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        handSide: PalmHandSide.right,
      );

      expect(request['action'], 'palm_reading.analyze');
      expect(request['hand_side'], 'right');
      expect(request['imageBase64'], 'AQID');
      expect(request['request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(reading.id, 'reading-1');
    },
  );

  test('history receives signed private image URLs', () async {
    final repository = SupabasePalmReadingRepository(
      invoker: (_) async => <String, dynamic>{'success': true},
      historyLoader: (_) async => <Map<String, dynamic>>[_readingJson()],
      imageSigner: (path) async => 'https://signed.example/$path',
    );

    final history = await repository.loadHistory();

    expect(history, hasLength(1));
    expect(
      history.single.imageUrl,
      'https://signed.example/user/reading-1.jpg',
    );
  });

  test('retake response becomes a user-facing typed exception', () async {
    final repository = SupabasePalmReadingRepository(
      invoker: (_) async => <String, dynamic>{
        'success': false,
        'status': 'imageNeedsRetake',
        'message': '手首まで明るく撮り直してください。',
      },
    );

    expect(
      () => repository.analyze(
        image: PalmReadingImage(
          fileName: 'blur.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        handSide: PalmHandSide.left,
      ),
      throwsA(
        isA<PalmReadingException>().having(
          (error) => error.message,
          'message',
          contains('撮り直してください'),
        ),
      ),
    );
  });

  test('rejects unsupported image types before invoking AI', () async {
    var invoked = false;
    final repository = SupabasePalmReadingRepository(
      invoker: (_) async {
        invoked = true;
        return <String, dynamic>{};
      },
    );

    expect(
      () => repository.analyze(
        image: PalmReadingImage(
          fileName: 'palm.gif',
          mimeType: 'image/gif',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        handSide: PalmHandSide.left,
      ),
      throwsA(isA<PalmReadingException>()),
    );
    expect(invoked, isFalse);
  });
}

Map<String, dynamic> _readingJson() => <String, dynamic>{
      'id': 'reading-1',
      'request_id': 'request-1',
      'hand_side': 'right',
      'image_path': 'user/reading-1.jpg',
      'image_mime_type': 'image/jpeg',
      'created_at': '2026-08-22T01:00:00Z',
      'provider': 'google',
      'model': 'gemini-2.5-flash',
      'schema_version': 1,
      'analysis': <String, dynamic>{
        'photo_quality': <String, dynamic>{
          'score': 90,
          'is_usable': true,
          'feedback': '鮮明',
        },
        'overall': '総評',
        'traits': '資質',
        'love': '恋愛',
        'work': '仕事',
        'advice': <String>['一歩試す'],
        'lines': <Map<String, dynamic>>[],
      },
      'comparison': <String, dynamic>{
        'has_previous': false,
        'confidence': 'low',
        'summary': '今回が基準です。',
        'caution': '同条件で撮影してください。',
        'changes': <Map<String, dynamic>>[],
      },
    };
