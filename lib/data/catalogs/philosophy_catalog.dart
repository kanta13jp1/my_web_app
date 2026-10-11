import 'dart:convert';
import '../../domain/models/philosophy_reading.dart';

// Factual metadata only. Sources link to SEP; edition page counts are user-specific.
const philosophyCatalogVersion = '2026-10-11';

final philosophyAuthors = List<PhilosophyAuthor>.unmodifiable(
  (jsonDecode(_authorsJson) as List)
      .map((value) => PhilosophyAuthor.fromJson(readingMap(value))),
);
final philosophyWorks = List<PhilosophyWork>.unmodifiable(
  (jsonDecode(_worksJson) as List)
      .map((value) => PhilosophyWork.fromJson(readingMap(value))),
);

const _authorsJson = r'''[
  {
    "id": "plato",
    "name": "プラトン",
    "aliases": [
      "Plato"
    ],
    "centuries": [
      "紀元前5世紀",
      "紀元前4世紀"
    ],
    "regions": [
      "古代ギリシア"
    ],
    "traditions": [
      "古代ギリシア哲学"
    ],
    "source": "https://plato.stanford.edu/entries/plato/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "aristotle",
    "name": "アリストテレス",
    "aliases": [
      "Aristotle"
    ],
    "centuries": [
      "紀元前4世紀"
    ],
    "regions": [
      "古代ギリシア"
    ],
    "traditions": [
      "古代ギリシア哲学"
    ],
    "source": "https://plato.stanford.edu/entries/aristotle/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "confucius",
    "name": "孔子",
    "aliases": [
      "Confucius"
    ],
    "centuries": [
      "紀元前6世紀",
      "紀元前5世紀"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "儒家"
    ],
    "source": "https://plato.stanford.edu/entries/confucius/",
    "note": "孔子の教説を伝える編集テキストであり本人執筆と断定しない"
  },
  {
    "id": "laozi",
    "name": "老子",
    "aliases": [
      "Laozi"
    ],
    "centuries": [
      "不明"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "道家"
    ],
    "source": "https://plato.stanford.edu/entries/laozi/",
    "note": "人物の実在や年代および著作の成立と帰属に諸説"
  },
  {
    "id": "zhuangzi",
    "name": "荘子",
    "aliases": [
      "Zhuangzi"
    ],
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "道家"
    ],
    "source": "https://plato.stanford.edu/entries/zhuangzi/",
    "note": "全篇を一人の著作と断定しない"
  },
  {
    "id": "nagarjuna",
    "name": "龍樹",
    "aliases": [
      "Nagarjuna"
    ],
    "centuries": [
      "2世紀",
      "3世紀"
    ],
    "regions": [
      "南アジア"
    ],
    "traditions": [
      "仏教",
      "中観"
    ],
    "source": "https://plato.stanford.edu/entries/nagarjuna/",
    "note": "年代は概数であり帰属は著作ごとに確認"
  },
  {
    "id": "shankara",
    "name": "シャンカラ",
    "aliases": [
      "Shankara"
    ],
    "centuries": [
      "8世紀"
    ],
    "regions": [
      "南アジア"
    ],
    "traditions": [
      "ヴェーダーンタ",
      "不二一元論"
    ],
    "source": "https://plato.stanford.edu/entries/shankara/",
    "note": "年代や他の著作の帰属には異説がある"
  },
  {
    "id": "descartes",
    "name": "デカルト",
    "aliases": [
      "Rene Descartes"
    ],
    "centuries": [
      "17世紀"
    ],
    "regions": [
      "フランス",
      "ネーデルラント"
    ],
    "traditions": [
      "近代合理論"
    ],
    "source": "https://plato.stanford.edu/entries/descartes/",
    "note": "地域は活動との関係を表し国籍ではない"
  },
  {
    "id": "spinoza",
    "name": "スピノザ",
    "aliases": [
      "Baruch Spinoza"
    ],
    "centuries": [
      "17世紀"
    ],
    "regions": [
      "ネーデルラント"
    ],
    "traditions": [
      "近代合理論"
    ],
    "source": "https://plato.stanford.edu/entries/spinoza/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "hume",
    "name": "ヒューム",
    "aliases": [
      "David Hume"
    ],
    "centuries": [
      "18世紀"
    ],
    "regions": [
      "スコットランド"
    ],
    "traditions": [
      "経験論"
    ],
    "source": "https://plato.stanford.edu/entries/hume/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "kant",
    "name": "カント",
    "aliases": [
      "Immanuel Kant"
    ],
    "centuries": [
      "18世紀",
      "19世紀"
    ],
    "regions": [
      "プロイセン"
    ],
    "traditions": [
      "批判哲学"
    ],
    "source": "https://plato.stanford.edu/entries/kant/",
    "note": "地域は歴史的表記であり現在の国に固定しない"
  },
  {
    "id": "nishida",
    "name": "西田幾多郎",
    "aliases": [
      "Nishida Kitaro"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "日本"
    ],
    "traditions": [
      "京都学派"
    ],
    "source": "https://plato.stanford.edu/entries/nishida-kitaro/",
    "note": "活動世紀は生没年の全区間ではなく著述活動の候補"
  },
  {
    "id": "beauvoir",
    "name": "ボーヴォワール",
    "aliases": [
      "Simone de Beauvoir"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "フランス"
    ],
    "traditions": [
      "実存主義",
      "フェミニズム"
    ],
    "source": "https://plato.stanford.edu/entries/beauvoir/",
    "note": "邦訳と版は別途確認"
  }
]''';

const _worksJson = r'''[
  {
    "id": "plato:republic",
    "title": "国家",
    "original_title": "Republic",
    "author_info": {
      "id": "plato",
      "name": "プラトン",
      "aliases": [
        "Plato"
      ],
      "centuries": [
        "紀元前5世紀",
        "紀元前4世紀"
      ],
      "regions": [
        "古代ギリシア"
      ],
      "traditions": [
        "古代ギリシア哲学"
      ],
      "source": "https://plato.stanford.edu/entries/plato/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "紀元前4世紀"
    ],
    "genres": [
      "政治哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/plato/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "plato:apology",
    "title": "ソクラテスの弁明",
    "original_title": "Apology",
    "author_info": {
      "id": "plato",
      "name": "プラトン",
      "aliases": [
        "Plato"
      ],
      "centuries": [
        "紀元前5世紀",
        "紀元前4世紀"
      ],
      "regions": [
        "古代ギリシア"
      ],
      "traditions": [
        "古代ギリシア哲学"
      ],
      "source": "https://plato.stanford.edu/entries/plato/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "紀元前4世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/plato/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "aristotle:nicomachean-ethics",
    "title": "ニコマコス倫理学",
    "original_title": "Nicomachean Ethics",
    "author_info": {
      "id": "aristotle",
      "name": "アリストテレス",
      "aliases": [
        "Aristotle"
      ],
      "centuries": [
        "紀元前4世紀"
      ],
      "regions": [
        "古代ギリシア"
      ],
      "traditions": [
        "古代ギリシア哲学"
      ],
      "source": "https://plato.stanford.edu/entries/aristotle/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "紀元前4世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/aristotle/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "aristotle:metaphysics",
    "title": "形而上学",
    "original_title": "Metaphysics",
    "author_info": {
      "id": "aristotle",
      "name": "アリストテレス",
      "aliases": [
        "Aristotle"
      ],
      "centuries": [
        "紀元前4世紀"
      ],
      "regions": [
        "古代ギリシア"
      ],
      "traditions": [
        "古代ギリシア哲学"
      ],
      "source": "https://plato.stanford.edu/entries/aristotle/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "紀元前4世紀"
    ],
    "genres": [
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/aristotle/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "confucius:analects",
    "title": "論語",
    "original_title": "Lunyu",
    "author_info": {
      "id": "confucius",
      "name": "孔子",
      "aliases": [
        "Confucius"
      ],
      "centuries": [
        "紀元前6世紀",
        "紀元前5世紀"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "儒家"
      ],
      "source": "https://plato.stanford.edu/entries/confucius/",
      "note": "孔子の教説を伝える編集テキストであり本人執筆と断定しない"
    },
    "centuries": [
      "不明"
    ],
    "genres": [
      "倫理学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/confucius/",
    "note": "孔子の教説を伝える編集テキストであり本人執筆と断定しない"
  },
  {
    "id": "laozi:daodejing",
    "title": "道徳経",
    "original_title": "Daodejing",
    "author_info": {
      "id": "laozi",
      "name": "老子",
      "aliases": [
        "Laozi"
      ],
      "centuries": [
        "不明"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "道家"
      ],
      "source": "https://plato.stanford.edu/entries/laozi/",
      "note": "人物の実在や年代および著作の成立と帰属に諸説"
    },
    "centuries": [
      "不明"
    ],
    "genres": [
      "形而上学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/laozi/",
    "note": "人物の実在や年代および著作の成立と帰属に諸説"
  },
  {
    "id": "zhuangzi:zhuangzi",
    "title": "荘子",
    "original_title": "Zhuangzi",
    "author_info": {
      "id": "zhuangzi",
      "name": "荘子",
      "aliases": [
        "Zhuangzi"
      ],
      "centuries": [
        "紀元前4世紀",
        "紀元前3世紀"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "道家"
      ],
      "source": "https://plato.stanford.edu/entries/zhuangzi/",
      "note": "全篇を一人の著作と断定しない"
    },
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "genres": [
      "形而上学",
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/zhuangzi/",
    "note": "全篇を一人の著作と断定しない"
  },
  {
    "id": "nagarjuna:mulamadhyamakakarika",
    "title": "中論",
    "original_title": "Mulamadhyamakakarika",
    "author_info": {
      "id": "nagarjuna",
      "name": "龍樹",
      "aliases": [
        "Nagarjuna"
      ],
      "centuries": [
        "2世紀",
        "3世紀"
      ],
      "regions": [
        "南アジア"
      ],
      "traditions": [
        "仏教",
        "中観"
      ],
      "source": "https://plato.stanford.edu/entries/nagarjuna/",
      "note": "年代は概数であり帰属は著作ごとに確認"
    },
    "centuries": [
      "2世紀",
      "3世紀"
    ],
    "genres": [
      "形而上学",
      "宗教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/nagarjuna/",
    "note": "年代は概数であり帰属は著作ごとに確認"
  },
  {
    "id": "shankara:brahmasutrabhasya",
    "title": "ブラフマ・スートラ註解",
    "original_title": "Brahmasutrabhasya",
    "author_info": {
      "id": "shankara",
      "name": "シャンカラ",
      "aliases": [
        "Shankara"
      ],
      "centuries": [
        "8世紀"
      ],
      "regions": [
        "南アジア"
      ],
      "traditions": [
        "ヴェーダーンタ",
        "不二一元論"
      ],
      "source": "https://plato.stanford.edu/entries/shankara/",
      "note": "年代や他の著作の帰属には異説がある"
    },
    "centuries": [
      "8世紀"
    ],
    "genres": [
      "形而上学",
      "宗教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/shankara/",
    "note": "年代や他の著作の帰属には異説がある"
  },
  {
    "id": "descartes:meditations",
    "title": "省察",
    "original_title": "Meditationes de prima philosophia",
    "author_info": {
      "id": "descartes",
      "name": "デカルト",
      "aliases": [
        "Rene Descartes"
      ],
      "centuries": [
        "17世紀"
      ],
      "regions": [
        "フランス",
        "ネーデルラント"
      ],
      "traditions": [
        "近代合理論"
      ],
      "source": "https://plato.stanford.edu/entries/descartes/",
      "note": "地域は活動との関係を表し国籍ではない"
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/descartes/",
    "note": "地域は活動との関係を表し国籍ではない"
  },
  {
    "id": "descartes:discourse",
    "title": "方法序説",
    "original_title": "Discours de la methode",
    "author_info": {
      "id": "descartes",
      "name": "デカルト",
      "aliases": [
        "Rene Descartes"
      ],
      "centuries": [
        "17世紀"
      ],
      "regions": [
        "フランス",
        "ネーデルラント"
      ],
      "traditions": [
        "近代合理論"
      ],
      "source": "https://plato.stanford.edu/entries/descartes/",
      "note": "地域は活動との関係を表し国籍ではない"
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/descartes/",
    "note": "地域は活動との関係を表し国籍ではない"
  },
  {
    "id": "spinoza:ethics",
    "title": "エチカ",
    "original_title": "Ethica",
    "author_info": {
      "id": "spinoza",
      "name": "スピノザ",
      "aliases": [
        "Baruch Spinoza"
      ],
      "centuries": [
        "17世紀"
      ],
      "regions": [
        "ネーデルラント"
      ],
      "traditions": [
        "近代合理論"
      ],
      "source": "https://plato.stanford.edu/entries/spinoza/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "倫理学",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/spinoza/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "hume:treatise",
    "title": "人間本性論",
    "original_title": "A Treatise of Human Nature",
    "author_info": {
      "id": "hume",
      "name": "ヒューム",
      "aliases": [
        "David Hume"
      ],
      "centuries": [
        "18世紀"
      ],
      "regions": [
        "スコットランド"
      ],
      "traditions": [
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/hume/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "認識論",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/hume/",
    "note": "邦訳と版は別途確認"
  },
  {
    "id": "kant:pure-reason",
    "title": "純粋理性批判",
    "original_title": "Kritik der reinen Vernunft",
    "author_info": {
      "id": "kant",
      "name": "カント",
      "aliases": [
        "Immanuel Kant"
      ],
      "centuries": [
        "18世紀",
        "19世紀"
      ],
      "regions": [
        "プロイセン"
      ],
      "traditions": [
        "批判哲学"
      ],
      "source": "https://plato.stanford.edu/entries/kant/",
      "note": "地域は歴史的表記であり現在の国に固定しない"
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/kant/",
    "note": "地域は歴史的表記であり現在の国に固定しない"
  },
  {
    "id": "kant:practical-reason",
    "title": "実践理性批判",
    "original_title": "Kritik der praktischen Vernunft",
    "author_info": {
      "id": "kant",
      "name": "カント",
      "aliases": [
        "Immanuel Kant"
      ],
      "centuries": [
        "18世紀",
        "19世紀"
      ],
      "regions": [
        "プロイセン"
      ],
      "traditions": [
        "批判哲学"
      ],
      "source": "https://plato.stanford.edu/entries/kant/",
      "note": "地域は歴史的表記であり現在の国に固定しない"
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/kant/",
    "note": "地域は歴史的表記であり現在の国に固定しない"
  },
  {
    "id": "nishida:inquiry",
    "title": "善の研究",
    "original_title": "善の研究",
    "author_info": {
      "id": "nishida",
      "name": "西田幾多郎",
      "aliases": [
        "Nishida Kitaro"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "京都学派"
      ],
      "source": "https://plato.stanford.edu/entries/nishida-kitaro/",
      "note": "活動世紀は生没年の全区間ではなく著述活動の候補"
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "倫理学",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/nishida-kitaro/",
    "note": "活動世紀は生没年の全区間ではなく著述活動の候補"
  },
  {
    "id": "beauvoir:second-sex",
    "title": "第二の性",
    "original_title": "Le Deuxieme Sexe",
    "author_info": {
      "id": "beauvoir",
      "name": "ボーヴォワール",
      "aliases": [
        "Simone de Beauvoir"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "フランス"
      ],
      "traditions": [
        "実存主義",
        "フェミニズム"
      ],
      "source": "https://plato.stanford.edu/entries/beauvoir/",
      "note": "邦訳と版は別途確認"
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "倫理学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/beauvoir/",
    "note": "邦訳と版は別途確認"
  }
]''';
