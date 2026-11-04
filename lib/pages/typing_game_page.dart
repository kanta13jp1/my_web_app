import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../models/typing_game.dart';

class TypingGamePage extends StatefulWidget {
  const TypingGamePage({super.key});

  @override
  State<TypingGamePage> createState() => _TypingGamePageState();
}

class _TypingGamePageState extends State<TypingGamePage> {
  final _game = TypingGame();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _controlsFocus = FocusNode();
  final _clock = Stopwatch();
  Timer? _timer;
  String _feedback = '';
  bool _announceFeedback = false;
  int _bestChallenge = 0;
  TypingMode _selectedMode = TypingMode.challenge;
  bool _reviewPractice = false;
  bool _english = false;

  String _t(String japanese, String english) => _english ? english : japanese;

  void _start({List<TypingPrompt>? review}) {
    _timer?.cancel();
    setState(() {
      if (review != null) _selectedMode = TypingMode.practice;
      _reviewPractice = review != null;
      _announceFeedback = false;
      _game.start(mode: _selectedMode, practicePrompts: review);
      _feedback = _t(
        'さあ、最初の一文字！',
        'Ready for your first letter!',
      );
      _input.clear();
    });
    _clock.reset();
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(_tick);
    });
    _focus.requestFocus();
  }

  void _tick() {
    _game.updateElapsed(_clock.elapsed);
    _settle();
  }

  void _settle() {
    if (_game.finished) {
      _clock.stop();
      _timer?.cancel();
      if (_game.mode == TypingMode.challenge && _game.score > _bestChallenge) {
        _bestChallenge = _game.score;
      }
      _focus.unfocus();
      _controlsFocus.requestFocus();
    }
  }

  TextEditingValue _canonicalInput() => TextEditingValue(
        text: _game.prefix,
        selection: TextSelection.collapsed(offset: _game.prefix.length),
      );

  void _inputFeedback(String japanese, String english, {bool announce = true}) {
    _feedback = _t(japanese, english);
    _announceFeedback = announce;
  }

  TextEditingValue _format(TextEditingValue old, TextEditingValue next) {
    setState(_tick);
    // Never rewrite a live IME candidate. The OS may restore it indefinitely.
    if (!next.composing.isCollapsed) {
      setState(() {
        _inputFeedback(
          '変換中です。英語キーボードでローマ字を確定してください。確定後に採点します。',
          'Composing text. Confirm Latin letters with an English keyboard to score them.',
        );
      });
      return next;
    }
    if (!_game.running) return next;
    final prefix = _game.prefix;
    final composed = old.composing.isValid && !old.composing.isCollapsed;
    var text = next.text;
    var compositionCommit = false;
    if (composed) {
      // Some soft keyboards append one space when confirming a candidate.
      final candidate = old.text.endsWith(' ')
          ? old.text.substring(0, old.text.length - 1)
          : old.text;
      if (text == candidate || text == '$candidate ') {
        text = candidate;
        compositionCommit = true;
      }
    }
    if (text == prefix) {
      if (composed) {
        setState(() => _inputFeedback(
              '入力を続けられます。',
              'Continue typing when ready.',
              announce: false,
            ),);
      }
      return _canonicalInput();
    }
    if (!text.startsWith(prefix) ||
        text.length <= prefix.length ||
        (!compositionCommit && text.length != prefix.length + 1)) {
      setState(() => _inputFeedback(
            '一文字ずつ入力するか、変換中のローマ字を確定してください。削除や貼り付けは使いません。',
            'Type one letter at a time, or confirm composed romaji. Deleting and pasting are not supported.',
          ),);
      return _canonicalInput();
    }
    final letters = text.substring(prefix.length);
    final limit = _game.prompt.spellings.fold<int>(
          0,
          (longest, spelling) =>
              spelling.length > longest ? spelling.length : longest,
        ) -
        prefix.length;
    if (letters.length > limit ||
        (compositionCommit &&
            _game.prompt.spellings.any(
              (spelling) => text.startsWith(spelling) && text.length > spelling.length,
            ))) {
      setState(() => _inputFeedback(
            '一つのお題ずつローマ字を確定してください。',
            'Confirm one prompt at a time.',
          ),);
      return _canonicalInput();
    }
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(letters)) {
      setState(() => _inputFeedback(
            'かな変換をオフにし、半角英字で入力してください。',
            'Turn off kana conversion and use Latin letters.',
          ),);
      return _canonicalInput();
    }
    setState(() {
      final words = _game.words;
      var accepted = true;
      for (final letter in letters.split('')) {
        if (!_game.type(letter)) {
          accepted = false;
          break;
        }
        if (_game.words > words) break;
      }
      _announceFeedback = !accepted;
      _feedback = !accepted
          ? _t('惜しい！次の文字を確認しよう', 'Almost! Check the next letter.',)
          : _game.words > words
              ? _t('クリア！次のことばへ', 'Word complete! Try the next one.',)
              : _t('${_game.combo}文字連続！', '${_game.combo} letters in a row!',);
    });
    _settle();
    return _canonicalInput();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    _input.dispose();
    _focus.dispose();
    _controlsFocus.dispose();
    super.dispose();
  }

  Widget _reviewCard(BuildContext context) {
    final review = _game.review;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(
                '間違えたことばを振り返ろう',
                'Words to practise',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final item in review.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${item.prompt.japanese}（${item.prompt.reading}）\n'
                  '${_t('ミス ${item.count}回', 'Mistakes ${item.count}')}\n'
                  '${item.prompt.spellings.join(' / ')}',
                ),
              ),
            if (review.length > 5)
              Text(
                _t(
                  'ほか${review.length - 5}語。再練習は間違えたことばから10問出題します。',
                  '${review.length - 5} more words. Focused practice picks ten prompts from all your missed words.',
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _start(review: review.map((item) => item.prompt).toList()),
              icon: const Icon(Icons.replay),
              label: Text(
                _t(
                  '苦手なことばを練習',
                  'Practise missed words',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final practice =
        (_game.running || _game.finished ? _game.mode : _selectedMode) ==
            TypingMode.practice;
    final page = Scaffold(
      appBar: AppBar(
        title: Text(_t('ことばのタイピング', 'Kotoba Typing')),
        actions: [
          TextButton(
            key: const Key('typing-language'),
            onPressed: _game.running
                ? null
                : () => setState(() => _english = !_english),
            child: Text(_english ? '日本語' : 'English'),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (!_game.running) _start();
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _controlsFocus,
            autofocus: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        practice
                            ? _t(
                                '自分のペースで、10問。',
                                'Ten words, at your own pace.',
                              )
                            : _t(
                                '60秒、ことばに集中。',
                                'One minute. Find your rhythm.',
                              ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          '36種類のことばをローマ字で入力しよう。正解1文字10点、1問クリアで50点。間違えてもそのまま続けられます。',
                          'Practise 36 Japanese words in romaji. Each correct letter scores 10 points; each word adds 50. Keep going after a mistake.',
                        ),
                      ),
                      if (!_game.running) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (final mode in TypingMode.values)
                              ChoiceChip(
                                label: Text(
                                  mode == TypingMode.challenge
                                      ? _t(
                                          '60秒チャレンジ',
                                          '60-second challenge',
                                        )
                                      : _t(
                                          '10問じっくり練習',
                                          '10-word practice',
                                        ),
                                ),
                                selected: _selectedMode == mode,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedMode = mode);
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedMode == TypingMode.practice
                              ? _t(
                                  '時間制限なし。10問クリアで終了。途中でも練習を終えられます。',
                                  'No time limit. Finish ten words, or end practice whenever you like.',
                                )
                              : _t(
                                  '60秒間のスコアに挑戦。ベストはチャレンジ同士で比べます。',
                                  'Challenge yourself for 60 seconds. Only challenge scores count towards your best.',
                                ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: [
                          Text(
                            practice
                                ? _t(
                                    '進み具合 ${_game.words} / 10問',
                                    'Progress ${_game.words} / 10 words',
                                  )
                                : _t(
                                    '残り ${(_game.remaining.inMilliseconds / 1000).ceil()}秒',
                                    'Time left ${(_game.remaining.inMilliseconds / 1000).ceil()}s',
                                  ),
                          ),
                          Text(
                            _t(
                              'スコア ${_game.score}',
                              'Score ${_game.score}',
                            ),
                          ),
                          Text(
                            _t(
                              '正確さ ${_game.accuracy.toStringAsFixed(1)}%',
                              'Accuracy ${_game.accuracy.toStringAsFixed(1)}%',
                            ),
                          ),
                          Text(
                            _t(
                              'クリア ${_game.words}問',
                              'Words ${_game.words}',
                            ),
                          ),
                          Text(
                            _t(
                              '連続 ${_game.combo}文字',
                              'Streak ${_game.combo} letters',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: practice
                            ? _game.words / TypingGame.practiceTarget
                            : _game.remaining.inMilliseconds /
                                TypingGame.duration.inMilliseconds,
                        semanticsLabel: practice
                            ? _t(
                                '練習の進み具合',
                                'Practice progress',
                              )
                            : _t(
                                '残り時間',
                                'Time left',
                              ),
                        semanticsValue: practice
                            ? _t(
                                '${_game.words} / 10問',
                                '${_game.words} / 10 words',
                              )
                            : _t(
                                '${(_game.remaining.inMilliseconds / 1000).ceil()}秒',
                                '${(_game.remaining.inMilliseconds / 1000).ceil()} seconds',
                              ),
                      ),
                      const SizedBox(height: 20),
                      if (_game.running) ...[
                        if (_reviewPractice)
                          Text(
                            _t(
                              '苦手なことばを10問練習中',
                              'Focused practice: ten prompts from your missed words',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  _game.prompt.japanese,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(_game.prompt.reading),
                                const SizedBox(height: 20),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _game.prefix,
                                        style: TextStyle(
                                          color: colors.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      TextSpan(
                                        text: _game.guide
                                            .substring(_game.prefix.length),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 24,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _t(
                                    '使えるつづり: ${_game.prompt.spellings.join(' / ')}',
                                    'Accepted spellings: ${_game.prompt.spellings.join(' / ')}',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('typing-input'),
                          controller: _input,
                          focusNode: _focus,
                          onTap: () {
                            if (!_input.value.composing.isCollapsed) return;
                            _input.selection = TextSelection.collapsed(
                              offset: _input.text.length,
                            );
                          },
                          autocorrect: false,
                          enableSuggestions: false,
                          enableInteractiveSelection: false,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          // Confirming a word must not dismiss the typing keyboard.
                          onEditingComplete: () {},
                          enableIMEPersonalizedLearning: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            TextInputFormatter.withFunction(_format),
                          ],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: _t(
                              'ローマ字入力',
                              'Romaji input',
                            ),
                            helperText: _t(
                              '英語キーボード・半角英字 / 変換中は確定後に採点 / 入力欄をタップで再開',
                              'Use Latin letters. Composed text scores after confirmation. Tap the input to continue.',
                            ),
                            helperMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: _announceFeedback,
                          child: Text(
                            _feedback,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (practice)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _game.updateElapsed(_clock.elapsed);
                                _game.finishPractice();
                                _settle();
                              });
                            },
                            child: Text(
                              _t(
                                '練習を終える',
                                'End practice',
                              ),
                            ),
                          ),
                      ] else ...[
                        if (_game.finished)
                          Semantics(
                            liveRegion: true,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(
                                      practice &&
                                              _game.words ==
                                                  TypingGame.practiceTarget
                                          ? _t(
                                              '10問完走！ ${_game.score}点',
                                              'Ten words complete! ${_game.score} points',
                                            )
                                          : _t(
                                              'おつかれさま！ ${_game.score}点',
                                              'Well done! ${_game.score} points',
                                            ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    Text(
                                      _t(
                                        '${_game.words}問クリア / 正確さ ${_game.accuracy.toStringAsFixed(1)}%',
                                        '${_game.words} words / Accuracy ${_game.accuracy.toStringAsFixed(1)}%',
                                      ),
                                    ),
                                    Text(
                                      _t(
                                        '最大連続 ${_game.bestCombo}文字 / ミス ${_game.mistakes}回',
                                        'Best streak ${_game.bestCombo} letters / Mistakes ${_game.mistakes}',
                                      ),
                                    ),
                                    Text(
                                      _t(
                                        '入力ペース ${_game.correctPerMinute.toStringAsFixed(1)}文字/分',
                                        'Pace ${_game.correctPerMinute.toStringAsFixed(1)} letters/min',
                                      ),
                                    ),
                                    Text(
                                      _t(
                                        '正解したローマ字数 ÷ 実際のプレイ時間',
                                        'Correct romaji letters divided by actual play time',
                                      ),
                                    ),
                                    if (!practice)
                                      Text(
                                        _t(
                                          'この画面でのチャレンジベスト $_bestChallenge点',
                                          'Challenge best on this screen: $_bestChallenge points',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_game.finished && _game.review.isNotEmpty)
                          _reviewCard(context),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('typing-start'),
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            _game.finished
                                ? _t(
                                    'もう一度挑戦（Enter）',
                                    'Try again (Enter)',
                                  )
                                : _t(
                                    'スタート（Enter）',
                                    'Start (Enter)',
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        _t(
                          '遊び方: 英語キーボードで、表示されたつづりを入力します。変換中の文字は確定後に採点します。shi / si などは「使えるつづり」にあるものに対応。削除・貼り付け・かな入力は対象外です。スマートフォンでは英語キーボードを選択してください。成績と振り返りはこの画面を閉じるまで。練習モードの成績はチャレンジのベストに含めません。',
                          'How to play: use an English keyboard. Type letters individually, or confirm composed Latin text to score it. Only the listed spellings, such as shi / si, are accepted. Deleting, pasting and kana input are not supported. On a phone, select an English keyboard. Scores, review and language choice last until this screen closes. Practice scores do not count towards your challenge best.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return _english
        ? Localizations.override(
            context: context,
            locale: const Locale('en'),
            delegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            child: page,
          )
        : page;
  }
}
