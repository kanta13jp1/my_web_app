import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/photo_action_advice.dart';
import 'package:my_web_app/services/photo_action_advisor_service.dart';
import 'package:my_web_app/view_models/photo_action_advisor_view_model.dart';

void main() {
  const advice = PhotoActionAdvice(
    sceneSummary: '棚に食品と汚れが見えます。',
    observations: ['棚に汚れが見えます'],
    actions: [
      PhotoRecommendedAction(
        priority: PhotoActionPriority.urgent,
        title: '食品表示を確認する',
        reason: '写真だけでは期限を判断できないため',
        estimatedMinutes: 5,
      ),
    ],
    confidenceNote: '写真の範囲だけを確認しました。',
  );

  test('selects an image and exposes analysis results', () async {
    final picker = _FakePicker(image: _image);
    final analyzer = _FakeAnalyzer(result: advice);
    final viewModel = PhotoActionAdvisorViewModel(
      imagePicker: picker,
      analyzer: analyzer,
    );

    await viewModel.pickAndAnalyze(PhotoActionImageSource.gallery);

    expect(picker.lastSource, PhotoActionImageSource.gallery);
    expect(analyzer.calls, 1);
    expect(viewModel.selectedImage, _image);
    expect(viewModel.advice, advice);
    expect(viewModel.isAnalyzing, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('picker cancellation does not start analysis', () async {
    final analyzer = _FakeAnalyzer(result: advice);
    final viewModel = PhotoActionAdvisorViewModel(
      imagePicker: _FakePicker(),
      analyzer: analyzer,
    );

    await viewModel.pickAndAnalyze(PhotoActionImageSource.camera);

    expect(analyzer.calls, 0);
    expect(viewModel.selectedImage, isNull);
    expect(viewModel.errorMessage, isNull);
  });

  test('keeps selected image and exposes a retryable analysis error', () async {
    final analyzer = _FakeAnalyzer(
      error: const PhotoActionAdvisorException('解析できませんでした。'),
    );
    final viewModel = PhotoActionAdvisorViewModel(
      imagePicker: _FakePicker(image: _image),
      analyzer: analyzer,
    );

    await viewModel.pickAndAnalyze(PhotoActionImageSource.gallery);

    expect(viewModel.selectedImage, _image);
    expect(viewModel.errorMessage, '解析できませんでした。');
    expect(viewModel.requiresLogin, isFalse);
  });

  test('exposes login-required state separately', () async {
    final viewModel = PhotoActionAdvisorViewModel(
      imagePicker: _FakePicker(image: _image),
      analyzer: _FakeAnalyzer(
        error: const PhotoActionAdvisorException(
          'ログインが必要です。',
          requiresLogin: true,
        ),
      ),
    );

    await viewModel.pickAndAnalyze(PhotoActionImageSource.gallery);

    expect(viewModel.requiresLogin, isTrue);
    expect(viewModel.errorMessage, 'ログインが必要です。');
  });
}

final _image = PhotoActionImage(
  bytes: Uint8List.fromList([1, 2, 3]),
  fileName: 'photo.jpg',
  mimeType: 'image/jpeg',
);

class _FakePicker implements PhotoActionImagePicker {
  _FakePicker({this.image});

  final PhotoActionImage? image;
  PhotoActionImageSource? lastSource;

  @override
  Future<PhotoActionImage?> pick(PhotoActionImageSource source) async {
    lastSource = source;
    return image;
  }
}

class _FakeAnalyzer implements PhotoActionAnalyzer {
  _FakeAnalyzer({this.result, this.error});

  final PhotoActionAdvice? result;
  final PhotoActionAdvisorException? error;
  int calls = 0;

  @override
  Future<PhotoActionAdvice> analyze(PhotoActionImage image) async {
    calls++;
    if (error != null) throw error!;
    return result!;
  }
}
