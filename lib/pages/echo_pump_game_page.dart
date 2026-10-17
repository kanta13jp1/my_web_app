import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';

class EchoPumpGamePage extends StatefulWidget {
  const EchoPumpGamePage({super.key});

  @override
  State<EchoPumpGamePage> createState() => _EchoPumpGamePageState();
}

class _EchoPumpGamePageState extends State<EchoPumpGamePage> {
  EchoPumpGame _game = EchoPumpGame();

  void _act(VoidCallback action) => setState(action);

  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _act(() => _game = EchoPumpGame()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '夜間排水施設 / 見取り図プロトタイプ',
                    style: TextStyle(color: Color(0xFF8FE3D0)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '電源を選び、音で誘い、生きて帰る。',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '豪雨で出口が冠水した。ヒューズを回収してポンプを修理し、'
                    '敵を点検槽に閉じ込めて排水しよう。'
                    '\n移動・通電・作業・待機の1操作で敵が1部屋動く。'
                    '最後に入れた電源の機械音へ向かう。管理室は安全。',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('体力 ${_game.health} / 3')),
                      Chip(label: Text('ターン ${_game.turn}')),
                      Chip(label: Text('現在地 ${_game.room.label}')),
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
                          onPressed: () => _act(() => _game = EchoPumpGame()),
                          icon: const Icon(Icons.replay),
                          label: const Text('リトライ'),
                        ),
                      ],
                    ),
                  _panel('施設の見取り図', [
                    const Text('線の代わりに接続先を各区画に表示。隣の部屋は下の移動ボタンから選べる。'),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 600 ? 3 : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 8) /
                                columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final room in PumpRoom.values)
                              SizedBox(width: width, child: _roomCard(room)),
                          ],
                        );
                      },
                    ),
                  ]),
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
                                : () => _act(() => _game.move(room)),
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
                                      _act(() => _game.togglePower(circuit)),
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
                                : () => _act(_game.collectFuse),
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
                                : () => _act(_game.repair),
                            child: const Text('ヒューズで修理'),
                          ),
                          FilledButton(
                            key: const Key('echo-seal'),
                            onPressed: _game.finished ||
                                    _game.sealed ||
                                    _game.enemy != PumpRoom.inspection ||
                                    !_game.power.contains(PumpCircuit.c)
                                ? null
                                : () => _act(_game.seal),
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
                                : () => _act(_game.drain),
                            child: const Text('排水ポンプを起動'),
                          ),
                        ],
                      ),
                    ]),
                  const SizedBox(height: 12),
                  const Text('最小版：音は表示で表現 / 3D・射撃・音声・保存なし。'
                      '再読込で最初から。敵の位置は全表示。'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomCard(PumpRoom room) {
    final current = room == _game.room;
    final enemy = room == _game.enemy;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF234F48) : const Color(0xFF233038),
        border: Border.all(
          color: enemy && !_game.sealed
              ? const Color(0xFFFFAA91)
              : const Color(0xFF55706C),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(room.label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (current) const Text('● あなた'),
          if (enemy) Text(_game.sealed ? '■ 敵・隔壁閉鎖' : '▲ 敵'),
          Text(room.description),
          const SizedBox(height: 4),
          Text(
            '接続：${EchoPumpGame.connections[room]!.map((r) => r.label).join('・')}',
          ),
        ],
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
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
