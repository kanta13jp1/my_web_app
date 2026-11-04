import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _bestChallenge = 0;
  TypingMode _selectedMode = TypingMode.challenge;
  bool _reviewPractice = false;

  void _start({List<TypingPrompt>? review}) {
    _timer?.cancel();
    setState(() {
      if (review != null) _selectedMode = TypingMode.practice;
      _reviewPractice = review != null;
      _game.start(mode: _selectedMode, practicePrompts: review);
      _feedback = 'さあ、最初の一文字！';
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

  TextEditingValue _format(TextEditingValue old, TextEditingValue next) {
    setState(_tick);
    if (!_game.running) return old;
    if (!next.composing.isCollapsed) {
      setState(() => _feedback = 'IMEをオフにして、半角英字で入力してください');
      return old;
    }
    final prefix = _game.prefix;
    if (next.text.length != prefix.length + 1 ||
        !next.text.startsWith(prefix)) {
      setState(() => _feedback = '一文字ずつ入力。削除や貼り付けは使いません');
      return TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: prefix.length),
      );
    }
    final letter = next.text.substring(prefix.length);
    setState(() {
      if (!RegExp(r'^[a-zA-Z]$').hasMatch(letter)) {
        _feedback = '半角英字で入力してください（IMEオフ）';
      } else {
        final words = _game.words;
        final accepted = _game.type(letter);
        _feedback = !accepted
            ? '惜しい！次の文字を確認しよう'
            : _game.words > words
                ? 'クリア！次のことばへ'
                : '${_game.combo}文字連続！';
      }
    });
    _settle();
    return TextEditingValue(
      text: _game.prefix,
      selection: TextSelection.collapsed(offset: _game.prefix.length),
    );
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
            Text('間違えたことばを振り返ろう',
                style: Theme.of(context).textTheme.titleMedium,),
            const SizedBox(height: 8),
            for (final item in review.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${item.prompt.japanese}（${item.prompt.reading}）'
                    ' / ミス ${item.count}回\n'
                    '${item.prompt.spellings.join(' / ')}'),
              ),
            if (review.length > 5)
              Text('ほか${review.length - 5}語。再練習は間違えたことばから10問出題します。'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _start(review: review.map((item) => item.prompt).toList()),
              icon: const Icon(Icons.replay),
              label: const Text('苦手なことばを練習'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('ことばのタイピング')),
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
                        practice ? '自分のペースで、10問。' : '60秒、ことばに集中。',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '36種類のことばをローマ字で入力しよう。正解1文字10点、1問クリアで50点。間違えてもそのまま続けられます。',
                      ),
                      if (!_game.running) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (final mode in TypingMode.values)
                              ChoiceChip(
                                label: Text(mode == TypingMode.challenge
                                    ? '60秒チャレンジ'
                                    : '10問じっくり練習',),
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
                        Text(_selectedMode == TypingMode.practice
                            ? '時間制限なし。10問クリアで終了。途中でも練習を終えられます。'
                            : '60秒間のスコアに挑戦。ベストはチャレンジ同士で比べます。',),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        children: [
                          Text(
                            practice
                                ? '進み具合 ${_game.words} / 10問'
                                : '残り ${(_game.remaining.inMilliseconds / 1000).ceil()}秒',
                          ),
                          Text('スコア ${_game.score}'),
                          Text('正確さ ${_game.accuracy.toStringAsFixed(1)}%'),
                          Text('クリア ${_game.words}問'),
                          Text('連続 ${_game.combo}文字'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: practice
                            ? _game.words / TypingGame.practiceTarget
                            : _game.remaining.inMilliseconds /
                                TypingGame.duration.inMilliseconds,
                        semanticsLabel: practice ? '練習の進み具合' : '残り時間',
                        semanticsValue: practice
                            ? '${_game.words} / 10問'
                            : '${(_game.remaining.inMilliseconds / 1000).ceil()}秒',
                      ),
                      const SizedBox(height: 20),
                      if (_game.running) ...[
                        if (_reviewPractice)
                          const Text('苦手なことばを10問練習中',
                              textAlign: TextAlign.center,),
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
                                  '使えるつづり: ${_game.prompt.spellings.join(' / ')}',
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
                            _input.selection = TextSelection.collapsed(
                              offset: _input.text.length,
                            );
                          },
                          autocorrect: false,
                          enableSuggestions: false,
                          enableInteractiveSelection: false,
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            TextInputFormatter.withFunction(_format),
                          ],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'ローマ字入力',
                            helperText: '英語キーボード・半角英字 / 入力欄をタップで再開',
                            helperMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_feedback, textAlign: TextAlign.center,),
                        if (practice)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _game.updateElapsed(_clock.elapsed);
                                _game.finishPractice();
                                _settle();
                              });
                            },
                            child: const Text('練習を終える'),
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
                                          ? '10問完走！ ${_game.score}点'
                                          : 'おつかれさま！ ${_game.score}点',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    Text(
                                      '${_game.words}問クリア / 正確さ ${_game.accuracy.toStringAsFixed(1)}%',
                                    ),
                                    Text(
                                      '最大連続 ${_game.bestCombo}文字 / ミス ${_game.mistakes}回',
                                    ),
                                    Text(
                                        '入力ペース ${_game.correctPerMinute.toStringAsFixed(1)}文字/分',),
                                    const Text('正解したローマ字数 ÷ 実際のプレイ時間'),
                                    if (!practice)
                                      Text('この画面でのチャレンジベスト $_bestChallenge点'),
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
                            _game.finished ? 'もう一度挑戦（Enter）' : 'スタート（Enter）',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '遊び方: IMEをオフにし、表示されたつづりを一文字ずつ入力します。shi / si などは「使えるつづり」にあるものに対応。削除・貼り付け・かな入力は対象外です。スマートフォンでは英語キーボードを選択してください。成績と振り返りはこの画面を閉じるまで。練習モードの成績はチャレンジのベストに含めません。',
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
  }
}
