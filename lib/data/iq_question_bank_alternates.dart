// 代替フォームの25問 (5領域 × 難易度1..5)。
//
// 仮説検証 H1 への対応: 既定フォームだけだと再受験で毎回まったく同じ25問が出て、
// 練習効果でスコアが上がる。推移グラフが能力変化を表さなくなるため、
// 各 (領域, 難易度) セルに 2 問目を用意し seed で選ばせる。
//
// 難易度は既定フォームの同セルと揃えてある (重み構成が変わると領域間比較が崩れる)。

import '../models/iq_test.dart';

/// 代替フォーム。キーは既定フォームと衝突しないよう `-b` を付ける。
const List<IqQuestion> kIqAlternateQuestions = [
  // ---------------------------------------------------------------- 論理推論
  IqQuestion(
    key: 'logic-01b',
    category: IqCategory.logic,
    difficulty: 1,
    prompt: 'すべての鳥は卵を生む。ハトは鳥である。\n'
        'このとき確実に言えるのはどれか。',
    options: [
      'ハトは卵を生む',
      '卵を生むものはすべて鳥である',
      'ハトは卵を生まない',
      '鳥の多くはハトである',
    ],
    correctIndex: 0,
    explanation: '三段論法。「すべてのAはB」「xはA」から「xはB」。'
        '逆 (卵を生む→鳥) は成り立たない。',
  ),
  IqQuestion(
    key: 'logic-02b',
    category: IqCategory.logic,
    difficulty: 2,
    prompt: 'PはQより速い。RはPより速い。SはQより遅い。\n'
        '最も速いのは誰か。',
    options: ['P', 'Q', 'R', 'S'],
    correctIndex: 2,
    explanation: '不等号でつなぐと R > P > Q > S。'
        'バラバラの関係文を1本の並びに統合してから読む。',
  ),
  IqQuestion(
    key: 'logic-03b',
    category: IqCategory.logic,
    difficulty: 3,
    prompt: '「準備をすれば合格する」が正しいとき、\n'
        '確実に言えるのはどれか。',
    options: [
      '合格したなら、準備をした',
      '合格しなかったなら、準備をしていない',
      '準備をしなければ、合格しない',
      '合格したなら、準備をしていない',
    ],
    correctIndex: 1,
    explanation: '確実に言えるのは対偶のみ。「準備→合格」の対偶は'
        '「合格でない→準備でない」。逆も裏も導けない。',
  ),
  IqQuestion(
    key: 'logic-04b',
    category: IqCategory.logic,
    difficulty: 4,
    prompt: 'A・B・Cの3人のうち、嘘つきはちょうど1人である。\n'
        'A「Bは正直者だ」\n'
        'B「Cは嘘つきだ」\n'
        'C「私は正直者だ」\n'
        '嘘つきは誰か。',
    options: ['A', 'B', 'C', '特定できない'],
    correctIndex: 2,
    explanation: 'Aが嘘つき→Bも嘘つきとなり2人で矛盾。'
        'Bが嘘つき→Cは正直、Aは正直なのでBは正直となり矛盾。'
        'Cが嘘つきのときだけ全発言が整合する。',
  ),
  IqQuestion(
    key: 'logic-05b',
    category: IqCategory.logic,
    difficulty: 5,
    prompt: '次の3つがすべて正しいとする。\n'
        '① AならばB\n'
        '② BでないならばC\n'
        '③ Cではない\n'
        'このとき確実に言えるのはどれか。',
    options: [
      'Aである',
      'Bである',
      'AでもBでもない',
      'これだけでは判定できない',
    ],
    correctIndex: 1,
    explanation: '③よりCでない。②の対偶「CでないならばB」よりBが成り立つ。'
        '①はAについて何も決めないので、Aは不明のまま。'
        '「全部決まる」と思い込まないことが要点。',
  ),

  // ---------------------------------------------------------------- 数的処理
  IqQuestion(
    key: 'num-01b',
    category: IqCategory.numerical,
    difficulty: 1,
    prompt: '次の数列の「?」に入る数はどれか。\n\n5, 10, 15, 20, ?',
    options: ['22', '25', '30', '24'],
    correctIndex: 1,
    explanation: '公差5の等差数列。まず隣同士の差を取る。',
  ),
  IqQuestion(
    key: 'num-02b',
    category: IqCategory.numerical,
    difficulty: 2,
    prompt: '次の数列の「?」に入る数はどれか。\n\n1, 8, 27, 64, ?',
    options: ['100', '121', '125', '144'],
    correctIndex: 2,
    explanation: '立方数の列 (1³, 2³, 3³, 4³, 5³)。'
        '増え方が急なら累乗を疑う。',
  ),
  IqQuestion(
    key: 'num-03b',
    category: IqCategory.numerical,
    difficulty: 3,
    prompt: '次の数列の「?」に入る数はどれか。\n\n1, 3, 4, 7, 11, ?',
    options: ['15', '16', '18', '22'],
    correctIndex: 2,
    explanation: '直前2項の和 (1+3=4, 3+4=7, 4+7=11, 7+11=18)。'
        '差が一定でないときは前の項との関係を疑う。',
  ),
  IqQuestion(
    key: 'num-04b',
    category: IqCategory.numerical,
    difficulty: 4,
    prompt: '次の数列の「?」に入る数はどれか。\n\n2, 6, 12, 20, 30, ?',
    options: ['40', '42', '44', '36'],
    correctIndex: 1,
    explanation: '差が 4, 6, 8, 10 と2ずつ増える階差数列。次の差は12で 30+12=42。'
        'n×(n+1) の形 (1·2, 2·3, 3·4 …) と見ても同じ。',
  ),
  IqQuestion(
    key: 'num-05b',
    category: IqCategory.numerical,
    difficulty: 5,
    prompt: '次の数列の「?」に入る数はどれか。\n\n1, 2, 5, 14, 41, ?',
    options: ['118', '120', '122', '125'],
    correctIndex: 2,
    explanation: '規則は「×3して1を引く」: 1×3-1=2, 2×3-1=5, 5×3-1=14, '
        '14×3-1=41、よって 41×3-1=122。倍率と加減が同時に動く複合型。',
  ),

  // ---------------------------------------------------------------- 空間認識
  IqQuestion(
    key: 'spa-01b',
    category: IqCategory.spatial,
    difficulty: 1,
    prompt: '次の図形を時計回りに90度回転させた結果はどれか。\n\n'
        '□ ■\n'
        '□ □',
    monospacePrompt: true,
    options: [
      '□ □\n□ ■',
      '■ □\n□ □',
      '□ ■\n□ □',
      '□ □\n■ □',
    ],
    correctIndex: 0,
    explanation: '時計回り90度で右上は右下へ移る。'
        '基準点 (■) を1つだけ追うのがコツ。',
  ),
  IqQuestion(
    key: 'spa-02b',
    category: IqCategory.spatial,
    difficulty: 2,
    prompt: '次は立方体の展開図である。面Cの向かい側にくる面はどれか。\n\n'
        '　　[A]\n'
        '[B][C][D]\n'
        '　　[E]\n'
        '　　[F]',
    monospacePrompt: true,
    options: ['A', 'B', 'E', 'F'],
    correctIndex: 3,
    explanation: '縦一列に4面 (A・C・E・F) が並ぶとき、1つ飛ばしが向かい合う。'
        'よって A↔E、C↔F。',
  ),
  IqQuestion(
    key: 'spa-03b',
    category: IqCategory.spatial,
    difficulty: 3,
    prompt: '次のパターンの「?」に入る図形はどれか。\n\n'
        '●　○　◐\n'
        '○　◐　●\n'
        '◐　●　?',
    monospacePrompt: true,
    options: ['●', '○', '◐', '□'],
    correctIndex: 1,
    explanation: '各行が1つずつ左へずれている。'
        '3行目は ◐→● と来ているので次は○。列方向で見ても同じ並びになる。',
  ),
  IqQuestion(
    key: 'spa-04b',
    category: IqCategory.spatial,
    difficulty: 4,
    prompt: '正方形の紙を対角線で半分に折り、さらにもう一度半分に折った。\n'
        'その状態で1つ穴を開けて紙を広げると、穴はいくつあるか。',
    options: ['2', '3', '4', '8'],
    correctIndex: 2,
    explanation: '2回折ると紙は4枚重なる。1回の穴あけが4枚を貫くので穴は4つ。'
        '折り目1回につき重なりが2倍になる。',
  ),
  IqQuestion(
    key: 'spa-05b',
    category: IqCategory.spatial,
    difficulty: 5,
    prompt: '次の図を上下反転させ、さらに時計回りに90度回転させた結果はどれか。\n\n'
        '■ □ □\n'
        '■ □ □\n'
        '■ ■ ■',
    monospacePrompt: true,
    options: [
      '■ ■ ■\n□ □ ■\n□ □ ■',
      '■ □ □\n■ □ □\n■ ■ ■',
      '□ □ ■\n□ □ ■\n■ ■ ■',
      '■ ■ ■\n■ □ □\n■ □ □',
    ],
    correctIndex: 0,
    explanation: '上下反転で L 字が上下逆になり、時計回り90度で横棒が上へ来る。'
        '合成変換は必ず指示された順に1つずつ適用する。',
  ),

  // -------------------------------------------------------- ワーキングメモリ
  IqQuestion(
    key: 'mem-01b',
    category: IqCategory.memory,
    difficulty: 1,
    memoryStimulus: '4　8　2　7　5',
    revealSeconds: 5,
    prompt: '先ほど表示された数字のうち、最後の数字はどれか。',
    options: ['4', '7', '5', '2'],
    correctIndex: 2,
    explanation: '末尾は直前に見た分なので保持しやすい (新近効果)。'
        '中央付近がいちばん落ちやすい。',
  ),
  IqQuestion(
    key: 'mem-02b',
    category: IqCategory.memory,
    difficulty: 2,
    memoryStimulus: 'そら　うみ　やま　かわ　もり',
    revealSeconds: 6,
    prompt: '先ほど表示された単語に「含まれていなかった」ものはどれか。',
    options: ['うみ', 'ほし', 'かわ', 'もり'],
    correctIndex: 1,
    explanation: '再認課題。5語を1つの風景として結びつけると保持が安定する。',
  ),
  IqQuestion(
    key: 'mem-03b',
    category: IqCategory.memory,
    difficulty: 3,
    memoryStimulus: '9　1　6　3　8　2　7',
    revealSeconds: 7,
    prompt: '先ほどの数字列を「逆から」読んだとき、最初の3つはどれか。',
    options: ['8 2 7', '7 2 8', '2 7 8', '7 8 2'],
    correctIndex: 1,
    explanation: '元の列は 9 1 6 3 8 2 7。逆順の先頭3つは 7 2 8。'
        '逆唱は保持しながら操作する課題で負荷が高い。',
  ),
  IqQuestion(
    key: 'mem-04b',
    category: IqCategory.memory,
    difficulty: 4,
    memoryStimulus: '春 → 桜\n夏 → 海\n秋 → 月\n冬 → 雪',
    revealSeconds: 8,
    prompt: '「秋」と対になっていたのはどれか。',
    options: ['桜', '海', '月', '雪'],
    correctIndex: 2,
    explanation: '対連合学習。「秋の月」のように意味でつなぐと想起が速い。',
  ),
  IqQuestion(
    key: 'mem-05b',
    category: IqCategory.memory,
    difficulty: 5,
    memoryStimulus: 'B2　D1　A3　C4　B1　D3',
    revealSeconds: 9,
    prompt: '「D」で始まる組み合わせの数字を、出てきた順に並べるとどれか。',
    options: ['3 1', '1 3', '1 1', '3 3'],
    correctIndex: 1,
    explanation: 'D1 が先、D3 が後なので「1 3」。'
        '全体を覚えず、条件に合うものだけを選んで保持する選択的更新が要点。',
  ),

  // ---------------------------------------------------------------- 言語理解
  IqQuestion(
    key: 'ver-01b',
    category: IqCategory.verbal,
    difficulty: 1,
    prompt: '「著名」に最も意味が近い語はどれか。',
    options: ['高名', '無名', '奇妙', '平凡'],
    correctIndex: 0,
    explanation: 'どちらも世に広く知られていること。「無名」は対義。',
  ),
  IqQuestion(
    key: 'ver-02b',
    category: IqCategory.verbal,
    difficulty: 2,
    prompt: '「軽率」の対義語はどれか。',
    options: ['軽薄', '慎重', '率直', '敏速'],
    correctIndex: 1,
    explanation: '深く考えずに行う「軽率」に対し、よく考えて行う「慎重」が対。'
        '同じ漢字を含む「軽薄」「率直」に引かれないこと。',
  ),
  IqQuestion(
    key: 'ver-03b',
    category: IqCategory.verbal,
    difficulty: 3,
    prompt: '「画家 : 絵筆」と同じ関係になるのはどれか。\n\n彫刻家 : ?',
    options: ['粘土', 'のみ', '石材', '工房'],
    correctIndex: 1,
    explanation: '「職業 : その職業が使う道具」の関係。'
        '粘土や石材は材料、工房は場所なので関係が異なる。',
  ),
  IqQuestion(
    key: 'ver-04b',
    category: IqCategory.verbal,
    difficulty: 4,
    prompt: '次のうち、他と性質が異なるものはどれか。\n\nイルカ / サメ / クジラ / シャチ',
    options: ['イルカ', 'サメ', 'クジラ', 'シャチ'],
    correctIndex: 1,
    explanation: 'イルカ・クジラ・シャチは哺乳類だが、サメは魚類。'
        '「海の生き物」で止めず、もう一段細かい軸を探す。',
  ),
  IqQuestion(
    key: 'ver-05b',
    category: IqCategory.verbal,
    difficulty: 5,
    prompt: '「彼は謙虚だが、仕事の質には一切妥協しない」\n'
        'この文と最も近い構造を持つのはどれか。',
    options: [
      '彼は明るく、誰とでもすぐ打ち解ける',
      '彼は温厚だが、不正には決して目をつぶらない',
      '彼は寝坊したので、会議に遅れた',
      '彼は教師であり、詩人でもある',
    ],
    correctIndex: 1,
    explanation: '「穏やかな印象」と「譲らない一面」を逆接で対比する構造。'
        '他は並列 (1・4) と因果 (3)。',
  ),
];
