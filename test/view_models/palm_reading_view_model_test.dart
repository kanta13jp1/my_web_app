import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/palm_reading_image.dart';
import 'package:my_web_app/data/repositories/palm_reading_repository.dart';
import 'package:my_web_app/data/services/palm_reading_image_picker.dart';
import 'package:my_web_app/domain/models/palm_reading.dart';
import 'package:my_web_app/ui/features/palm_reading/view_models/palm_reading_view_model.dart';

void main() {
  test('capture, consent and analysis produce a new history entry', () async {
    final repository = _FakeRepository();
    final viewModel = PalmReadingViewModel(
      repository: repository,
      imagePicker: _FakePicker(_image),
    );

    await viewModel.initialize();
    await viewModel.pickImage(PalmImageSource.gallery);
    expect(viewModel.selectedImage, isNotNull);
    expect(viewModel.canAnalyze, isFalse);

    viewModel.setPrivacyConsent(true);
    expect(viewModel.canAnalyze, isTrue);

    await viewModel.analyze();

    expect(repository.lastHandSide, PalmHandSide.left);
    expect(viewModel.currentReading?.id, 'reading-1');
    expect(viewModel.history.single.id, 'reading-1');
    expect(viewModel.isAnalyzing, isFalse);
  });

  test('changing hand clears a photo selected for the other hand', () async {
    final viewModel = PalmReadingViewModel(
      repository: _FakeRepository(),
      imagePicker: _FakePicker(_image),
    );
    await viewModel.pickImage(PalmImageSource.gallery);

    viewModel.selectHand(PalmHandSide.right);

    expect(viewModel.handSide, PalmHandSide.right);
    expect(viewModel.selectedImage, isNull);
  });

  test('delete removes both current result and history entry', () async {
    final repository = _FakeRepository(initialHistory: <PalmReading>[_reading]);
    final viewModel = PalmReadingViewModel(
      repository: repository,
      imagePicker: _FakePicker(_image),
    );
    await viewModel.initialize();

    final deleted = await viewModel.deleteReading('reading-1');

    expect(deleted, isTrue);
    expect(repository.deletedIds, contains('reading-1'));
    expect(viewModel.history, isEmpty);
  });
}

final PalmReadingImage _image = PalmReadingImage(
  fileName: 'palm.jpg',
  mimeType: 'image/jpeg',
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
);

final PalmReading _reading = PalmReading.fromJson(<String, dynamic>{
  'id': 'reading-1',
  'request_id': 'request-1',
  'hand_side': 'left',
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
    'advice': <String>[],
    'lines': <Map<String, dynamic>>[],
  },
  'comparison': <String, dynamic>{
    'has_previous': false,
    'confidence': 'low',
    'summary': '今回が基準です。',
    'caution': '同じ条件で撮影してください。',
    'changes': <Map<String, dynamic>>[],
  },
});

class _FakePicker implements PalmReadingImagePicker {
  _FakePicker(this.result);

  final PalmReadingImage? result;

  @override
  Future<PalmReadingImage?> pick(PalmImageSource source) async => result;
}

class _FakeRepository implements PalmReadingRepository {
  _FakeRepository({List<PalmReading> initialHistory = const <PalmReading>[]})
      : _history = List<PalmReading>.of(initialHistory);

  List<PalmReading> _history;
  PalmHandSide? lastHandSide;
  final List<String> deletedIds = <String>[];

  @override
  Future<PalmReading> analyze({
    required PalmReadingImage image,
    required PalmHandSide handSide,
  }) async {
    lastHandSide = handSide;
    _history = <PalmReading>[_reading, ..._history];
    return _reading;
  }

  @override
  Future<void> deleteReading(String readingId) async {
    deletedIds.add(readingId);
    _history = _history.where((item) => item.id != readingId).toList();
  }

  @override
  Future<List<PalmReading>> loadHistory({int limit = 50}) async => _history;
}
