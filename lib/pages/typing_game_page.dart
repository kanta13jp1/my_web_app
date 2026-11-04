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
  final _clock = Stopwatch();
  Timer? _timer;
  String _feedback = '';
  int _best = 0;

  void _start() {
    _timer?.cancel();
    setState(() {
      _game.start();
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
    if (!_game.running) {
      _clock.stop();
      _timer?.cancel();
      _best = _game.score > _best ? _game.score : _best;
      _focus.unfocus();
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
          selection: TextSelection.collapsed(offset: prefix.length),);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ことばのタイピング')),
      body: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              if (!_game.running) _start();
              return null;
            },),
          },
          child: Focus(
            autofocus: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('60秒、ことばに集中。',
                          style: Theme.of(context).textTheme.headlineMedium,),
                      const SizedBox(height: 8),
                      const Text(
                          '日本語のことばをローマ字で入力しよう。正解1文字10点、1問クリアで50点。間違えてもそのまま続けられます。',),
                      const SizedBox(height: 20),
                      Wrap(spacing: 20, runSpacing: 12, children: [
                        Text(
                            '残り ${(_game.remaining.inMilliseconds / 1000).ceil()}秒',),
                        Text('スコア ${_game.score}'),
                        Text('正確さ ${_game.accuracy.toStringAsFixed(1)}%'),
                        Text('クリア ${_game.words}問'),
                        Text('連続 ${_game.combo}文字'),
                      ],),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          value: _game.remaining.inMilliseconds /
                              TypingGame.duration.inMilliseconds,),
                      const SizedBox(height: 20),
                      if (_game.running) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              Text(_game.prompt.japanese,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                  textAlign: TextAlign.center,),
                              const SizedBox(height: 8),
                              Text(_game.prompt.reading),
                              const SizedBox(height: 20),
                              Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                        text: _game.prefix,
                                        style: TextStyle(
                                            color: colors.primary,
                                            decoration:
                                                TextDecoration.underline,),),
                                    TextSpan(
                                        text: _game.guide
                                            .substring(_game.prefix.length),),
                                  ],),
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 24,),
                                  textAlign: TextAlign.center,),
                              const SizedBox(height: 12),
                              Text(
                                  '使えるつづり: ${_game.prompt.spellings.join(' / ')}',
                                  textAlign: TextAlign.center,),
                            ],),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('typing-input'),
                          controller: _input,
                          focusNode: _focus,
                          onTap: () {
                            _input.selection = TextSelection.collapsed(
                                offset: _input.text.length,);
                          },
                          autocorrect: false,
                          enableSuggestions: false,
                          enableInteractiveSelection: false,
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.none,
                          inputFormatters: [
                            TextInputFormatter.withFunction(_format)
                          ,],
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'ローマ字入力',
                              helperText: '英語キーボード・半角英字 / 入力欄をタップで再開',),
                        ),
                        const SizedBox(height: 12),
                        Text(_feedback, textAlign: TextAlign.center),
                      ] else ...[
                        if (_game.finished)
                          Semantics(
                              liveRegion: true,
                              child: Card(
                                  child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(children: [
                                  Text('おつかれさま！ ${_game.score}点',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,),
                                  Text(
                                      '${_game.words}問クリア / 正確さ ${_game.accuracy.toStringAsFixed(1)}%',),
                                  Text(
                                      '最大連続 ${_game.bestCombo}文字 / ミス ${_game.mistakes}回',),
                                  Text('この画面でのベスト $_best点'),
                                ],),
                              ),),),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('typing-start'),
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                              _game.finished ? 'もう一度挑戦（Enter）' : 'スタート（Enter）',),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                          '遊び方: IMEをオフにし、表示されたつづりを一文字ずつ入力します。shi / si などは「使えるつづり」にあるものに対応。削除・貼り付け・かな入力は対象外です。スマートフォンでは英語キーボードを選択してください。ベスト記録はこの画面を閉じるまで。',),
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
