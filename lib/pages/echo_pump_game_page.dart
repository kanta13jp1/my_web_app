import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import '../services/echo_pump_audio.dart';
import '../widgets/echo_pump_audio_controls.dart';
import '../widgets/echo_pump_title_screen.dart';
import '../widgets/echo_pump_intro.dart';
import '../widgets/echo_pump_visuals.dart';
import '../widgets/echo_pump_guidance.dart';
import '../widgets/echo_pump_inventory.dart';
import '../widgets/echo_pump_incident.dart';

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
  int _actionRevision = 0;
  EchoPumpCue? _visualCue = EchoPumpCue.start;
  PumpRoom _fromRoom = PumpRoom.control;
  bool _blocked = false;
  bool _inventoryOpen = false;
  bool _incidentOpen = false;
  EchoPumpGame? _inspectedIncidentGame;

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
    final from = _game.room;
    setState(() {
      action();
      _actionRevision++;
      _fromRoom = from;
      _blocked = _game.turn == turn && cue != EchoPumpCue.start;
      _visualCue = _game.escaped
          ? EchoPumpCue.escape
          : _game.health == 0
              ? EchoPumpCue.fail
              : _game.health < health
                  ? EchoPumpCue.damage
                  : cue;
    });
    _audio.setMusicActive(!_game.finished);
    if (_game.escaped) {
      _audio.cue(EchoPumpCue.escape);
    } else if (_game.health == 0) {
      _audio.cue(EchoPumpCue.fail);
    } else if (_game.health < health) {
      _audio.cue(EchoPumpCue.damage);
    } else if (cue != null &&
        (_game.turn != turn || cue == EchoPumpCue.start)) {
      _audio.cue(cue);
    }
  }

  Future<void> _openInventory(BuildContext inventoryContext) async {
    if (_inventoryOpen || _incidentOpen) return;
    _inventoryOpen = true;
    final effectsStopped = _audio.suspendEffects();
    final inspectedGame = _game;
    EchoPumpInventoryAction? result;
    try {
      result = await showDialog<EchoPumpInventoryAction>(
        context: inventoryContext,
        useRootNavigator: false,
        builder: (_) => FutureBuilder<void>(
          future: effectsStopped,
          builder: (_, snapshot) =>
              snapshot.connectionState == ConnectionState.done
                  ? EchoPumpInventoryDialog(game: inspectedGame)
                  : const AlertDialog(
                      title: Text('所持品を準備中…'),
                      content: SizedBox(
                        height: 32,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
        ),
      );
    } finally {
      _inventoryOpen = false;
      _audio.resumeEffects();
    }
    if (!mounted || !identical(inspectedGame, _game)) return;
    if (result == EchoPumpInventoryAction.repair &&
        !_game.finished &&
        _game.hasFuse &&
        _game.room == PumpRoom.pump) {
      _act(_game.repair, EchoPumpCue.repair);
    }
  }

  Future<void> _inspectIncident(BuildContext incidentContext) async {
    if (_incidentOpen || _inventoryOpen) return;
    final inspectedGame = _game;
    if (identical(_inspectedIncidentGame, inspectedGame)) {
      await showDialog<void>(
        context: incidentContext,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: const Text('異常灯：確認済み'),
          content: const Text('音に反応する影。設備の音を使って誘導しよう。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('探索へ戻る'),
            ),
          ],
        ),
      );
      return;
    }
    _incidentOpen = true;
    final stopped = _audio.suspendEffects();
    bool? finished;
    try {
      finished = await showDialog<bool>(
        context: incidentContext,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.all(12),
            backgroundColor: const Color(0xFF081318),
            child: SizedBox(
              width: 800,
              height: (MediaQuery.sizeOf(dialogContext).height * 0.8)
                  .clamp(0, 620)
                  .toDouble(),
              child: FutureBuilder<void>(
                future: stopped,
                builder: (_, snapshot) => snapshot.connectionState ==
                        ConnectionState.done
                    ? EchoPumpIncident(
                        onFinished: () => Navigator.pop(dialogContext, true),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const Text('設備の音を確認中…'),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('探索へ戻る'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _incidentOpen = false;
      _audio.resumeEffects();
    }
    if (!mounted || !identical(inspectedGame, _game) || finished != true)
      return;
    setState(() => _inspectedIncidentGame = inspectedGame);
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
      data: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'NotoSansJP',
      ).copyWith(
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
            Builder(
              builder: (inventoryContext) => IconButton(
                key: const Key('echo-inventory-toolbar'),
                tooltip: '所持品を開く',
                onPressed: () => _openInventory(inventoryContext),
                icon: const Icon(Icons.inventory_2_outlined),
              ),
            ),
            IconButton(
              tooltip: '最初からやり直す',
              onPressed: () =>
                  _act(() => _game = EchoPumpGame(), EchoPumpCue.start),
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
                  EchoPumpScene(
                    game: _game,
                    onExploreMove: (room) {
                      if (_game.room == PumpRoom.control && !_game.finished) {
                        _act(() => _game.move(room), EchoPumpCue.step);
                      }
                    },
                    onFootstep: () {
                      if (_game.room == PumpRoom.control && !_game.finished) {
                        _audio.cue(EchoPumpCue.step);
                      }
                    },
                  ),
                  if (_game.room == PumpRoom.control && !_game.finished)
                    Builder(
                      builder: (incidentContext) => Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton.icon(
                          key: const Key('echo-incident-inspect'),
                          onPressed: () => _inspectIncident(incidentContext),
                          icon: Icon(
                            identical(_inspectedIncidentGame, _game)
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                          ),
                          label: Text(
                            identical(_inspectedIncidentGame, _game)
                                ? '異常灯：確認済み'
                                : '異常灯を調べる',
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (inventoryContext) => EchoPumpInventoryStrip(
                      game: _game,
                      onOpen: () => _openInventory(inventoryContext),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _game.sealed ? '敵：封鎖済み' : '敵：${_game.enemy.label}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EchoPumpProgress(game: _game),
                  const SizedBox(height: 12),
                  EchoPumpActionVisual(
                    revision: _actionRevision,
                    cue: _visualCue,
                    from: _fromRoom,
                    to: _game.room,
                    message: _game.message,
                    blocked: _blocked,
                  ),
                  ExpansionTile(
                    key: const Key('echo-details'),
                    title: const Text('詳しい目標・状況'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_game.objective),
                            const SizedBox(height: 8),
                            Text(_game.message),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_game.finished)
                    _panel(_game.escaped ? '脱出成功' : '探索失敗', [
                      Text(
                        _game.escaped
                            ? '施設の仕組みを使って、生還できた。'
                            : '敵の位置と音の行き先を確認してみよう。',
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('echo-retry'),
                        onPressed: () => _act(
                          () => _game = EchoPumpGame(),
                          EchoPumpCue.start,
                        ),
                        icon: const Icon(Icons.replay),
                        label: const Text('リトライ'),
                      ),
                    ]),
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
                        child: Text(
                          '移動・通電・作業・待機の1操作で敵が1部屋動く。'
                          '最後に入れた電源の機械音へ向かう。通電は最大2系統。'
                          'ヒューズで修理し、敵を点検槽に封鎖してから排水する。',
                        ),
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
                                : () => _act(
                                      () => _game.move(room),
                                      EchoPumpCue.step,
                                    ),
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
                                  : (_) => _act(
                                        () => _game.togglePower(circuit),
                                        EchoPumpCue.power,
                                      ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < 2; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.bolt,
                                color: i < _game.power.length
                                    ? const Color(0xFF9BE0CF)
                                    : Colors.white24,
                              ),
                            ),
                          Text('${_game.power.length} / 2'),
                        ],
                      ),
                      const ExpansionTile(
                        title: Text('電源の使い方'),
                        children: [
                          Text(
                            '3系統目を入れる前に、どれか1つを停止。'
                            '\nA：搬入ファン / B：工具棚とコンプレッサー / C：点検槽のベルと排水',
                          ),
                        ],
                      ),
                    ]),
                  if (_game.room == PumpRoom.workshop)
                    EchoPumpFuseShelf(
                      game: _game,
                      onCollect: () =>
                          _act(_game.collectFuse, EchoPumpCue.collect),
                    ),
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
                  const Text(
                    '音は下のボタンでONにできます。保存はされません。'
                    '再読み込みすると最初から始まります。',
                  ),
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
