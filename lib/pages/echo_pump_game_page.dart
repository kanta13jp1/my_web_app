import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import '../services/echo_pump_audio.dart';
import '../widgets/echo_pump_audio_controls.dart';
import '../widgets/echo_pump_title_screen.dart';
import '../widgets/echo_pump_intro.dart';
import '../widgets/echo_pump_visuals.dart';

class EchoPumpGamePage extends StatefulWidget {
  const EchoPumpGamePage({super.key, this.audio});

  final EchoPumpAudio? audio;

  @override
  State<EchoPumpGamePage> createState() => _EchoPumpGamePageState();
}

class _EchoPumpGamePageState extends State<EchoPumpGamePage>
    with WidgetsBindingObserver {
  EchoPumpGame _game = EchoPumpGame();
  bool _started = false;
  bool _introPlaying = false;

  late final EchoPumpAudio _audio;

  @override
  void initState() {
    super.initState();
    _audio = widget.audio ?? EchoPumpAudio();
    _audio.setForeground(true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _audio.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.setForeground(false);
    if (widget.audio == null) _audio.dispose();
    super.dispose();
  }

  void _act(VoidCallback action, [EchoPumpCue? cue]) {
    final health = _game.health;
    final turn = _game.turn;
    setState(action);
    _audio.setMusicActive(!_game.finished);
    if (_game.escaped) {
      _audio.cue(EchoPumpCue.escape);
    } else if (_game.health == 0) {
      _audio.cue(EchoPumpCue.fail);
    } else if (_game.health < health) {
      _audio.cue(EchoPumpCue.damage);
    } else if (cue != null && (_game.turn != turn || cue == EchoPumpCue.start)) {
      _audio.cue(cue);
    }
  }

  void _beginIntro() {
    if (_started || _introPlaying) return;
    setState(() => _introPlaying = true);
    _audio.cue(EchoPumpCue.start);
  }

  void _startGame() {
    if (_started) {
      return;
    }
    setState(() {
      _game = EchoPumpGame();
      _started = true;
      _introPlaying = false;
    });
    _audio.setMusicActive(true);
    _audio.cue(EchoPumpCue.start);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildScreen(context)),
        EchoPumpAudioControls(audio: _audio),
      ],
    );
  }

  Widget _buildScreen(BuildContext context) {
    if (_introPlaying) {
      return EchoPumpIntro(onFinished: _startGame);
    }
    if (!_started) {
      return EchoPumpTitleScreen(onStart: _beginIntro);
    }
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64D8C2),
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF10191D),
        appBar: AppBar(
          title: const Text('残響ポンプ室'),
          actions: [
            IconButton(
              tooltip: '最初からやり直す',
              onPressed: () => _act(() => _game = EchoPumpGame(), EchoPumpCue.start),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EchoPumpScene(game: _game),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _game.repaired
                              ? '修理済み'
                              : _game.hasFuse
                                  ? 'ヒューズ所持'
                                  : 'ヒューズ未回収',
                        ),
                      ),
                      Chip(
                        label: Text(
                          _game.sealed ? '敵：封鎖済み' : '敵：${_game.enemy.label}',
                        ),
                      ),
                    ],
                  ),
                  _panel(
                    '現在の目標',
                    [
                      Text(
                        _game.objective,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  Semantics(
                    liveRegion: true,
                    child: _panel('状況', [Text(_game.message)]),
                  ),
                  if (_game.finished)
                    _panel(
                      _game.escaped ? '脱出成功' : '探索失敗',
                      [
                        Text(
                          _game.escaped
                              ? '施設の仕組みを使って、生還できた。'
                              : '敵の位置と音の行き先を確認してみよう。',
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('echo-retry'),
                          onPressed: () => _act(() => _game = EchoPumpGame(), EchoPumpCue.start),
                          icon: const Icon(Icons.replay),
                          label: const Text('リトライ'),
                        ),
                      ],
                    ),
                  _panel('施設の見取り図', [
                    EchoPumpFacilityMap(game: _game),
                    const SizedBox(height: 8),
                    const Text('隣の部屋へは下の移動ボタンから進める。管理室は安全。'),
                  ]),
                  const ExpansionTile(
                    title: Text('探索のヒント'),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('移動・通電・作業・待機の1操作で敵が1部屋動く。'
                            '最後に入れた電源の機械音へ向かう。通電は最大2系統。'
                            'ヒューズで修理し、敵を点検槽に封鎖してから排水する。'),
                      ),
                    ],
                  ),
                  _panel('移動・待機', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final room in _game.destinations)
                          OutlinedButton(
                            key: Key('echo-move-${room.name}'),
                            onPressed: _game.finished ||
                                    (room == PumpRoom.exit && !_game.drained) ||
                                    (room == PumpRoom.inspection &&
                                        _game.sealed)
                                ? null
                                : () => _act(() => _game.move(room), EchoPumpCue.step),
                            child: Text('${room.label}へ'),
                          ),
                        OutlinedButton.icon(
                          key: const Key('echo-wait'),
                          onPressed:
                              _game.finished ? null : () => _act(_game.wait),
                          icon: const Icon(Icons.hearing),
                          label: const Text('1ターン待つ'),
                        ),
                      ],
                    ),
                  ]),
                  if (_game.room == PumpRoom.control)
                    _panel('配電盤 / 最大2系統', [
                      Text(
                        _game.noiseRoom == null
                            ? '稼働音なし：敵はその場に留まる。'
                            : '音の行き先：${_game.noiseRoom!.label}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final circuit in PumpCircuit.values)
                            FilterChip(
                              key: Key('echo-power-${circuit.name}'),
                              label: Text(circuit.label),
                              selected: _game.power.contains(circuit),
                              onSelected: _game.finished
                                  ? null
                                  : (_) =>
                                      _act(() => _game.togglePower(circuit), EchoPumpCue.power),
                            ),
                        ],
                      ),
                      const Text('3系統目を入れる前に、どれか1つを停止。'
                          '\nA：搬入ファン / B：工具棚とコンプレッサー / C：点検槽のベルと排水'),
                    ]),
                  if (_game.room == PumpRoom.workshop)
                    _panel('工具棚', [
                      FilledButton(
                        key: const Key('echo-collect'),
                        onPressed:
                            _game.finished || _game.hasFuse || _game.repaired
                                ? null
                                : () => _act(_game.collectFuse, EchoPumpCue.collect),
                        child: const Text('ヒューズを回収'),
                      ),
                      const Text('B系統が必要。敵が工具庫へ来る前に、別の音へ誘おう。'),
                    ]),
                  if (_game.room == PumpRoom.pump)
                    _panel('ポンプ制御', [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            key: const Key('echo-repair'),
                            onPressed: _game.finished || !_game.hasFuse
                                ? null
                                : () => _act(_game.repair, EchoPumpCue.repair),
                            child: const Text('ヒューズで修理'),
                          ),
                          FilledButton(
                            key: const Key('echo-seal'),
                            onPressed: _game.finished ||
                                    _game.sealed ||
                                    _game.enemy != PumpRoom.inspection ||
                                    !_game.power.contains(PumpCircuit.c)
                                ? null
                                : () => _act(_game.seal, EchoPumpCue.seal),
                            child: const Text('隔壁を閉じる'),
                          ),
                          FilledButton(
                            key: const Key('echo-drain'),
                            onPressed: _game.finished ||
                                    !_game.repaired ||
                                    !_game.sealed ||
                                    _game.drained ||
                                    !_game.power.contains(PumpCircuit.c)
                                ? null
                                : () => _act(_game.drain, EchoPumpCue.drain),
                            child: const Text('排水ポンプを起動'),
                          ),
                        ],
                      ),
                    ]),
                  const SizedBox(height: 12),
                  const Text('最小版：BGM・SEは下の「音をON」で再生 / 3D・射撃・保存なし。'
                      '再読込で最初から。敵の位置は全表示。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
