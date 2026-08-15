/// VM (単体/widget テスト) 用の `package:web` 最小スタブ。
/// Web ビルドでは条件付き import により本物の package:web が使われる。
library;

class TextDecoder {
  const TextDecoder(this.encoding);

  final String encoding;

  String decode(Object? input) {
    throw UnsupportedError('TextDecoder は Web ビルド専用です');
  }
}

class Window {
  const Window();

  void open(String url, String target) {}
}

const Window window = Window();
