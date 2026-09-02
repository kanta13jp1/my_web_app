// IQテスト本体の固定問題バンク。
//
// 5領域 × 5問 = 25問。各領域で難易度 1..5 を1問ずつ持たせ、
// どの領域も同じ重み構成になるようにしている (領域間比較を成立させるため)。
//
// 問題を DB でなくコードで持つ理由は models/iq_test.dart の冒頭コメント参照。

import 'dart:math' as math;

import '../models/iq_test.dart';
import 'iq_question_bank_alternates.dart';

class IqQuestionBank {
  const IqQuestionBank._();

  /// 1領域あたりの出題数。
  static const int questionsPerCategory = 5;

  /// テスト全体の制限時間。
  static const Duration timeLimit = Duration(minutes: 20);

  static int get totalQuestions =>
      IqCategory.values.length * questionsPerCategory;

  /// 全問題プール (既定フォーム + 代替フォーム)。
  static List<IqQuestion> get allQuestions =>
      List.unmodifiable([..._all, ..._alternates]);

  /// (領域, 難易度) ごとの候補。各セルに2問ずつある。
  static Map<String, List<IqQuestion>> _pool() {
    final pool = <String, List<IqQuestion>>{};
    for (final q in [..._all, ..._alternates]) {
      pool.putIfAbsent('${q.category.key}-${q.difficulty}', () => []).add(q);
    }
    return pool;
  }

  /// 標準テストの25問を返す。
  ///
  /// [seed] を渡すと **各セルからどの問題を出すかと選択肢の並びの両方** が変わる。
  /// 以前は seed が選択肢順しか変えず、再受験すると毎回まったく同じ25問が出て
  /// いた (= 練習効果でスコアが上がり、推移が能力変化を表さない)。
  /// 問題の並びは領域が偏らないようラウンドロビンで交互に出す。
  static List<IqQuestion> standardTest({int? seed}) {
    final pool = _pool();
    final random = seed == null ? null : math.Random(seed);

    // ラウンドロビン: 難易度1を全領域 → 難易度2を全領域 … と並べる。
    // 序盤で難問が固まって離脱するのを防ぐ。
    final ordered = <IqQuestion>[];
    for (var difficulty = 1; difficulty <= questionsPerCategory; difficulty++) {
      for (final category in IqCategory.values) {
        final candidates = pool['${category.key}-$difficulty'];
        if (candidates == null || candidates.isEmpty) continue;

        // seed 無しは常に先頭 (既定フォーム) = 決定的なので参照用に使える。
        final picked = random == null
            ? candidates.first
            : candidates[random.nextInt(candidates.length)];
        ordered.add(picked);
      }
    }

    if (random == null) return ordered;
    return ordered.map((q) => shuffleOptions(q, random)).toList();
  }

  /// 選択肢をシャッフルし、correctIndex を新しい位置へ張り替える。
  static IqQuestion shuffleOptions(IqQuestion question, math.Random random) {
    final indices = List<int>.generate(question.options.length, (i) => i)
      ..shuffle(random);
    final options = [for (final i in indices) question.options[i]];
    final newCorrectIndex = indices.indexOf(question.correctIndex);

    return IqQuestion(
      key: question.key,
      category: question.category,
      difficulty: question.difficulty,
      prompt: question.prompt,
      options: options,
      correctIndex: newCorrectIndex,
      explanation: question.explanation,
      memoryStimulus: question.memoryStimulus,
      revealSeconds: question.revealSeconds,
      monospacePrompt: question.monospacePrompt,
    );
  }

  /// 代替フォーム。各 (領域, 難易度) セルの2問目。
  static const List<IqQuestion> _alternates = kIqAlternateQuestions;

  static const List<IqQuestion> _all = [
    // ---------------------------------------------------------------- 論理推論
    IqQuestion(
      key: 'logic-01',
      category: IqCategory.logic,
      difficulty: 1,
      prompt: 'すべてのネコは哺乳類である。タマはネコである。\n'
          'このとき確実に言えるのはどれか。',
      options: [
        'タマは哺乳類である',
        'すべての哺乳類はネコである',
        'タマは哺乳類ではない',
        '哺乳類の多くはネコである',
      ],
      correctIndex: 0,
      explanation: '典型的な三段論法。「すべてのAはB」「xはA」から「xはB」が導かれる。'
          '逆 (すべてのBはA) は成り立たない点に注意。',
    ),
    IqQuestion(
      key: 'logic-02',
      category: IqCategory.logic,
      difficulty: 2,
      prompt: 'AはBより背が高い。CはAより背が高い。DはBより背が低い。\n'
          '最も背が高いのは誰か。',
      options: ['A', 'B', 'C', 'D'],
      correctIndex: 2,
      explanation: '不等号に直すと C > A > B > D。順序推論は数直線に置き換えると誤りが減る。',
    ),
    IqQuestion(
      key: 'logic-03',
      category: IqCategory.logic,
      difficulty: 3,
      prompt: '「雨が降れば試合は中止になる」が正しいとき、\n'
          '確実に言えるのはどれか。',
      options: [
        '試合が中止なら、雨が降った',
        '試合が中止でないなら、雨は降っていない',
        '雨が降らなければ、試合は行われる',
        '試合が行われたなら、雨が降っていた',
      ],
      correctIndex: 1,
      explanation: '確実に言えるのは対偶のみ。「雨→中止」の対偶は「中止でない→雨でない」。'
          '逆 (中止→雨) や裏 (雨でない→中止でない) は導けない。',
    ),
    IqQuestion(
      key: 'logic-04',
      category: IqCategory.logic,
      difficulty: 4,
      prompt: 'X・Y・Zの3人のうち、正直者はちょうど1人で残りは嘘つきである。\n'
          'X「Yは嘘つきだ」\n'
          'Y「Zは嘘つきだ」\n'
          'Z「XとYは2人とも嘘つきだ」\n'
          '正直者は誰か。',
      options: ['X', 'Y', 'Z', '特定できない'],
      correctIndex: 1,
      explanation: 'Xが正直→Yは嘘つき→Yの発言が偽→Zは正直となり正直者が2人で矛盾。'
          'Zが正直→XもYも嘘つき→Xの発言が偽→Yは正直となり矛盾。'
          'Yが正直の場合のみ全発言が整合する。',
    ),
    IqQuestion(
      key: 'logic-05',
      category: IqCategory.logic,
      difficulty: 5,
      prompt: '次の3つがすべて正しいとする。\n'
          '① PならばQ\n'
          '② QならばR\n'
          '③ Rではない\n'
          'このとき確実に言えるのはどれか。',
      options: [
        'Pである',
        'Qである',
        'PでもQでもない',
        'これだけでは判定できない',
      ],
      correctIndex: 2,
      explanation: '③より¬R。②の対偶 ¬R→¬Q より¬Q。①の対偶 ¬Q→¬P より¬P。'
          'よってPもQも成り立たない。対偶を2段つなぐ問題。',
    ),

    // ---------------------------------------------------------------- 数的処理
    IqQuestion(
      key: 'num-01',
      category: IqCategory.numerical,
      difficulty: 1,
      prompt: '次の数列の「?」に入る数はどれか。\n\n3, 6, 9, 12, ?',
      options: ['14', '15', '16', '18'],
      correctIndex: 1,
      explanation: '公差3の等差数列。まず隣同士の差を取るのが数列問題の第一手。',
    ),
    IqQuestion(
      key: 'num-02',
      category: IqCategory.numerical,
      difficulty: 2,
      prompt: '次の数列の「?」に入る数はどれか。\n\n1, 4, 9, 16, 25, ?',
      options: ['36', '30', '35', '49'],
      correctIndex: 0,
      explanation: '平方数の列 (1², 2², 3², …)。差を取ると 3,5,7,9 と奇数が並ぶことでも気づける。',
    ),
    IqQuestion(
      key: 'num-03',
      category: IqCategory.numerical,
      difficulty: 3,
      prompt: '次の数列の「?」に入る数はどれか。\n\n2, 3, 5, 8, 13, ?',
      options: ['18', '20', '26', '21'],
      correctIndex: 3,
      explanation: '直前2項の和 (2+3=5, 3+5=8, 5+8=13, 8+13=21)。'
          '差が一定でないときは「前の項との関係」を疑う。',
    ),
    IqQuestion(
      key: 'num-04',
      category: IqCategory.numerical,
      difficulty: 4,
      prompt: '次の数列の「?」に入る数はどれか。\n\n1, 2, 6, 24, 120, ?',
      options: ['240', '720', '600', '840'],
      correctIndex: 1,
      explanation: '掛ける数が 2, 3, 4, 5 と増える (階乗)。120 × 6 = 720。'
          '急激に増える列は差ではなく比を見る。',
    ),
    IqQuestion(
      key: 'num-05',
      category: IqCategory.numerical,
      difficulty: 5,
      prompt: '次の数列の「?」に入る数はどれか。\n\n3, 7, 16, 35, 74, ?',
      options: ['148', '151', '153', '158'],
      correctIndex: 2,
      explanation: '規則は「×2して、増える数を足す」: 3×2+1=7, 7×2+2=16, 16×2+3=35, '
          '35×2+4=74, よって 74×2+5=153。倍率と加算が同時に動く複合型。',
    ),

    // ---------------------------------------------------------------- 空間認識
    IqQuestion(
      key: 'spa-01',
      category: IqCategory.spatial,
      difficulty: 1,
      prompt: '次の図形を時計回りに90度回転させた結果はどれか。\n\n'
          '■ □\n'
          '□ □',
      monospacePrompt: true,
      options: [
        '□ ■\n□ □',
        '■ □\n□ □',
        '□ □\n■ □',
        '□ □\n□ ■',
      ],
      correctIndex: 0,
      explanation: '時計回り90度で左上は右上へ移る。基準点 (ここでは■) を1つだけ追うのがコツ。',
    ),
    IqQuestion(
      key: 'spa-02',
      category: IqCategory.spatial,
      difficulty: 2,
      prompt: '次は立方体の展開図である。面Aの向かい側にくる面はどれか。\n\n'
          '　　[A]\n'
          '[B][C][D]\n'
          '　　[E]\n'
          '　　[F]',
      monospacePrompt: true,
      options: ['B', 'C', 'E', 'F'],
      correctIndex: 2,
      explanation: '縦一列に4面 (A・C・E・F) が並ぶとき、1つ飛ばしが向かい合う。'
          'よって A↔E、C↔F。横に張り出したB↔Dも向かい合う。',
    ),
    IqQuestion(
      key: 'spa-03',
      category: IqCategory.spatial,
      difficulty: 3,
      prompt: '次のパターンの「?」に入る図形はどれか。\n\n'
          '○　◐　●\n'
          '◐　●　○\n'
          '●　○　?',
      monospacePrompt: true,
      options: ['○', '◐', '●', '□'],
      correctIndex: 1,
      explanation: '各行が ○→◐→● の並びを1つずつ左へずらした形になっている。'
          '3行目は ●→○ と来ているので次は◐。行方向と列方向の両方で確認できる。',
    ),
    IqQuestion(
      key: 'spa-04',
      category: IqCategory.spatial,
      difficulty: 4,
      prompt: '正方形の紙を縦半分に折り、さらに横半分に折った。\n'
          'その状態で重なった部分の中央に1つ穴を開けて紙を広げると、\n'
          '穴はいくつあるか。',
      options: ['2', '3', '4', '8'],
      correctIndex: 2,
      explanation: '2回折ると紙は4枚重なる。1回の穴あけが4枚すべてを貫くので穴は4つ。'
          '折り目1回につき重なりが2倍になると考える。',
    ),
    IqQuestion(
      key: 'spa-05',
      category: IqCategory.spatial,
      difficulty: 5,
      prompt: '次の図を左右反転させ、さらに時計回りに90度回転させた結果はどれか。\n\n'
          '■ □ □\n'
          '□ ■ □\n'
          '□ □ ■',
      monospacePrompt: true,
      options: [
        '■ □ □\n□ ■ □\n□ □ ■',
        '□ □ ■\n□ ■ □\n■ □ □',
        '□ ■ □\n■ □ ■\n□ ■ □',
        '■ ■ □\n□ ■ □\n□ ■ ■',
      ],
      correctIndex: 0,
      explanation: '左右反転で対角線は逆向き (右上→左下) になり、そこから時計回り90度で'
          'もとの向き (左上→右下) に戻る。反転と回転は打ち消し合うことがある。',
    ),

    // -------------------------------------------------------- ワーキングメモリ
    IqQuestion(
      key: 'mem-01',
      category: IqCategory.memory,
      difficulty: 1,
      memoryStimulus: '7　3　9　1　5',
      revealSeconds: 5,
      prompt: '先ほど表示された数字のうち、3番目の数字はどれか。',
      options: ['9', '3', '1', '5'],
      correctIndex: 0,
      explanation: '5桁程度は一塊で保持できる。声に出さず「頭の中で反復する」だけで保持率が上がる。',
    ),
    IqQuestion(
      key: 'mem-02',
      category: IqCategory.memory,
      difficulty: 2,
      memoryStimulus: 'かさ　くるま　ねこ　つくえ　ぼうし',
      revealSeconds: 6,
      prompt: '先ほど表示された単語に「含まれていなかった」ものはどれか。',
      options: ['くるま', 'ねこ', 'とけい', 'ぼうし'],
      correctIndex: 2,
      explanation: '再認課題。単語同士を1つの情景に結びつけて覚えると保持が安定する。',
    ),
    IqQuestion(
      key: 'mem-03',
      category: IqCategory.memory,
      difficulty: 3,
      memoryStimulus: '4　8　2　6　1　9　3',
      revealSeconds: 7,
      prompt: '先ほどの数字列を「逆から」読んだとき、最初の3つはどれか。',
      options: ['1 9 3', '3 1 9', '3 9 1', '9 3 1'],
      correctIndex: 2,
      explanation: '元の列は 4 8 2 6 1 9 3。逆順は 3 9 1 …。'
          '逆唱は保持しながら操作する課題で、ワーキングメモリ負荷が順唱より高い。',
    ),
    IqQuestion(
      key: 'mem-04',
      category: IqCategory.memory,
      difficulty: 4,
      memoryStimulus: '赤 → 山\n青 → 川\n緑 → 森\n黄 → 海',
      revealSeconds: 8,
      prompt: '「青」と対になっていたのはどれか。',
      options: ['山', '森', '海', '川'],
      correctIndex: 3,
      explanation: '対連合学習。「青い川」のように意味でつなぐと想起が速くなる。'
          '無関係な対ほどイメージ化が効く。',
    ),
    IqQuestion(
      key: 'mem-05',
      category: IqCategory.memory,
      difficulty: 5,
      memoryStimulus: 'A1　C3　B2　D4　A2　C1',
      revealSeconds: 9,
      prompt: '「C」で始まる組み合わせの数字を、出てきた順に並べるとどれか。',
      options: ['1 3', '3 1', '3 3', '1 1'],
      correctIndex: 1,
      explanation: 'C3 が先、C1 が後なので「3 1」。'
          '全体を覚えるのではなく、条件に合うものだけを選んで保持する「選択的更新」が要点。',
    ),

    // ---------------------------------------------------------------- 言語理解
    IqQuestion(
      key: 'ver-01',
      category: IqCategory.verbal,
      difficulty: 1,
      prompt: '「精密」に最も意味が近い語はどれか。',
      options: ['緻密', '巨大', '曖昧', '迅速'],
      correctIndex: 0,
      explanation: '「精密」も「緻密」も細部まで行き届いていることを指す。'
          '「曖昧」は対義に近い。',
    ),
    IqQuestion(
      key: 'ver-02',
      category: IqCategory.verbal,
      difficulty: 2,
      prompt: '「必然」の対義語はどれか。',
      options: ['当然', '偶然', '自然', '突然'],
      correctIndex: 1,
      explanation: '必ずそうなる「必然」に対し、たまたまそうなる「偶然」が対。'
          '字面の似た語 (当然・突然) に引かれないこと。',
    ),
    IqQuestion(
      key: 'ver-03',
      category: IqCategory.verbal,
      difficulty: 3,
      prompt: '「医者 : 病院」と同じ関係になるのはどれか。\n\n教師 : ?',
      options: ['生徒', '教科書', '学校', '授業'],
      correctIndex: 2,
      explanation: '「職業 : その職業が働く場所」の関係。'
          '類推問題はまず関係を言葉にしてから当てはめる。',
    ),
    IqQuestion(
      key: 'ver-04',
      category: IqCategory.verbal,
      difficulty: 4,
      prompt: '次のうち、他と性質が異なるものはどれか。\n\n桜 / 松 / 楓 / 銀杏',
      options: ['桜', '松', '楓', '銀杏'],
      correctIndex: 1,
      explanation: '桜・楓・銀杏は落葉樹だが、松は常緑樹。'
          '「木」という共通点で止めず、もう一段細かい軸を探すのが仲間はずれ問題。',
    ),
    IqQuestion(
      key: 'ver-05',
      category: IqCategory.verbal,
      difficulty: 5,
      prompt: '「彼は寡黙だが、いざという時には誰よりも雄弁だ」\n'
          'この文と最も近い構造を持つのはどれか。',
      options: [
        '彼は勤勉で、成績も良い',
        '彼は小柄だが、力は誰にも負けない',
        '彼は疲れたので、早く寝た',
        '彼は医者であり、作家でもある',
      ],
      correctIndex: 1,
      explanation: '「一般的な印象」と「実際の力」を逆接で対比する構造。'
          '他は並列 (1・4) と因果 (3) であり、対比になっていない。',
    ),
  ];
}
