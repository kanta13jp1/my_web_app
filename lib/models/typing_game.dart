import 'dart:math';

class TypingPrompt {
  const TypingPrompt(this.japanese, this.reading, this.spellings);

  final String japanese;
  final String reading;
  final List<String> spellings;
}

/// A deliberately small, curated vocabulary with explicit spelling variants.
/// No network, persistence, or platform keyboard dependency.
class TypingGame {
  TypingGame({Random? random}) : _random = random ?? Random();

  static const duration = Duration(seconds: 60);
  static const prompts = <TypingPrompt>[
    TypingPrompt('桜', 'さくら', ['sakura']),
    TypingPrompt('青空', 'あおぞら', ['aozora']),
    TypingPrompt('新しい一歩', 'あたらしいいっぽ', ['atarashiiippo', 'atarasiiippo']),
    TypingPrompt('小さな発見', 'ちいさなはっけん', ['chiisanahakken', 'tiisanahakken']),
    TypingPrompt('深呼吸', 'しんこきゅう', ['shinkokyuu', 'sinkokyuu']),
    TypingPrompt('挑戦', 'ちょうせん', ['chousen', 'tyousen']),
    TypingPrompt('休憩', 'きゅうけい', ['kyuukei']),
    TypingPrompt('図書館', 'としょかん', ['toshokan', 'tosyokan']),
    TypingPrompt('朝の散歩', 'あさのさんぽ', ['asanosanpo']),
    TypingPrompt('星空', 'ほしぞら', ['hoshizora', 'hosizora']),
    TypingPrompt('未来', 'みらい', ['mirai']),
    TypingPrompt('ありがとう', 'ありがとう', ['arigatou']),
  ];

  final Random _random;
  late List<TypingPrompt> _deck;
  int _index = 0;
  bool running = false;
  bool finished = false;
  Duration remaining = duration;
  String prefix = '';
  int correct = 0;
  int mistakes = 0;
  int words = 0;
  int combo = 0;
  int bestCombo = 0;
  int score = 0;

  TypingPrompt get prompt => _deck[_index];
  String get guide => prompt.spellings.firstWhere((s) => s.startsWith(prefix));
  double get accuracy =>
      correct + mistakes == 0 ? 100 : correct * 100 / (correct + mistakes);

  void start() {
    _deck = [...prompts]..shuffle(_random);
    _index = 0;
    running = true;
    finished = false;
    remaining = duration;
    prefix = '';
    correct = mistakes = words = combo = bestCombo = score = 0;
  }

  void updateElapsed(Duration elapsed) {
    if (!running) return;
    remaining = elapsed >= duration ? Duration.zero : duration - elapsed;
    if (remaining == Duration.zero) {
      running = false;
      finished = true;
    }
  }

  /// Accepts one physical or soft-keyboard letter. Edits/paste are handled by UI.
  bool type(String letter) {
    if (!running || !RegExp(r'^[a-zA-Z]$').hasMatch(letter)) return false;
    final next = prefix + letter.toLowerCase();
    if (!prompt.spellings.any((s) => s.startsWith(next))) {
      mistakes++;
      combo = 0;
      return false;
    }
    correct++;
    combo++;
    bestCombo = max(bestCombo, combo);
    score += 10;
    if (prompt.spellings.contains(next)) {
      words++;
      score += 50;
      _index = (_index + 1) % _deck.length;
      prefix = '';
    } else {
      prefix = next;
    }
    return true;
  }
}
