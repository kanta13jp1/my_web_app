// トレーニング用ドリルの手続き生成。
//
// テストの領域別スコアから決まった「レベル (1..5)」を入力に、その領域の問題を
// 無限に生成する。固定問題バンクだと数回で解き尽くして練習効果しか残らないため、
// 学習側は生成方式にしている。
//
// seed を渡せば決定的に再現できる (テスト可能性のため)。

import 'dart:math' as math;

import '../models/iq_test.dart';

class IqDrillGenerator {
  const IqDrillGenerator._();

  /// 1セッションの標準問題数。
  static const int defaultSessionSize = 8;

  /// 指定領域・レベルのドリルを [count] 問生成する。
  static List<IqQuestion> generate({
    required IqCategory category,
    required int level,
    int count = defaultSessionSize,
    int? seed,
  }) {
    final random = math.Random(seed);
    final clampedLevel = level.clamp(1, 5);
    final questions = <IqQuestion>[];
    final session = _SessionDraw(random);

    for (var i = 0; i < count; i++) {
      questions.add(
        _generateOne(
          category: category,
          level: clampedLevel,
          index: i,
          random: random,
          session: session,
        ),
      );
    }
    return questions;
  }

  static IqQuestion _generateOne({
    required IqCategory category,
    required int level,
    required int index,
    required math.Random random,
    required _SessionDraw session,
  }) {
    switch (category) {
      case IqCategory.numerical:
        return _numerical(level, index, random);
      case IqCategory.logic:
        return _logic(level, index, random, session);
      case IqCategory.spatial:
        return _spatial(level, index, random);
      case IqCategory.memory:
        return _memory(level, index, random);
      case IqCategory.verbal:
        return _verbal(level, index, random, session);
    }
  }

  static String _key(IqCategory category, int level, int index) =>
      'gen-${category.key}-l$level-$index';

  // =====================================================================
  // 数的処理: 数列を規則ごと生成する
  // =====================================================================

  static IqQuestion _numerical(int level, int index, math.Random random) {
    final terms = <int>[];
    final String rule;

    switch (level) {
      case 1:
        // 等差数列 (小さい公差)
        final start = random.nextInt(9) + 1;
        final diff = random.nextInt(4) + 2;
        for (var i = 0; i < 6; i++) {
          terms.add(start + diff * i);
        }
        rule = '公差 $diff の等差数列。隣同士の差を取れば見える。';
        break;
      case 2:
        // 等差数列 (公差が大きい) か 平方数列
        if (random.nextBool()) {
          final start = random.nextInt(20) + 5;
          final diff = random.nextInt(9) + 6;
          for (var i = 0; i < 6; i++) {
            terms.add(start + diff * i);
          }
          rule = '公差 $diff の等差数列。';
        } else {
          final offset = random.nextInt(3);
          for (var i = 1; i <= 6; i++) {
            terms.add((i + offset) * (i + offset));
          }
          rule = '平方数の列。差を取ると奇数が並ぶことでも気づける。';
        }
        break;
      case 3:
        // 等比数列 または フィボナッチ型
        if (random.nextBool()) {
          final start = random.nextInt(4) + 2;
          final ratio = random.nextInt(2) + 2;
          var value = start;
          for (var i = 0; i < 6; i++) {
            terms.add(value);
            value *= ratio;
          }
          rule = '公比 $ratio の等比数列。急に増える列は差でなく比を見る。';
        } else {
          var a = random.nextInt(4) + 1;
          var b = a + random.nextInt(4) + 1;
          for (var i = 0; i < 6; i++) {
            terms.add(a);
            final next = a + b;
            a = b;
            b = next;
          }
          rule = '直前2項の和になっている (フィボナッチ型)。';
        }
        break;
      case 4:
        // 階差が等差 (二階差分が一定)
        final start = random.nextInt(6) + 1;
        final firstDiff = random.nextInt(3) + 2;
        final secondDiff = random.nextInt(3) + 1;
        var value = start;
        var diff = firstDiff;
        for (var i = 0; i < 6; i++) {
          terms.add(value);
          value += diff;
          diff += secondDiff;
        }
        rule = '差を取るとさらに $secondDiff ずつ増える (階差数列)。'
            '差が一定でないときは「差の差」を取る。';
        break;
      default:
        // 複合型: ×r して増える数を足す
        final start = random.nextInt(4) + 2;
        const ratio = 2;
        var value = start;
        var add = 1;
        for (var i = 0; i < 6; i++) {
          terms.add(value);
          value = value * ratio + add;
          add += 1;
        }
        rule = '「×$ratio して、足す数を1ずつ増やす」複合型。倍率と加算が同時に動く。';
        break;
    }

    final answer = terms.removeLast();
    final shown = terms.join(', ');
    final options = _numericOptions(answer, random);

    return IqQuestion(
      key: _key(IqCategory.numerical, level, index),
      category: IqCategory.numerical,
      difficulty: level,
      prompt: '次の数列の「?」に入る数はどれか。\n\n$shown, ?',
      options: options.map((e) => e.toString()).toList(),
      correctIndex: options.indexOf(answer),
      explanation: '正解は $answer。$rule',
    );
  }

  /// 正解に近い誤答を3つ作る。桁違いの選択肢だと消去法で当たるため近傍に置く。
  static List<int> _numericOptions(int answer, math.Random random) {
    final values = <int>{answer};
    final spread = math.max(2, (answer.abs() * 0.12).round());

    var guard = 0;
    while (values.length < 4 && guard < 60) {
      guard++;
      final delta = random.nextInt(spread * 2 + 1) - spread;
      if (delta == 0) continue;
      final candidate = answer + delta;
      if (candidate <= 0) continue;
      values.add(candidate);
    }
    // spread が小さすぎて埋まらない場合の保険。
    var fallback = 1;
    while (values.length < 4) {
      final candidate = answer + fallback;
      if (candidate > 0) values.add(candidate);
      fallback++;
    }

    final list = values.toList()..shuffle(random);
    return list;
  }

  // =====================================================================
  // 論理推論
  // =====================================================================

  static const List<List<String>> _logicCategories = [
    ['ネコ', '哺乳類', '動物'],
    ['バラ', '花', '植物'],
    ['スズメ', '鳥', '生き物'],
    ['りんご', '果物', '食べ物'],
    ['正方形', '四角形', '図形'],
    ['ピアノ', '楽器', '道具'],
    ['カブトムシ', '昆虫', '動物'],
    ['ひまわり', '植物', '生物'],
  ];

  static const List<String> _logicNames = [
    'A',
    'B',
    'C',
    'D',
    'E',
  ];

  static IqQuestion _logic(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    switch (level) {
      case 1:
        return _logicSyllogism(level, index, random, session);
      case 2:
        return _logicOrdering(level, index, random, itemCount: 3);
      case 3:
        return _logicContrapositive(level, index, random, session);
      case 4:
        return _logicOrdering(level, index, random, itemCount: 4);
      default:
        return _logicChain(level, index, random);
    }
  }

  static IqQuestion _logicSyllogism(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    final triple = _logicCategories[session.next(
      'logicCategories',
      _logicCategories.length,
    )];
    final specific = triple[0];
    final middle = triple[1];
    final broad = triple[2];
    const subject = 'X';

    final options = <String>[
      '$subject は$broadである',
      'すべての$broadは$middleである',
      '$subject は$middleではない',
      '$broadの多くは$specificである',
    ];

    return IqQuestion(
      key: _key(IqCategory.logic, level, index),
      category: IqCategory.logic,
      difficulty: level,
      prompt: 'すべての$middleは$broadである。\n'
          '$subject は$middleである。\n'
          'このとき確実に言えるのはどれか。',
      options: options,
      correctIndex: 0,
      explanation: '「すべてのAはB」「xはA」から「xはB」が導ける (三段論法)。'
          '逆向き (すべてのBはA) や量の主張は導けない。',
    );
  }

  static IqQuestion _logicOrdering(
    int level,
    int index,
    math.Random random, {
    required int itemCount,
  }) {
    // 高い順の真の並びをまず決め、そこから成り立つ関係文だけを提示する。
    final names = _logicNames.take(itemCount).toList()..shuffle(random);
    final statements = <String>[];
    for (var i = 0; i < names.length - 1; i++) {
      statements.add('${names[i]}は${names[i + 1]}より背が高い。');
    }
    statements.shuffle(random);

    final askTallest = random.nextBool();
    final answer = askTallest ? names.first : names.last;
    final options = List<String>.from(_logicNames.take(itemCount))..sort();

    return IqQuestion(
      key: _key(IqCategory.logic, level, index),
      category: IqCategory.logic,
      difficulty: level,
      prompt: '${statements.join('\n')}\n'
          '最も背が${askTallest ? '高い' : '低い'}のは誰か。',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '不等号でつなぐと ${names.join(' > ')} となる。'
          '順序推論はバラバラの関係文を1本の並びに統合してから読む。',
    );
  }

  static IqQuestion _logicContrapositive(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    const pairs = [
      ['雨が降る', '試合は中止になる'],
      ['電源が入っている', 'ランプが点く'],
      ['会員である', '割引が受けられる'],
      ['締切に間に合う', 'ボーナスが出る'],
      ['試験に合格する', '資格が取れる'],
      ['気温が下がる', '水が凍る'],
      ['鍵をかける', '安全になる'],
      ['雨が続く', '川が増水する'],
    ];
    final pair = pairs[session.next('logicConditionals', pairs.length)];
    final p = pair[0];
    final q = pair[1];

    final options = <String>[
      '$qなら、$p',
      '$qでないなら、$pでない',
      '$pでないなら、$qでない',
      '$qなら、$pでない',
    ];

    return IqQuestion(
      key: _key(IqCategory.logic, level, index),
      category: IqCategory.logic,
      difficulty: level,
      prompt: '「$pならば、$q」が正しいとき、確実に言えるのはどれか。',
      options: options,
      correctIndex: 1,
      explanation: '確実に言えるのは対偶だけ。「P→Q」の対偶は「Qでない→Pでない」。'
          '逆 (Q→P) も裏 (Pでない→Qでない) も導けない。',
    );
  }

  static IqQuestion _logicChain(int level, int index, math.Random random) {
    const symbols = ['P', 'Q', 'R', 'S'];
    final negateLast = random.nextBool();

    if (negateLast) {
      // ¬R から遡って ¬Q, ¬P を導く
      return IqQuestion(
        key: _key(IqCategory.logic, level, index),
        category: IqCategory.logic,
        difficulty: level,
        prompt: '次の3つがすべて正しいとする。\n'
            '① ${symbols[0]}ならば${symbols[1]}\n'
            '② ${symbols[1]}ならば${symbols[2]}\n'
            '③ ${symbols[2]}ではない\n'
            'このとき確実に言えるのはどれか。',
        options: [
          '${symbols[0]}である',
          '${symbols[1]}である',
          '${symbols[0]}でも${symbols[1]}でもない',
          'これだけでは判定できない',
        ],
        correctIndex: 2,
        explanation: '③より${symbols[2]}でない。②の対偶で${symbols[1]}でない。'
            '①の対偶で${symbols[0]}でない。対偶を2段つないで遡る。',
      );
    }

    // P が真から順に辿る
    return IqQuestion(
      key: _key(IqCategory.logic, level, index),
      category: IqCategory.logic,
      difficulty: level,
      prompt: '次の3つがすべて正しいとする。\n'
          '① ${symbols[0]}ならば${symbols[1]}\n'
          '② ${symbols[1]}ならば${symbols[2]}\n'
          '③ ${symbols[0]}である\n'
          'このとき確実に言えるのはどれか。',
      options: [
        '${symbols[2]}ではない',
        '${symbols[1]}も${symbols[2]}も成り立つ',
        '${symbols[1]}のみ成り立つ',
        'これだけでは判定できない',
      ],
      correctIndex: 1,
      explanation: '③と①より${symbols[1]}、さらに②より${symbols[2]}。'
          '前件が真のときは矢印を順方向に辿れる。',
    );
  }

  // =====================================================================
  // 空間認識: グリッドを生成して変換をかける
  // =====================================================================

  /// グリッド変換の種類。
  static const List<String> _transformNames = [
    'rotate90',
    'rotate180',
    'rotate270',
    'mirrorH',
    'mirrorV',
  ];

  static IqQuestion _spatial(int level, int index, math.Random random) {
    // レベルで盤面サイズと変換の複雑さを上げる。
    final size = level <= 2 ? 2 : 3;
    final filled = level <= 2 ? 1 + random.nextInt(2) : 2 + random.nextInt(2);

    // 変換候補: 低レベルは単変換、高レベルは合成変換。
    final List<String> transforms;
    final String label;
    if (level <= 2) {
      transforms = ['rotate90'];
      label = '時計回りに90度回転';
    } else if (level == 3) {
      transforms = [random.nextBool() ? 'rotate90' : 'rotate180'];
      label = transforms.first == 'rotate90' ? '時計回りに90度回転' : '180度回転';
    } else if (level == 4) {
      transforms = ['mirrorH', 'rotate90'];
      label = '左右反転させ、さらに時計回りに90度回転';
    } else {
      transforms = ['mirrorV', 'rotate90', 'rotate90'];
      label = '上下反転させ、さらに時計回りに180度回転';
    }

    // 誤答が3通り取れるグリッドが出るまで引き直す。
    // 対称なグリッドだと複数の変換結果が一致し、誤答を作れない。
    var grid = _randomGrid(size, filled, random);
    var distractors = <String>{};

    for (var attempt = 0; attempt < 40; attempt++) {
      final candidate = attempt == 0 ? grid : _randomGrid(size, filled, random);
      final correct = _renderGrid(_transformAll(candidate, transforms));

      // 誤答は「別の変換をかけた結果」= もっともらしい引っかけになる。
      final found = <String>{};
      for (final t in _transformNames) {
        final other = _renderGrid(_applyTransform(candidate, t));
        if (other != correct) found.add(other);
      }
      final original = _renderGrid(candidate);
      if (original != correct) found.add(original);

      grid = candidate;
      distractors = found;
      if (found.length >= 3) break;
    }

    final answerGrid = _renderGrid(_transformAll(grid, transforms));
    final optionGrids = _buildGridOptions(
      correct: answerGrid,
      distractors: distractors,
      size: size,
      random: random,
    );

    return IqQuestion(
      key: _key(IqCategory.spatial, level, index),
      category: IqCategory.spatial,
      difficulty: level,
      prompt: '次の図形を$labelさせた結果はどれか。\n\n${_renderGrid(grid)}',
      monospacePrompt: true,
      options: optionGrids,
      correctIndex: optionGrids.indexOf(answerGrid),
      explanation: '基準になるマスを1つだけ決めて追うと確実に解ける。'
          '全体を一度に回そうとすると誤りやすい。'
          '${transforms.length > 1 ? '合成変換は必ず指示された順に1つずつ適用する。' : ''}',
    );
  }

  static List<List<bool>> _randomGrid(
    int size,
    int filled,
    math.Random random,
  ) {
    final grid = List.generate(size, (_) => List.filled(size, false));
    final cells = <int>[];
    for (var i = 0; i < size * size; i++) {
      cells.add(i);
    }
    cells.shuffle(random);
    for (var i = 0; i < filled && i < cells.length; i++) {
      grid[cells[i] ~/ size][cells[i] % size] = true;
    }
    return grid;
  }

  static List<List<bool>> _transformAll(
    List<List<bool>> grid,
    List<String> transforms,
  ) {
    var result = grid;
    for (final t in transforms) {
      result = _applyTransform(result, t);
    }
    return result;
  }

  /// 正解 + 誤答3つ = 必ず4択を作る。
  ///
  /// 変換由来の誤答が3つに満たない場合 (対称なグリッド) は、盤面を総当たりして
  /// 補充する。選択肢が3つしかない問題を出さないための保証。
  static List<String> _buildGridOptions({
    required String correct,
    required Set<String> distractors,
    required int size,
    required math.Random random,
  }) {
    final options = <String>{correct};
    final pool = distractors.toList()..shuffle(random);
    for (final d in pool) {
      if (options.length >= 4) break;
      options.add(d);
    }

    if (options.length < 4) {
      // size は最大3なので走査は最大 512 通り。
      final cells = size * size;
      for (var mask = 0; mask < (1 << cells) && options.length < 4; mask++) {
        final candidate = List.generate(
          size,
          (r) => List.generate(size, (c) => (mask >> (r * size + c)) & 1 == 1),
        );
        options.add(_renderGrid(candidate));
      }
    }

    return options.toList()..shuffle(random);
  }

  static List<List<bool>> _applyTransform(
    List<List<bool>> grid,
    String transform,
  ) {
    switch (transform) {
      case 'rotate90':
        return _rotateCw(grid);
      case 'rotate180':
        return _rotateCw(_rotateCw(grid));
      case 'rotate270':
        return _rotateCw(_rotateCw(_rotateCw(grid)));
      case 'mirrorH':
        return grid.map((row) => row.reversed.toList()).toList();
      case 'mirrorV':
        return grid.reversed.toList();
      default:
        return grid;
    }
  }

  static List<List<bool>> _rotateCw(List<List<bool>> grid) {
    final n = grid.length;
    return List.generate(
      n,
      (r) => List.generate(n, (c) => grid[n - 1 - c][r]),
    );
  }

  static String _renderGrid(List<List<bool>> grid) {
    return grid
        .map((row) => row.map((cell) => cell ? '■' : '□').join(' '))
        .join('\n');
  }

  // =====================================================================
  // ワーキングメモリ: 数唱スパンをレベルで伸ばす
  // =====================================================================

  static IqQuestion _memory(int level, int index, math.Random random) {
    // スパン長 5..9。標準的な数唱スパン (7±2) に合わせている。
    final span = 4 + level;
    final digits = List.generate(span, (_) => random.nextInt(10));
    final stimulus = digits.join('　');
    final revealSeconds = 3 + level;

    // レベルが上がるほど「保持」から「保持しながら操作」へ移行させる。
    if (level <= 2) {
      final position = random.nextInt(span);
      final answer = digits[position];
      final options = _digitOptions(answer, digits, random);
      return IqQuestion(
        key: _key(IqCategory.memory, level, index),
        category: IqCategory.memory,
        difficulty: level,
        memoryStimulus: stimulus,
        revealSeconds: revealSeconds,
        prompt: '先ほど表示された数字のうち、${position + 1}番目はどれか。',
        options: options.map((e) => e.toString()).toList(),
        correctIndex: options.indexOf(answer),
        explanation: '正解は $answer (元の列: ${digits.join(' ')})。'
            '3〜4桁ずつのチャンクに区切って保持すると安定する。',
      );
    }

    if (level == 3) {
      final reversed = digits.reversed.toList();
      final answer = reversed.take(3).join(' ');

      // 数字が重複する列 (例: 3 3 3 …) では誤答候補が正解と一致しうる。
      // Set のまま埋めきらないと選択肢が重複し、正解が2つある問題になる。
      final optionSet = <String>{
        answer,
        digits.take(3).join(' '),
        reversed.skip(1).take(3).join(' '),
        digits.reversed.take(3).toList().reversed.join(' '),
      };
      var pad = 0;
      while (optionSet.length < 4 && pad < 30) {
        final shuffled = List<int>.from(digits)..shuffle(random);
        optionSet.add(shuffled.take(3).join(' '));
        pad++;
      }
      // シャッフルでも埋まらない場合 (数字が全て同一など) の確実な補充。
      var filler = 0;
      while (optionSet.length < 4) {
        optionSet.add(
          List<int>.generate(3, (i) => (filler + i) % 10).join(' '),
        );
        filler++;
      }

      final options = optionSet.toList()..shuffle(random);
      return IqQuestion(
        key: _key(IqCategory.memory, level, index),
        category: IqCategory.memory,
        difficulty: level,
        memoryStimulus: stimulus,
        revealSeconds: revealSeconds,
        prompt: '先ほどの数字列を「逆から」読んだとき、最初の3つはどれか。',
        options: options,
        correctIndex: options.indexOf(answer),
        explanation: '元の列は ${digits.join(' ')}。逆順の先頭3つは $answer。'
            '逆唱は保持しながら操作する課題で負荷が高い。',
      );
    }

    if (level == 4) {
      final answer = digits.reduce((a, b) => a + b);
      final options = _numericOptions(answer, random);
      return IqQuestion(
        key: _key(IqCategory.memory, level, index),
        category: IqCategory.memory,
        difficulty: level,
        memoryStimulus: stimulus,
        revealSeconds: revealSeconds,
        prompt: '先ほど表示された数字をすべて足すといくつか。',
        options: options.map((e) => e.toString()).toList(),
        correctIndex: options.indexOf(answer),
        explanation: '元の列は ${digits.join(' ')}、合計は $answer。'
            '全部覚えてから足すより、表示中に足しながら1つの数だけ保持するほうが楽になる。',
      );
    }

    // レベル5: 条件に合うものだけを選んで保持する (選択的更新)
    final evens = digits.where((d) => d.isEven).toList();
    final answer = evens.isEmpty ? 0 : evens.length;
    final options = <int>{answer, answer + 1, answer + 2}.toList();
    if (answer > 0) options.add(answer - 1);
    var filler = 3;
    while (options.length < 4) {
      options.add(answer + filler);
      filler++;
    }
    options.shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.memory, level, index),
      category: IqCategory.memory,
      difficulty: level,
      memoryStimulus: stimulus,
      revealSeconds: revealSeconds,
      prompt: '先ほど表示された数字のうち、偶数 (0を含む) はいくつあったか。',
      options: options.map((e) => e.toString()).toList(),
      correctIndex: options.indexOf(answer),
      explanation: '元の列は ${digits.join(' ')}、偶数は $answer 個。'
          '列全体を覚えるのではなく、条件に合う数だけカウンタとして保持するのが要点。',
    );
  }

  static List<int> _digitOptions(
    int answer,
    List<int> digits,
    math.Random random,
  ) {
    final values = <int>{answer};
    for (final d in digits) {
      if (values.length >= 4) break;
      values.add(d);
    }
    // 乱数任せだと理論上 4 個に届かないことがあるため、0..9 の総当たりで確実に埋める。
    for (var d = 0; d < 10 && values.length < 4; d++) {
      values.add(d);
    }
    return values.toList()..shuffle(random);
  }

  // =====================================================================
  // 言語理解: 関係プールから出題する
  // =====================================================================

  /// [語, 正解, 誤答1, 誤答2, 誤答3]
  static const List<List<String>> _synonymPool = [
    ['巨大', '膨大', '微小', '希薄', '柔軟'],
    ['迅速', '敏速', '緩慢', '丁寧', '正確'],
    ['明白', '明瞭', '曖昧', '複雑', '重大'],
    ['困難', '難儀', '容易', '単純', '快適'],
    ['精密', '緻密', '粗雑', '曖昧', '軽率'],
    ['寛容', '寛大', '厳格', '冷淡', '慎重'],
    ['顕著', '著しい', '些細', '平凡', '穏やか'],
    ['堅実', '着実', '軽率', '華美', '奇抜'],
  ];

  static const List<List<String>> _antonymPool = [
    ['必然', '偶然', '当然', '自然', '突然'],
    ['需要', '供給', '要求', '消費', '生産'],
    ['楽観', '悲観', '達観', '静観', '傍観'],
    ['具体', '抽象', '実体', '具現', '個別'],
    ['集中', '分散', '凝縮', '密集', '専念'],
    ['促進', '抑制', '推進', '助長', '加速'],
    ['拡大', '縮小', '拡張', '増大', '巨大'],
    ['原因', '結果', '要因', '起因', '動機'],
  ];

  /// [A, B, C, 正解, 誤答1, 誤答2, 誤答3, 関係の説明]
  static const List<List<String>> _analogyPool = [
    ['医者', '病院', '教師', '学校', '生徒', '教科書', '授業', '職業とその職業が働く場所'],
    ['鳥', '翼', '魚', 'ひれ', '水', 'うろこ', '泳ぐ', '生き物とその移動器官'],
    ['本', 'ページ', '木', '葉', '森', '幹', '根', '全体とそれを構成する部分'],
    ['寒い', '暖房', '暗い', '照明', '電気', '夜', '眠気', '状態とそれを解消する手段'],
    ['種', '花', '卵', 'ひな', '鳥', '巣', '殻', '初期状態とそこから育つもの'],
    ['温度計', '温度', '時計', '時刻', '針', '数字', '時間割', '計測器とそれが測る量'],
    ['画家', '絵筆', '大工', 'のこぎり', '木材', '家', '設計図', '職業とその職業が使う道具'],
    ['雨', '傘', '日差し', '帽子', '夏', '日焼け', '雲', '事象とそれを防ぐ道具'],
  ];

  /// [仲間はずれ, 同種1, 同種2, 同種3, 理由]
  static const List<List<String>> _oddOneOutPool = [
    ['松', '桜', '楓', '銀杏', '松だけが常緑樹で、他は落葉樹'],
    ['クジラ', 'サメ', 'マグロ', 'サバ', 'クジラだけが哺乳類で、他は魚類'],
    ['トマト', 'にんじん', 'だいこん', 'ごぼう', 'トマトだけが果菜で、他は根菜'],
    ['銅', '木材', '鉄', 'アルミ', '木材だけが金属でない'],
    ['ピアノ', 'バイオリン', 'チェロ', 'ギター', 'ピアノだけが弦を指で弾かない (打弦楽器)'],
    ['コウモリ', 'ワシ', 'ハト', 'ツバメ', 'コウモリだけが哺乳類で、他は鳥類'],
    ['砂', '金', '銀', '銅', '砂だけが金属でない'],
    ['トランペット', 'バイオリン', 'チェロ', 'ビオラ', 'トランペットだけが金管楽器で、他は弦楽器'],
  ];

  static IqQuestion _verbal(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    switch (level) {
      case 1:
        return _verbalSynonym(
          level,
          index,
          random,
          session,
          pool: _synonymPool,
        );
      case 2:
        return _verbalAntonym(level, index, random, session);
      case 3:
        return _verbalAnalogy(level, index, random, session);
      case 4:
        return _verbalOddOneOut(level, index, random, session);
      default:
        // レベル5は「文の構造どうしを対応させる」課題。
        // 以前は L3/L4 の生成器を混ぜていただけで、difficulty ラベルが 5 に
        // なるだけで実際には難しくなっていなかった (第3ラウンド T3 で実測)。
        return _verbalSentenceRelation(level, index, random, session);
    }
  }

  /// [文, 構造, 同構造の文, 別構造1, 別構造2, 別構造3]
  ///
  /// L5 専用。語と語ではなく **文と文の論理構造** を対応させる課題で、
  /// L3 (類推) / L4 (仲間はずれ) より一段抽象度が高い。
  static const List<List<String>> _sentenceRelationPool = [
    [
      '彼は寡黙だが、いざという時には誰よりも雄弁だ',
      '逆接による対比',
      '彼は小柄だが、力は誰にも負けない',
      '彼は勤勉で、成績も良い',
      '彼は疲れたので、早く寝た',
      '彼は医者であり、作家でもある',
    ],
    [
      '雨が降ったので、試合は中止になった',
      '原因と結果',
      '寝坊したので、電車に乗り遅れた',
      '彼は静かだが、芯は強い',
      '彼は教師でもあり、詩人でもある',
      '早く行けば、席が取れる',
    ],
    [
      '練習を続ければ、必ず上達する',
      '条件と帰結',
      '早起きすれば、朝日が見られる',
      '彼女は優しく、そして厳しい',
      '道が混んだので、遅刻した',
      '彼は無口だが、よく笑う',
    ],
    [
      '彼女は歌も上手いし、踊りも上手い',
      '並列の列挙',
      'この店は安いし、味も良い',
      '彼は若いが、経験は豊富だ',
      '風が強いので、電車が止まった',
      '準備すれば、失敗は減る',
    ],
    [
      '小さな店だが、味は一流だ',
      '逆接による対比',
      '古い家だが、住み心地は良い',
      '雪が降ったので、道が凍った',
      '彼は速く走り、高く跳ぶ',
      '練習すれば、上達する',
    ],
    [
      '道が凍ったので、転んでしまった',
      '原因と結果',
      '風邪をひいたので、仕事を休んだ',
      '安いけれど、質は高い',
      '彼は歌い、そして踊る',
      '走れば、間に合う',
    ],
    [
      'よく眠れば、頭が冴える',
      '条件と帰結',
      '毎日書けば、文章は上達する',
      '彼は寡黙だが、優しい',
      '雨なので、試合は中止だ',
      '彼は速く、そして正確だ',
    ],
    [
      'この本は面白いし、ためになる',
      '並列の列挙',
      'あの人は明るいし、頼りになる',
      '静かだが、存在感がある',
      '遅れたので、謝った',
      '努力すれば、報われる',
    ],
  ];

  static IqQuestion _verbalSentenceRelation(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    final row = _sentenceRelationPool[session.next(
      'sentenceRelation',
      _sentenceRelationPool.length,
    )];
    final source = row[0];
    final relation = row[1];
    final answer = row[2];
    final options = row.sublist(2).toList()..shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.verbal, level, index),
      category: IqCategory.verbal,
      difficulty: level,
      prompt: '「$source」\nこの文と最も近い構造を持つのはどれか。',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '元の文の構造は「$relation」。正解は「$answer」。'
          '語の意味ではなく、節と節のつながり方を見る。',
    );
  }

  static IqQuestion _verbalSynonym(
    int level,
    int index,
    math.Random random,
    _SessionDraw session, {
    required List<List<String>> pool,
  }) {
    final row = pool[session.next('synonym', pool.length)];
    final word = row[0];
    final answer = row[1];
    final options = row.sublist(1).toList()..shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.verbal, level, index),
      category: IqCategory.verbal,
      difficulty: level,
      prompt: '「$word」に最も意味が近い語はどれか。',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '正解は「$answer」。字面の似た語ではなく、'
          '置き換えて文が成り立つかで判断する。',
    );
  }

  static IqQuestion _verbalAntonym(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    final row = _antonymPool[session.next('antonym', _antonymPool.length)];
    final word = row[0];
    final answer = row[1];
    final options = row.sublist(1).toList()..shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.verbal, level, index),
      category: IqCategory.verbal,
      difficulty: level,
      prompt: '「$word」の対義語はどれか。',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '正解は「$answer」。誤答は同じ漢字を含むだけの語や、'
          '意味が近い語が並んでいる。軸 (何の反対か) を先に決めるとぶれない。',
    );
  }

  static IqQuestion _verbalAnalogy(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    final row = _analogyPool[session.next('analogy', _analogyPool.length)];
    final a = row[0];
    final b = row[1];
    final c = row[2];
    final answer = row[3];
    final relation = row[7];
    final options = [row[3], row[4], row[5], row[6]]..shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.verbal, level, index),
      category: IqCategory.verbal,
      difficulty: level,
      prompt: '「$a : $b」と同じ関係になるのはどれか。\n\n$c : ?',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '関係は「$relation」。正解は「$answer」。'
          '類推はまず関係を言葉にしてから当てはめる。',
    );
  }

  static IqQuestion _verbalOddOneOut(
    int level,
    int index,
    math.Random random,
    _SessionDraw session,
  ) {
    final row =
        _oddOneOutPool[session.next('oddOneOut', _oddOneOutPool.length)];
    final answer = row[0];
    final reason = row[4];
    final options = row.sublist(0, 4).toList()..shuffle(random);

    return IqQuestion(
      key: _key(IqCategory.verbal, level, index),
      category: IqCategory.verbal,
      difficulty: level,
      prompt: '次のうち、他と性質が異なるものはどれか。\n\n${options.join(' / ')}',
      options: options,
      correctIndex: options.indexOf(answer),
      explanation: '正解は「$answer」。$reason。'
          '共通点で止めず、もう一段細かい軸を探すのが仲間はずれ問題のコツ。',
    );
  }
}

/// 1セッション内で同じ出題プール行を使い回さないための抽選器。
///
/// 出題プールは 5〜8 行しかないのに 1 セッションは 8 問あるため、
/// 毎回 `random.nextInt(pool.length)` を引くと同一セッション内で同じ問題が
/// 何度も出る (実測: 語彙L1 は 30/30 セッションで重複し、最大 4 問が重複)。
/// 同じ問題を続けて解かされるのは学習としても測定としても無意味なので、
/// プールごとに順列を作って先頭から配り、尽きたら並べ替えて配り直す。
class _SessionDraw {
  final math.Random _random;

  /// プール識別子 -> まだ配っていない添字の並び。
  final Map<String, List<int>> _remaining = {};

  _SessionDraw(this._random);

  /// [poolSize] 件のプールから、セッション内で重複しない添字を1つ返す。
  ///
  /// プールを配り切った場合のみ最初から配り直す (8問 > プール件数のとき)。
  int next(String poolId, int poolSize) {
    if (poolSize <= 0) return 0;

    var queue = _remaining[poolId];
    if (queue == null || queue.isEmpty) {
      queue = List<int>.generate(poolSize, (i) => i)..shuffle(_random);
      _remaining[poolId] = queue;
    }
    return queue.removeLast();
  }
}
