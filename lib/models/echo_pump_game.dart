enum PumpRoom {
  control('管理室', '安全な拠点・配電盤'),
  hall('中央廊下', '各区画への分岐'),
  loading('搬入区画', 'A系統・換気ファン'),
  workshop('工具庫', 'B系統・交換ヒューズ'),
  pump('ポンプ室', '修理・隔壁・排水'),
  inspection('点検槽', 'C系統・試運転ベル'),
  exit('出口', '排水後に脱出できる');

  const PumpRoom(this.label, this.description);
  final String label;
  final String description;
}

enum PumpCircuit {
  a('A 搬入', PumpRoom.loading),
  b('B 整備', PumpRoom.workshop),
  c('C 排水', PumpRoom.inspection);

  const PumpCircuit(this.label, this.noiseRoom);
  final String label;
  final PumpRoom noiseRoom;
}

/// Deterministic, turn-based rules. No timers, network or persistence.
class EchoPumpGame {
  static const connections = <PumpRoom, List<PumpRoom>>{
    PumpRoom.control: [PumpRoom.hall, PumpRoom.exit],
    PumpRoom.hall: [
      PumpRoom.control,
      PumpRoom.loading,
      PumpRoom.workshop,
      PumpRoom.pump,
    ],
    PumpRoom.loading: [PumpRoom.hall],
    PumpRoom.workshop: [PumpRoom.hall],
    PumpRoom.pump: [PumpRoom.hall, PumpRoom.inspection],
    PumpRoom.inspection: [PumpRoom.pump],
    PumpRoom.exit: [PumpRoom.control],
  };

  PumpRoom _room = PumpRoom.control;
  PumpRoom _enemy = PumpRoom.pump;
  final Set<PumpCircuit> _power = {};
  PumpCircuit? _lastNoise;
  int _health = 3;
  int _turn = 0;
  bool _fuse = false;
  bool _repaired = false;
  bool _sealed = false;
  bool _drained = false;
  bool _escaped = false;
  String _message = '管理室から探索開始。B系統を入れ、工具庫のヒューズを探そう。';

  PumpRoom get room => _room;
  PumpRoom get enemy => _enemy;
  Set<PumpCircuit> get power => Set.unmodifiable(_power);
  PumpRoom? get noiseRoom => _lastNoise?.noiseRoom;
  int get health => _health;
  int get turn => _turn;
  bool get hasFuse => _fuse;
  bool get repaired => _repaired;
  bool get sealed => _sealed;
  bool get drained => _drained;
  bool get escaped => _escaped;
  bool get finished => _escaped || _health == 0;
  String get message => _message;
  List<PumpRoom> get destinations => connections[_room]!;

  String get objective {
    if (_escaped) {
      return '脱出成功。雨の向こうに、朝の光が見える。';
    }
    if (_health == 0) {
      return '探索失敗。もう一度、電源と敵の位置を確かめよう。';
    }
    if (_drained) {
      return '管理室から出口へ戻り、脱出する。';
    }
    if (_sealed && _repaired) {
      return 'C系統を入れた状態でポンプ室から排水する。';
    }
    if (_repaired) {
      return 'C系統のベルで敵を点検槽へ誘い、ポンプ室で隔壁を閉じる。';
    }
    if (_fuse) {
      return 'ポンプ室でヒューズを取り付ける。';
    }
    return 'B系統を通電し、工具庫で交換ヒューズを回収する。';
  }

  void togglePower(PumpCircuit circuit) {
    if (finished) {
      return;
    }
    if (_room != PumpRoom.control) {
      _message = '配電盤は管理室にある。';
      return;
    }
    if (_power.contains(circuit)) {
      _power.remove(circuit);
      if (_lastNoise == circuit) {
        _lastNoise = _power.isEmpty ? null : _power.last;
      }
      _message = '${circuit.label}を停止した。';
    } else {
      if (_power.length == 2) {
        _message = '通電は最大2系統。先に別の系統を停止しよう。';
        return;
      }
      _power.add(circuit);
      _lastNoise = circuit;
      _message = '${circuit.label}が稼働。敵は${circuit.noiseRoom.label}の音へ向かう。';
    }
    _advance();
  }

  void move(PumpRoom destination) {
    if (finished) {
      return;
    }
    if (!destinations.contains(destination)) {
      _message = '隣接する部屋だけ移動できる。';
      return;
    }
    if (destination == PumpRoom.inspection && _sealed) {
      _message = '隔壁は閉鎖済み。点検槽には入れない。';
      return;
    }
    if (destination == PumpRoom.exit && !_drained) {
      _message = '出口は冠水している。先に排水が必要だ。';
      return;
    }
    _room = destination;
    _message = '${destination.label}へ移動した。';
    if (!_sealed && _room == _enemy) {
      _turn++;
      _hit();
      return;
    }
    if (_room == PumpRoom.exit) {
      _escaped = true;
      _turn++;
      _message = '脱出成功！ ポンプの音だけが、建物に残った。';
      return;
    }
    _advance();
  }

  void collectFuse() {
    if (finished) {
      return;
    }
    if (_room != PumpRoom.workshop || _fuse || _repaired) {
      _message = '回収できるヒューズはここにはない。';
      return;
    }
    if (!_power.contains(PumpCircuit.b)) {
      _message = '工具棚が開かない。管理室でB系統を入れよう。';
      return;
    }
    _fuse = true;
    _message = '交換ヒューズを回収。ポンプ室へ運ぼう。';
    _advance();
  }

  void repair() {
    if (finished) {
      return;
    }
    if (_room != PumpRoom.pump || !_fuse || _repaired) {
      _message = 'ポンプ室で交換ヒューズを取り付けよう。';
      return;
    }
    _fuse = false;
    _repaired = true;
    _message = '制御盤を修理した。次は敵を点検槽へ誘導しよう。';
    _advance();
  }

  void seal() {
    if (finished) {
      return;
    }
    if (_room != PumpRoom.pump ||
        _enemy != PumpRoom.inspection ||
        !_power.contains(PumpCircuit.c) ||
        _sealed) {
      _message = 'C系統で敵を点検槽へ誘い、ポンプ室から隔壁を閉じよう。';
      return;
    }
    _sealed = true;
    _message = '隔壁を閉鎖！ 敵を点検槽に封じ込めた。';
    _advance();
  }

  void drain() {
    if (finished) {
      return;
    }
    if (_room != PumpRoom.pump ||
        !_repaired ||
        !_sealed ||
        !_power.contains(PumpCircuit.c) ||
        _drained) {
      _message = '排水には修理・隔壁閉鎖・C系統の通電が必要だ。';
      return;
    }
    _drained = true;
    _message = '排水完了。管理室から出口へ戻ろう。';
    _advance();
  }

  void wait() {
    if (finished) {
      return;
    }
    _message = '耳を澄ませた。機械音に応じて敵が動く。';
    _advance();
  }

  void _advance() {
    _turn++;
    if (_sealed) {
      return;
    }
    final target = noiseRoom;
    if (target != null && _enemy != target) {
      final paths = <List<PumpRoom>>[
        [_enemy]
      ];
      final visited = <PumpRoom>{_enemy};
      while (paths.isNotEmpty) {
        final path = paths.removeAt(0);
        if (path.last == target) {
          _enemy = path[1];
          break;
        }
        for (final next in connections[path.last]!) {
          if (next == PumpRoom.control ||
              next == PumpRoom.exit ||
              !visited.add(next)) {
            continue;
          }
          paths.add([...path, next]);
        }
      }
    }
    if (_room == _enemy) {
      _hit();
    }
  }

  void _hit() {
    _health--;
    _room = PumpRoom.control;
    _message = _health == 0
        ? '探索失敗。リトライで最初からやり直せる。'
        : '敵と接触！ 体力を1失い、管理室へ退避した。回収・修理は保持される。';
  }
}
