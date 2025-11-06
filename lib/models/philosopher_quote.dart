/// 哲学者の名言データモデル
class PhilosopherQuote {
  final String quote;
  final String author;
  final String imageUrl;
  final String? authorDescription; // オプション: 哲学者の簡単な説明

  const PhilosopherQuote({
    required this.quote,
    required this.author,
    required this.imageUrl,
    this.authorDescription,
  });

  /// 哲学者の名言リスト（日本語）
  static const List<PhilosopherQuote> quotes = [
    PhilosopherQuote(
      quote: '何かを学ぶとき、実際にそれを行なうことによって我々は学ぶ。',
      author: 'アリストテレス',
      imageUrl: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '無知の知。私が知っているのは、自分が何も知らないということだけだ。',
      author: 'ソクラテス',
      imageUrl: 'https://images.unsplash.com/photo-1503023345310-bd7c1de61c7d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '知恵の始まりは定義にあり。',
      author: 'プラトン',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '我思う、ゆえに我あり。',
      author: 'ルネ・デカルト',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&h=800&fit=crop',
      authorDescription: '近世哲学の祖',
    ),
    PhilosopherQuote(
      quote: '経験なき概念は空虚であり、概念なき経験は盲目である。',
      author: 'イマヌエル・カント',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: 'すべての知識は経験に基づく。',
      author: 'イマヌエル・カント',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: '深淵を覗く時、深淵もまたこちらを覗いている。',
      author: 'フリードリヒ・ニーチェ',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: '神は死んだ。我々が神を殺したのだ。',
      author: 'フリードリヒ・ニーチェ',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: '人間は教育によってはじめて人間となる。',
      author: 'イマヌエル・カント',
      imageUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: '千里の道も一歩から。',
      author: '老子',
      imageUrl: 'https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=800&h=800&fit=crop',
      authorDescription: '古代中国の哲学者',
    ),
    PhilosopherQuote(
      quote: '学びて思わざれば則ち罔し、思いて学ばざれば則ち殆し。',
      author: '孔子',
      imageUrl: 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=800&h=800&fit=crop',
      authorDescription: '古代中国の思想家',
    ),
    PhilosopherQuote(
      quote: '知者は惑わず、仁者は憂えず、勇者は懼れず。',
      author: '孔子',
      imageUrl: 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=800&h=800&fit=crop',
      authorDescription: '古代中国の思想家',
    ),
    PhilosopherQuote(
      quote: '人間は自由の刑に処せられている。',
      author: 'ジャン＝ポール・サルトル',
      imageUrl: 'https://images.unsplash.com/photo-1528892952291-009c663ce843?w=800&h=800&fit=crop',
      authorDescription: 'フランスの哲学者',
    ),
    PhilosopherQuote(
      quote: '実存は本質に先立つ。',
      author: 'ジャン＝ポール・サルトル',
      imageUrl: 'https://images.unsplash.com/photo-1528892952291-009c663ce843?w=800&h=800&fit=crop',
      authorDescription: 'フランスの哲学者',
    ),
    PhilosopherQuote(
      quote: '汝自身を知れ。',
      author: 'ソクラテス',
      imageUrl: 'https://images.unsplash.com/photo-1503023345310-bd7c1de61c7d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '習慣は第二の天性なり。',
      author: 'アリストテレス',
      imageUrl: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '真の知恵とは、自分が無知であることを知ることである。',
      author: 'ソクラテス',
      imageUrl: 'https://images.unsplash.com/photo-1503023345310-bd7c1de61c7d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '人間は考える葦である。',
      author: 'ブレーズ・パスカル',
      imageUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=800&h=800&fit=crop',
      authorDescription: 'フランスの哲学者',
    ),
    PhilosopherQuote(
      quote: '善く生きることは、善く考えることである。',
      author: 'マルクス・アウレリウス',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&h=800&fit=crop',
      authorDescription: 'ローマ皇帝・ストア派哲学者',
    ),
    PhilosopherQuote(
      quote: '障害は道である。',
      author: 'マルクス・アウレリウス',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&h=800&fit=crop',
      authorDescription: 'ローマ皇帝・ストア派哲学者',
    ),
    PhilosopherQuote(
      quote: '継続は力なり。小さな一歩の積み重ねが偉大な達成につながる。',
      author: 'アリストテレス',
      imageUrl: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '哲学するとは、死ぬことを学ぶことである。',
      author: 'プラトン',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '疑うことは、知恵の始まりである。',
      author: 'ルネ・デカルト',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&h=800&fit=crop',
      authorDescription: '近世哲学の祖',
    ),
    PhilosopherQuote(
      quote: '怠惰は魅力的だが、ひどい気分にさせる。',
      author: 'ブレーズ・パスカル',
      imageUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=800&h=800&fit=crop',
      authorDescription: 'フランスの哲学者',
    ),
    PhilosopherQuote(
      quote: '上善は水のごとし。水はよく万物を利して争わず。',
      author: '老子',
      imageUrl: 'https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=800&h=800&fit=crop',
      authorDescription: '古代中国の哲学者',
    ),
    PhilosopherQuote(
      quote: '強くなりすぎて壊れることのないように。',
      author: 'フリードリヒ・ニーチェ',
      imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの哲学者',
    ),
    PhilosopherQuote(
      quote: '与えられたものをよく楽しめる者こそ、最も裕福である。',
      author: 'マルクス・アウレリウス',
      imageUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=800&h=800&fit=crop',
      authorDescription: 'ローマ皇帝・ストア派哲学者',
    ),
    PhilosopherQuote(
      quote: '己の欲せざるところ、人に施すなかれ。',
      author: '孔子',
      imageUrl: 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=800&h=800&fit=crop',
      authorDescription: '古代中国の思想家',
    ),
    PhilosopherQuote(
      quote: '善いことをするのに理由は必要ない。',
      author: 'ジャン＝ポール・サルトル',
      imageUrl: 'https://images.unsplash.com/photo-1528892952291-009c663ce843?w=800&h=800&fit=crop',
      authorDescription: 'フランスの哲学者',
    ),
    PhilosopherQuote(
      quote: '未検証の人生は生きるに値しない。',
      author: 'ソクラテス',
      imageUrl: 'https://images.unsplash.com/photo-1503023345310-bd7c1de61c7d?w=800&h=800&fit=crop',
      authorDescription: '古代ギリシアの哲学者',
    ),
    PhilosopherQuote(
      quote: '愛は、人間の実存という問題への、唯一の健全で満足のいく答えである。',
      author: 'エーリッヒ・フロム',
      imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの精神分析学者・社会心理学者',
    ),
    PhilosopherQuote(
      quote: '現代人は、自分自身になることを恐れている。',
      author: 'エーリッヒ・フロム',
      imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの精神分析学者・社会心理学者',
    ),
    PhilosopherQuote(
      quote: '愛するということは、愛される者の成長と幸福を積極的に求めることである。',
      author: 'エーリッヒ・フロム',
      imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&h=800&fit=crop',
      authorDescription: 'ドイツの精神分析学者・社会心理学者',
    ),
    PhilosopherQuote(
      quote: '義を見てせざるは勇無きなり',
      author: '孔子',
      imageUrl: 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=800&h=800&fit=crop',
      authorDescription: '古代中国の思想家',
    ),
    PhilosopherQuote(
      quote: '祈りは神を変えず、祈る者を変える',
      author: 'セーレン・キルケゴール',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&h=800&fit=crop',
      authorDescription: 'デンマークの哲学者',
    ),
  ];

  /// ランダムに名言を取得
  static PhilosopherQuote getRandom() {
    final now = DateTime.now();
    // 日付ベースで名言を選択（毎日同じ名言）
    final index = (now.day + now.month + now.year) % quotes.length;
    return quotes[index];
  }

  /// 完全にランダムに名言を取得（毎回異なる）
  static PhilosopherQuote getRandomAlways() {
    // より良いランダム性を確保するため、複数の要素を組み合わせる
    final now = DateTime.now();
    final seed = now.microsecondsSinceEpoch +
                 now.millisecondsSinceEpoch * 31 +
                 now.second * 97 +
                 now.millisecond * 197;
    final randomIndex = seed % quotes.length;
    return quotes[randomIndex];
  }
}
