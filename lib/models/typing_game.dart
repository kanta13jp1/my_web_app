import 'dart:math';

enum TypingMode { challenge, practice }

class TypingPrompt {
  const TypingPrompt(this.japanese, this.reading, this.spellings);

  final String japanese;
  final String reading;
  final List<String> spellings;
}

class TypingMistake {
  const TypingMistake(this.prompt, this.count);

  final TypingPrompt prompt;
  final int count;
}

/// Curated, explicit spellings. Runs and review data stay in memory only.
class TypingGame {
  TypingGame({Random? random}) : _random = random ?? Random();

  static const duration = Duration(seconds: 60);
  static const practiceTarget = 10;
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
    TypingPrompt('りんご', 'りんご', ['ringo']),
    TypingPrompt('猫', 'ねこ', ['neko']),
    TypingPrompt('犬', 'いぬ', ['inu']),
    TypingPrompt('海', 'うみ', ['umi']),
    TypingPrompt('山', 'やま', ['yama']),
    TypingPrompt('風', 'かぜ', ['kaze']),
    TypingPrompt('雨', 'あめ', ['ame']),
    TypingPrompt('虹', 'にじ', ['niji', 'nizi']),
    TypingPrompt('太陽', 'たいよう', ['taiyou']),
    TypingPrompt('月', 'つき', ['tsuki', 'tuki']),
    TypingPrompt('花火', 'はなび', ['hanabi']),
    TypingPrompt('ひまわり', 'ひまわり', ['himawari']),
    TypingPrompt('手紙', 'てがみ', ['tegami']),
    TypingPrompt('音楽', 'おんがく', ['ongaku']),
    TypingPrompt('楽しい', 'たのしい', ['tanoshii', 'tanosii']),
    TypingPrompt('笑顔', 'えがお', ['egao']),
    TypingPrompt('仲間', 'なかま', ['nakama']),
    TypingPrompt('おはよう', 'おはよう', ['ohayou']),
    TypingPrompt('こんにちは', 'こんにちは', ['konnichiwa', 'konnitiwa']),
    TypingPrompt('自転車', 'じてんしゃ', ['jitensha', 'zitensya']),
    TypingPrompt('お茶', 'おちゃ', ['ocha', 'otya']),
    TypingPrompt('船', 'ふね', ['fune', 'hune']),
    TypingPrompt('一緒に', 'いっしょに', ['isshoni', 'issyoni']),
    TypingPrompt('明日', 'あした', ['ashita', 'asita']),
  ];

  final Random _random;
  final Map<TypingPrompt, int> _misses = {};
  late List<TypingPrompt> _deck;
  int _index = 0;
  TypingMode mode = TypingMode.challenge;
  bool running = false;
  bool finished = false;
  Duration remaining = duration;
  Duration elapsed = Duration.zero;
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
  double get correctPerMinute => elapsed.inMilliseconds == 0
      ? 0
      : correct * 60000 / elapsed.inMilliseconds;
  List<TypingMistake> get review {
    final result = _misses.entries
        .map((entry) => TypingMistake(entry.key, entry.value))
        .toList()
      ..sort((a, b) {
        final count = b.count.compareTo(a.count);
        return count != 0 ? count : a.prompt.japanese.compareTo(b.prompt.japanese);
      });
    return List.unmodifiable(result);
  }

  void start({
    TypingMode mode = TypingMode.challenge,
    Iterable<TypingPrompt>? practicePrompts,
  }) {
    final deck = (practicePrompts ?? prompts).toSet().toList();
    if (deck.isEmpty ||
        (practicePrompts != null && mode != TypingMode.practice)) {
      throw ArgumentError('Custom prompts require a nonempty practice run');
    }
    this.mode = mode;
    _deck = deck..shuffle(_random);
    _index = 0;
    running = true;
    finished = false;
    remaining = duration;
    elapsed = Duration.zero;
    prefix = '';
    correct = mistakes = words = combo = bestCombo = score = 0;
    _misses.clear();
  }

  void updateElapsed(Duration value) {
    if (!running || value < elapsed) return;
    elapsed = mode == TypingMode.challenge && value >= duration ? duration : value;
    if (mode == TypingMode.challenge) {
      remaining = duration - elapsed;
      if (remaining == Duration.zero) _finish();
    }
  }

  void finishPractice() {
    if (running && mode == TypingMode.practice) _finish();
  }

  void _finish() {
    running = false;
    finished = true;
  }

  /// Accepts one physical or soft-keyboard letter. Edits/paste are handled by UI.
  bool type(String letter) {
    if (!running || !RegExp(r'^[a-zA-Z]$').hasMatch(letter)) return false;
    final next = prefix + letter.toLowerCase();
    if (!prompt.spellings.any((s) => s.startsWith(next))) {
      mistakes++;
      _misses.update(prompt, (count) => count + 1, ifAbsent: () => 1);
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
      prefix = '';
      if (mode == TypingMode.practice && words == practiceTarget) {
        _finish();
      } else {
        final previous = prompt;
        _index++;
        if (_index == _deck.length) {
          _deck.shuffle(_random);
          _index = 0;
          if (_deck.length > 1 && _deck.first == previous) {
            final first = _deck[0];
            _deck[0] = _deck[1];
            _deck[1] = first;
          }
        }
      }
    } else {
      prefix = next;
    }
    return true;
  }
}
