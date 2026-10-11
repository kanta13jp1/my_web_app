import 'dart:convert';
import '../../domain/models/philosophy_reading.dart';

// Factual metadata only; attribution sources and edition sources are separate.
const philosophyCatalogVersion = '2026-10-11-japanese-editions';

class PhilosophyCatalogEdition {
  const PhilosophyCatalogEdition(this.workId, this.label, this.edition,
      {this.note = ''});
  final String workId;
  final String label;
  final ReadingEdition edition;
  final String note;
}

// Verified publisher/library bibliographies. Unknown fields remain empty.
// A volume's page count is never treated as the complete work's page count.
const philosophyCatalogEditions = [
  PhilosophyCatalogEdition(
    'aristotle:nicomachean-ethics',
    'ニコマコス倫理学（上）・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '渡辺邦夫・立花幸司',
      year: '2015',
      isbn: '9784334753221',
      volume: '上巻・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book221/',
      bookUrl: 'https://www.kotensinyaku.jp/books/book221/',
    ),
  ),
  PhilosophyCatalogEdition(
    'confucius:analects',
    '論語・岩波文庫（改訂新版）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '金谷治（訳注）',
      year: '1999',
      isbn: '9784003320211',
      volume: '岩波文庫・改訂新版',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002845211',
      bookUrl: 'https://www.kinokuniya.co.jp/f/dsg-01-9784003320211',
    ),
  ),
  PhilosophyCatalogEdition(
    'arendt:human-condition',
    '人間の条件・ちくま学芸文庫',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '志水速雄',
      year: '1994',
      isbn: '9784480081568',
      volume: 'ちくま学芸文庫',
      totalPages: 560,
      sourceUrl: 'https://www.chikumashobo.co.jp/product/9784480081568/',
      bookUrl: 'https://www.chikumashobo.co.jp/product/9784480081568/',
    ),
  ),
  PhilosophyCatalogEdition(
    'dogen:zuimonki',
    '正法眼蔵随聞記・ちくま学芸文庫',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '水野弥穂子',
      editor: '懐奘（記録・編纂）',
      year: '1992',
      isbn: '9784480080226',
      volume: 'ちくま学芸文庫',
      totalPages: 464,
      sourceUrl: 'https://www.chikumashobo.co.jp/product/9784480080226/',
      bookUrl: 'https://www.chikumashobo.co.jp/product/9784480080226/',
    ),
  ),
  PhilosophyCatalogEdition(
    'habermas:facts-norms',
    'Between Facts and Norms・英語ペーパーバック',
    ReadingEdition(
      publisher: 'The MIT Press',
      translator: 'William Rehg',
      year: '1998',
      language: '英語',
      isbn: '9780262581622',
      volume: 'Paperback',
      totalPages: 676,
      sourceUrl:
          'https://mitpress.mit.edu/9780262581622/between-facts-and-norms/',
      bookUrl:
          'https://mitpress.mit.edu/9780262581622/between-facts-and-norms/',
    ),
  ),
  PhilosophyCatalogEdition(
    'butler:gender-trouble',
    'ジェンダー・トラブル・青土社（1999年版）',
    ReadingEdition(
      publisher: '青土社',
      translator: '竹村和子',
      year: '1999',
      isbn: '4791757033',
      volume: '1999年版',
      sourceUrl: 'https://www.seidosha.co.jp/book/index.php?id=856',
      bookUrl: 'https://www.seidosha.co.jp/book/index.php?id=856',
    ),
  ),
  PhilosophyCatalogEdition(
    'aristotle:nicomachean-ethics',
    'ニコマコス倫理学（下）・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '渡辺邦夫・立花幸司',
      year: '2016',
      isbn: '9784334753245',
      volume: '下巻・光文社古典新訳文庫（全2巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book222/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753245',
    ),
  ),
  PhilosophyCatalogEdition(
    'confucius:analects',
    '論語・光文社古典新訳文庫（鶴ヶ谷真一訳）',
    ReadingEdition(
      publisher: '光文社',
      translator: '鶴ヶ谷真一（訳・注）',
      year: '2025',
      isbn: '9784334107741',
      volume: '光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book420/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334107741',
    ),
  ),
  PhilosophyCatalogEdition(
    'mill:liberty',
    '自由論・光文社古典新訳文庫（斉藤悦則訳）',
    ReadingEdition(
      publisher: '光文社',
      translator: '斉藤悦則',
      year: '2012',
      isbn: '9784334752507',
      volume: '光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book150/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752507',
    ),
  ),
  PhilosophyCatalogEdition(
    'rousseau:social-contract',
    '社会契約論／ジュネーヴ草稿・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2008',
      isbn: '9784334751678',
      volume: '光文社古典新訳文庫（ジュネーヴ草稿併録）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book66/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334751678',
    ),
  ),
  PhilosophyCatalogEdition(
    'plato:apology',
    'ソクラテスの弁明・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '納富信留',
      year: '2012',
      isbn: '9784334752569',
      volume: '光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book156/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752569',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 1・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2010',
      isbn: '9784334751982',
      volume: '第1巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book97/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334751982',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 2・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2010',
      isbn: '9784334752040',
      volume: '第2巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book104/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752040',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 3・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2010',
      isbn: '9784334752132',
      volume: '第3巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book112/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752132',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 4・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2011',
      isbn: '9784334752231',
      volume: '第4巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book120/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752231',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 5・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2011',
      isbn: '9784334752293',
      volume: '第5巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book127/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752293',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 6・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2011',
      isbn: '9784334752354',
      volume: '第6巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book133/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752354',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:pure-reason',
    '純粋理性批判 7・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2012',
      isbn: '9784334752439',
      volume: '第7巻・光文社古典新訳文庫（全7巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book141/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752439',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:practical-reason',
    '実践理性批判 1・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2013',
      isbn: '9784334752699',
      volume: '第1巻・光文社古典新訳文庫（全2巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book167/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752699',
    ),
  ),
  PhilosophyCatalogEdition(
    'kant:practical-reason',
    '実践理性批判 2・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2013',
      isbn: '9784334752736',
      volume: '第2巻・光文社古典新訳文庫（全2巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book172/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752736',
    ),
  ),
  PhilosophyCatalogEdition(
    'nietzsche:zarathustra',
    'ツァラトゥストラ（上）・光文社古典新訳文庫（丘沢静也訳）',
    ReadingEdition(
      publisher: '光文社',
      translator: '丘沢静也',
      year: '2010',
      isbn: '9784334752170',
      volume: '上巻・光文社古典新訳文庫（全2巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book116/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752170',
    ),
  ),
  PhilosophyCatalogEdition(
    'nietzsche:zarathustra',
    'ツァラトゥストラ（下）・光文社古典新訳文庫（丘沢静也訳）',
    ReadingEdition(
      publisher: '光文社',
      translator: '丘沢静也',
      year: '2011',
      isbn: '9784334752224',
      volume: '下巻・光文社古典新訳文庫（全2巻）',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book121/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752224',
    ),
  ),
  PhilosophyCatalogEdition(
    'descartes:meditations',
    '省察・筑摩書房（山田弘明訳）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '山田弘明',
      year: '2006',
      isbn: '9784480089656',
      volume: 'ちくま学芸文庫',
      totalPages: 320,
      sourceUrl: 'https://www.chikumashobo.co.jp/product/9784480089656/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480089656',
    ),
  ),
  PhilosophyCatalogEdition(
    'descartes:discourse',
    '方法序説・筑摩書房（山田弘明訳）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '山田弘明',
      year: '2010',
      isbn: '9784480093066',
      volume: 'ちくま学芸文庫',
      totalPages: 288,
      sourceUrl: 'https://www.chikumashobo.co.jp/product/9784480093066/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480093066',
    ),
  ),
  PhilosophyCatalogEdition(
    'nietzsche:zarathustra',
    'ツァラトゥストラ（上）・筑摩書房（吉沢伝三郎訳）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '吉沢伝三郎',
      year: '1993',
      isbn: '9784480080790',
      volume: 'ニーチェ全集9・ちくま学芸文庫（第一部・第二部）',
      sourceUrl: 'https://www.chikumashobo.co.jp/product/9784480080790/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480080790',
    ),
  ),
  PhilosophyCatalogEdition(
    'mill:liberty',
    '自由論・日経BPクラシックス（山岡洋一訳）',
    ReadingEdition(
      publisher: '日経BP',
      translator: '山岡洋一',
      year: '2011',
      isbn: '9784822248574',
      volume: '日経BPクラシックス',
      totalPages: 264,
      sourceUrl: 'https://bookplus.nikkei.com/atcl/catalog/11/P48570/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784822248574',
    ),
  ),
  PhilosophyCatalogEdition(
    'arendt:human-condition',
    '人間の条件・講談社学術文庫（牧野雅彦訳）',
    ReadingEdition(
      publisher: '講談社',
      translator: '牧野雅彦',
      year: '2023',
      isbn: '9784065314272',
      volume: '講談社学術文庫',
      totalPages: 632,
      sourceUrl: 'https://www.kodansha.co.jp/book/products/0000365277',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784065314272',
    ),
  ),
  PhilosophyCatalogEdition(
    'plato:republic',
    '国家（上）・岩波文庫',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '藤澤令夫',
      year: '1979',
      isbn: '9784003360170',
      volume: '上巻・岩波文庫（全2巻）',
      sourceUrl: 'https://www.books.or.jp/book-details/9784003360170',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003360170',
    ),
    note: '書誌の初刊年を記載。刷・改版によってページ数が異なるため、手元の本で確認してください。',
  ),
  PhilosophyCatalogEdition(
    'plato:republic',
    '国家（下）・岩波文庫',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '藤澤令夫',
      year: '1979',
      isbn: '9784003360187',
      volume: '下巻・岩波文庫（全2巻）',
      sourceUrl: 'https://www.books.or.jp/book-details/9784003360187',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003360187',
    ),
    note: '書誌の初刊年を記載。刷・改版によってページ数が異なるため、手元の本で確認してください。',
  ),
  PhilosophyCatalogEdition(
    'laozi:daodejing',
    '老子・岩波文庫（蜂屋邦夫訳注）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '蜂屋邦夫（訳注）',
      year: '2008',
      isbn: '9784003320518',
      volume: '岩波文庫',
      sourceUrl:
          'https://lib-opac.mc.beppu-u.ac.jp/webopac/catdbl.do?hidden_return_link=true&pkey=BB00112034',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003320518',
    ),
    note: '出版社書誌と図書館書誌でページ数表記が異なるため、手元の本で確認してください。',
  ),
  PhilosophyCatalogEdition(
    'nagarjuna:mulamadhyamakakarika',
    '中論（上）・レグルス文庫',
    ReadingEdition(
      publisher: '第三文明社',
      translator: '三枝充悳（訳注）',
      year: '1984',
      isbn: '9784476011586',
      volume: '上巻・レグルス文庫（全3巻）',
      totalPages: 280,
      sourceUrl: 'https://www.daisanbunmei.co.jp/books/book.php?mt=0&no=01158',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784476011586',
    ),
    note: '羅什漢訳を基準にサンスクリット詩頌と対照した訳注。入手先では中古を含む在庫・版を確認してください。',
  ),
  PhilosophyCatalogEdition(
    'nagarjuna:mulamadhyamakakarika',
    '中論（中）・レグルス文庫',
    ReadingEdition(
      publisher: '第三文明社',
      translator: '三枝充悳（訳注）',
      year: '1984',
      isbn: '9784476011593',
      volume: '中巻・レグルス文庫（全3巻）',
      totalPages: 272,
      sourceUrl: 'https://www.daisanbunmei.co.jp/books/book.php?mt=0&no=01159',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784476011593',
    ),
    note: '羅什漢訳を基準にサンスクリット詩頌と対照した訳注。入手先では中古を含む在庫・版を確認してください。',
  ),
  PhilosophyCatalogEdition(
    'nagarjuna:mulamadhyamakakarika',
    '中論（下）・レグルス文庫',
    ReadingEdition(
      publisher: '第三文明社',
      translator: '三枝充悳（訳注）',
      year: '1984',
      isbn: '9784476011609',
      volume: '下巻・レグルス文庫（全3巻）',
      totalPages: 272,
      sourceUrl: 'https://www.daisanbunmei.co.jp/books/book.php?mt=0&no=01160',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784476011609',
    ),
    note: '羅什漢訳を基準にサンスクリット詩頌と対照した訳注。入手先では中古を含む在庫・版を確認してください。',
  ),
];

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
  },
  {
    "id": "epicurus",
    "name": "エピクロス",
    "aliases": [
      "Epicurus"
    ],
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "regions": [
      "古代ギリシア"
    ],
    "traditions": [
      "エピクロス派"
    ],
    "source": "https://plato.stanford.edu/entries/epicurus/",
    "note": ""
  },
  {
    "id": "epictetus",
    "name": "エピクテトス",
    "aliases": [
      "Epictetus"
    ],
    "centuries": [
      "1世紀",
      "2世紀"
    ],
    "regions": [
      "ローマ帝国"
    ],
    "traditions": [
      "ストア派"
    ],
    "source": "https://plato.stanford.edu/entries/epictetus/",
    "note": "教説は弟子アリアノスが記録。"
  },
  {
    "id": "marcus-aurelius",
    "name": "マルクス・アウレリウス",
    "aliases": [
      "Marcus Aurelius"
    ],
    "centuries": [
      "2世紀"
    ],
    "regions": [
      "ローマ帝国"
    ],
    "traditions": [
      "ストア派"
    ],
    "source": "https://plato.stanford.edu/entries/marcus-aurelius/",
    "note": ""
  },
  {
    "id": "plotinus",
    "name": "プロティノス",
    "aliases": [
      "Plotinus"
    ],
    "centuries": [
      "3世紀"
    ],
    "regions": [
      "ローマ帝国"
    ],
    "traditions": [
      "新プラトン主義"
    ],
    "source": "https://plato.stanford.edu/entries/plotinus/",
    "note": ""
  },
  {
    "id": "augustine",
    "name": "アウグスティヌス",
    "aliases": [
      "Augustine"
    ],
    "centuries": [
      "4世紀",
      "5世紀"
    ],
    "regions": [
      "北アフリカ（ローマ帝国）"
    ],
    "traditions": [
      "キリスト教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/augustine/",
    "note": ""
  },
  {
    "id": "boethius",
    "name": "ボエティウス",
    "aliases": [
      "Boethius"
    ],
    "centuries": [
      "6世紀"
    ],
    "regions": [
      "イタリア（東ゴート王国）"
    ],
    "traditions": [
      "キリスト教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/boethius/",
    "note": ""
  },
  {
    "id": "al-farabi",
    "name": "ファーラービー",
    "aliases": [
      "al-Farabi"
    ],
    "centuries": [
      "10世紀"
    ],
    "regions": [
      "西アジア（アッバース朝）"
    ],
    "traditions": [
      "イスラーム哲学"
    ],
    "source": "https://plato.stanford.edu/entries/al-farabi/",
    "note": "出自の現代国籍への固定は避け、活動地域を記載。"
  },
  {
    "id": "avicenna",
    "name": "イブン・スィーナー",
    "aliases": [
      "Avicenna",
      "Ibn Sina"
    ],
    "centuries": [
      "10世紀",
      "11世紀"
    ],
    "regions": [
      "中央アジア",
      "ペルシア"
    ],
    "traditions": [
      "イスラーム哲学"
    ],
    "source": "https://plato.stanford.edu/entries/ibn-sina/",
    "note": ""
  },
  {
    "id": "averroes",
    "name": "イブン・ルシュド",
    "aliases": [
      "Averroes",
      "Ibn Rushd"
    ],
    "centuries": [
      "12世紀"
    ],
    "regions": [
      "アンダルス",
      "北アフリカ"
    ],
    "traditions": [
      "イスラーム哲学"
    ],
    "source": "https://plato.stanford.edu/entries/ibn-rushd/",
    "note": ""
  },
  {
    "id": "aquinas",
    "name": "トマス・アクィナス",
    "aliases": [
      "Thomas Aquinas"
    ],
    "centuries": [
      "13世紀"
    ],
    "regions": [
      "イタリア",
      "フランス"
    ],
    "traditions": [
      "スコラ哲学"
    ],
    "source": "https://plato.stanford.edu/entries/aquinas/",
    "note": ""
  },
  {
    "id": "mencius",
    "name": "孟子",
    "aliases": [
      "Mencius",
      "Mengzi"
    ],
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "儒家"
    ],
    "source": "https://plato.stanford.edu/entries/mencius/",
    "note": ""
  },
  {
    "id": "xunzi",
    "name": "荀子",
    "aliases": [
      "Xunzi"
    ],
    "centuries": [
      "紀元前3世紀"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "儒家"
    ],
    "source": "https://plato.stanford.edu/entries/xunzi/",
    "note": ""
  },
  {
    "id": "mozi",
    "name": "墨子",
    "aliases": [
      "Mozi"
    ],
    "centuries": [
      "紀元前5世紀",
      "紀元前4世紀"
    ],
    "regions": [
      "古代中国"
    ],
    "traditions": [
      "墨家"
    ],
    "source": "https://plato.stanford.edu/entries/mohism/",
    "note": "墨子と墨家の学派的伝承を区別。"
  },
  {
    "id": "zhu-xi",
    "name": "朱熹",
    "aliases": [
      "Zhu Xi"
    ],
    "centuries": [
      "12世紀"
    ],
    "regions": [
      "中国（宋）"
    ],
    "traditions": [
      "儒家",
      "朱子学"
    ],
    "source": "https://plato.stanford.edu/entries/zhu-xi/",
    "note": ""
  },
  {
    "id": "wang-yangming",
    "name": "王陽明",
    "aliases": [
      "Wang Yangming"
    ],
    "centuries": [
      "15世紀",
      "16世紀"
    ],
    "regions": [
      "中国（明）"
    ],
    "traditions": [
      "儒家",
      "陽明学"
    ],
    "source": "https://plato.stanford.edu/entries/wang-yangming/",
    "note": ""
  },
  {
    "id": "vasubandhu",
    "name": "世親",
    "aliases": [
      "Vasubandhu"
    ],
    "centuries": [
      "4世紀",
      "5世紀"
    ],
    "regions": [
      "南アジア"
    ],
    "traditions": [
      "仏教",
      "唯識"
    ],
    "source": "https://plato.stanford.edu/entries/vasubandhu/",
    "note": "年代および同名人物についての議論がある。"
  },
  {
    "id": "tsongkhapa",
    "name": "ツォンカパ",
    "aliases": [
      "Tsongkhapa"
    ],
    "centuries": [
      "14世紀",
      "15世紀"
    ],
    "regions": [
      "チベット"
    ],
    "traditions": [
      "仏教",
      "中観"
    ],
    "source": "https://plato.stanford.edu/entries/tsongkhapa/",
    "note": ""
  },
  {
    "id": "kukai",
    "name": "空海",
    "aliases": [
      "Kukai"
    ],
    "centuries": [
      "8世紀",
      "9世紀"
    ],
    "regions": [
      "日本"
    ],
    "traditions": [
      "仏教",
      "密教"
    ],
    "source": "https://plato.stanford.edu/entries/kukai/",
    "note": ""
  },
  {
    "id": "dogen",
    "name": "道元",
    "aliases": [
      "Dogen"
    ],
    "centuries": [
      "13世紀"
    ],
    "regions": [
      "日本"
    ],
    "traditions": [
      "仏教",
      "禅"
    ],
    "source": "https://plato.stanford.edu/entries/japanese-zen/",
    "note": ""
  },
  {
    "id": "watsuji",
    "name": "和辻哲郎",
    "aliases": [
      "Watsuji Tetsuro"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "日本"
    ],
    "traditions": [
      "日本近代哲学"
    ],
    "source": "https://plato.stanford.edu/entries/watsuji-tetsuro/",
    "note": ""
  },
  {
    "id": "locke",
    "name": "ジョン・ロック",
    "aliases": [
      "John Locke"
    ],
    "centuries": [
      "17世紀",
      "18世紀"
    ],
    "regions": [
      "イングランド"
    ],
    "traditions": [
      "経験論"
    ],
    "source": "https://plato.stanford.edu/entries/locke/",
    "note": ""
  },
  {
    "id": "leibniz",
    "name": "ライプニッツ",
    "aliases": [
      "Gottfried Wilhelm Leibniz"
    ],
    "centuries": [
      "17世紀",
      "18世紀"
    ],
    "regions": [
      "ドイツ諸邦"
    ],
    "traditions": [
      "近代合理論"
    ],
    "source": "https://plato.stanford.edu/entries/leibniz/",
    "note": ""
  },
  {
    "id": "rousseau",
    "name": "ジャン＝ジャック・ルソー",
    "aliases": [
      "Jean-Jacques Rousseau"
    ],
    "centuries": [
      "18世紀"
    ],
    "regions": [
      "ジュネーヴ",
      "フランス"
    ],
    "traditions": [
      "啓蒙思想"
    ],
    "source": "https://plato.stanford.edu/entries/rousseau/",
    "note": ""
  },
  {
    "id": "hegel",
    "name": "ヘーゲル",
    "aliases": [
      "Georg Wilhelm Friedrich Hegel"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "ドイツ諸邦"
    ],
    "traditions": [
      "ドイツ観念論"
    ],
    "source": "https://plato.stanford.edu/entries/hegel/",
    "note": ""
  },
  {
    "id": "schopenhauer",
    "name": "ショーペンハウアー",
    "aliases": [
      "Arthur Schopenhauer"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "ドイツ諸邦"
    ],
    "traditions": [
      "意志の哲学"
    ],
    "source": "https://plato.stanford.edu/entries/schopenhauer/",
    "note": ""
  },
  {
    "id": "kierkegaard",
    "name": "キルケゴール",
    "aliases": [
      "Soren Kierkegaard"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "デンマーク"
    ],
    "traditions": [
      "実存思想"
    ],
    "source": "https://plato.stanford.edu/entries/kierkegaard/",
    "note": "筆名で執筆された著作が多い。"
  },
  {
    "id": "marx",
    "name": "カール・マルクス",
    "aliases": [
      "Karl Marx"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "ドイツ諸邦",
      "イギリス"
    ],
    "traditions": [
      "マルクス主義"
    ],
    "source": "https://plato.stanford.edu/entries/marx/",
    "note": ""
  },
  {
    "id": "nietzsche",
    "name": "ニーチェ",
    "aliases": [
      "Friedrich Nietzsche"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "ドイツ",
      "スイス"
    ],
    "traditions": [
      "生の哲学"
    ],
    "source": "https://plato.stanford.edu/entries/nietzsche/",
    "note": ""
  },
  {
    "id": "husserl",
    "name": "フッサール",
    "aliases": [
      "Edmund Husserl"
    ],
    "centuries": [
      "19世紀",
      "20世紀"
    ],
    "regions": [
      "オーストリア＝ハンガリー",
      "ドイツ"
    ],
    "traditions": [
      "現象学"
    ],
    "source": "https://plato.stanford.edu/entries/husserl/",
    "note": ""
  },
  {
    "id": "heidegger",
    "name": "ハイデガー",
    "aliases": [
      "Martin Heidegger"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "ドイツ"
    ],
    "traditions": [
      "現象学",
      "実存思想"
    ],
    "source": "https://plato.stanford.edu/entries/heidegger/",
    "note": ""
  },
  {
    "id": "wittgenstein",
    "name": "ウィトゲンシュタイン",
    "aliases": [
      "Ludwig Wittgenstein"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "オーストリア",
      "イギリス"
    ],
    "traditions": [
      "分析哲学"
    ],
    "source": "https://plato.stanford.edu/entries/wittgenstein/",
    "note": ""
  },
  {
    "id": "russell",
    "name": "バートランド・ラッセル",
    "aliases": [
      "Bertrand Russell"
    ],
    "centuries": [
      "19世紀",
      "20世紀"
    ],
    "regions": [
      "イギリス"
    ],
    "traditions": [
      "分析哲学"
    ],
    "source": "https://plato.stanford.edu/entries/russell/",
    "note": ""
  },
  {
    "id": "sartre",
    "name": "サルトル",
    "aliases": [
      "Jean-Paul Sartre"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "フランス"
    ],
    "traditions": [
      "実存主義"
    ],
    "source": "https://plato.stanford.edu/entries/sartre/",
    "note": ""
  },
  {
    "id": "arendt",
    "name": "ハンナ・アーレント",
    "aliases": [
      "Hannah Arendt"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "ドイツ",
      "アメリカ合衆国"
    ],
    "traditions": [
      "政治思想"
    ],
    "source": "https://plato.stanford.edu/entries/arendt/",
    "note": ""
  },
  {
    "id": "foucault",
    "name": "ミシェル・フーコー",
    "aliases": [
      "Michel Foucault"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "フランス"
    ],
    "traditions": [
      "ポスト構造主義"
    ],
    "source": "https://plato.stanford.edu/entries/foucault/",
    "note": ""
  },
  {
    "id": "rawls",
    "name": "ジョン・ロールズ",
    "aliases": [
      "John Rawls"
    ],
    "centuries": [
      "20世紀"
    ],
    "regions": [
      "アメリカ合衆国"
    ],
    "traditions": [
      "リベラリズム"
    ],
    "source": "https://plato.stanford.edu/entries/rawls/",
    "note": ""
  },
  {
    "id": "habermas",
    "name": "ユルゲン・ハーバーマス",
    "aliases": [
      "Jurgen Habermas"
    ],
    "centuries": [
      "20世紀",
      "21世紀"
    ],
    "regions": [
      "ドイツ"
    ],
    "traditions": [
      "批判理論"
    ],
    "source": "https://plato.stanford.edu/entries/habermas/",
    "note": ""
  },
  {
    "id": "butler",
    "name": "ジュディス・バトラー",
    "aliases": [
      "Judith Butler"
    ],
    "centuries": [
      "20世紀",
      "21世紀"
    ],
    "regions": [
      "アメリカ合衆国"
    ],
    "traditions": [
      "フェミニズム",
      "クィア理論"
    ],
    "source": "https://vcresearch.berkeley.edu/faculty/judith-butler",
    "note": ""
  },
  {
    "id": "sen",
    "name": "アマルティア・セン",
    "aliases": [
      "Amartya Sen"
    ],
    "centuries": [
      "20世紀",
      "21世紀"
    ],
    "regions": [
      "インド",
      "イギリス",
      "アメリカ合衆国"
    ],
    "traditions": [
      "ケイパビリティ論"
    ],
    "source": "https://philosophy.fas.harvard.edu/publications/idea-justice",
    "note": "活動地域は著述・研究との関係を表す。"
  },
  {
    "id": "hobbes",
    "name": "トマス・ホッブズ",
    "aliases": [
      "Thomas Hobbes"
    ],
    "centuries": [
      "17世紀"
    ],
    "regions": [
      "イングランド"
    ],
    "traditions": [
      "社会契約論"
    ],
    "source": "https://plato.stanford.edu/entries/hobbes/",
    "note": ""
  },
  {
    "id": "mill",
    "name": "ジョン・スチュアート・ミル",
    "aliases": [
      "John Stuart Mill"
    ],
    "centuries": [
      "19世紀"
    ],
    "regions": [
      "イギリス"
    ],
    "traditions": [
      "功利主義",
      "経験論"
    ],
    "source": "https://plato.stanford.edu/entries/mill/",
    "note": ""
  },
  {
    "id": "wollstonecraft",
    "name": "メアリ・ウルストンクラフト",
    "aliases": [
      "Mary Wollstonecraft"
    ],
    "centuries": [
      "18世紀"
    ],
    "regions": [
      "イギリス"
    ],
    "traditions": [
      "啓蒙思想",
      "フェミニズム"
    ],
    "source": "https://plato.stanford.edu/entries/wollstonecraft/",
    "note": ""
  },
  {
    "id": "bacon",
    "name": "フランシス・ベーコン",
    "aliases": [
      "Francis Bacon"
    ],
    "centuries": [
      "16世紀",
      "17世紀"
    ],
    "regions": [
      "イングランド"
    ],
    "traditions": [
      "経験論"
    ],
    "source": "https://plato.stanford.edu/entries/francis-bacon/",
    "note": ""
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
  },
  {
    "id": "epicurus:menoeceus",
    "title": "メノイケウス宛の手紙",
    "original_title": "Letter to Menoeceus",
    "author_info": {
      "id": "epicurus",
      "name": "エピクロス",
      "aliases": [
        "Epicurus"
      ],
      "centuries": [
        "紀元前4世紀",
        "紀元前3世紀"
      ],
      "regions": [
        "古代ギリシア"
      ],
      "traditions": [
        "エピクロス派"
      ],
      "source": "https://plato.stanford.edu/entries/epicurus/",
      "note": ""
    },
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/epicurus/",
    "note": "成立年は確定せず、ディオゲネス・ラエルティオスが伝える。"
  },
  {
    "id": "epictetus:discourses",
    "title": "語録",
    "original_title": "Discourses",
    "author_info": {
      "id": "epictetus",
      "name": "エピクテトス",
      "aliases": [
        "Epictetus"
      ],
      "centuries": [
        "1世紀",
        "2世紀"
      ],
      "regions": [
        "ローマ帝国"
      ],
      "traditions": [
        "ストア派"
      ],
      "source": "https://plato.stanford.edu/entries/epictetus/",
      "note": "教説は弟子アリアノスが記録。"
    },
    "centuries": [
      "2世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/epictetus/",
    "note": "アリアノスによる教説の記録。"
  },
  {
    "id": "epictetus:enchiridion",
    "title": "提要",
    "original_title": "Enchiridion",
    "author_info": {
      "id": "epictetus",
      "name": "エピクテトス",
      "aliases": [
        "Epictetus"
      ],
      "centuries": [
        "1世紀",
        "2世紀"
      ],
      "regions": [
        "ローマ帝国"
      ],
      "traditions": [
        "ストア派"
      ],
      "source": "https://plato.stanford.edu/entries/epictetus/",
      "note": "教説は弟子アリアノスが記録。"
    },
    "centuries": [
      "2世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/epictetus/",
    "note": "アリアノスによる教説の要約。"
  },
  {
    "id": "marcus-aurelius:meditations",
    "title": "自省録",
    "original_title": "Meditations",
    "author_info": {
      "id": "marcus-aurelius",
      "name": "マルクス・アウレリウス",
      "aliases": [
        "Marcus Aurelius"
      ],
      "centuries": [
        "2世紀"
      ],
      "regions": [
        "ローマ帝国"
      ],
      "traditions": [
        "ストア派"
      ],
      "source": "https://plato.stanford.edu/entries/marcus-aurelius/",
      "note": ""
    },
    "centuries": [
      "2世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/marcus-aurelius/",
    "note": ""
  },
  {
    "id": "plotinus:enneads",
    "title": "エネアデス",
    "original_title": "Enneads",
    "author_info": {
      "id": "plotinus",
      "name": "プロティノス",
      "aliases": [
        "Plotinus"
      ],
      "centuries": [
        "3世紀"
      ],
      "regions": [
        "ローマ帝国"
      ],
      "traditions": [
        "新プラトン主義"
      ],
      "source": "https://plato.stanford.edu/entries/plotinus/",
      "note": ""
    },
    "centuries": [
      "3世紀"
    ],
    "genres": [
      "形而上学",
      "宗教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/plotinus/",
    "note": "論文群を弟子ポルピュリオスが死後に編纂。編纂は3〜4世紀。"
  },
  {
    "id": "augustine:confessions",
    "title": "告白",
    "original_title": "Confessiones",
    "author_info": {
      "id": "augustine",
      "name": "アウグスティヌス",
      "aliases": [
        "Augustine"
      ],
      "centuries": [
        "4世紀",
        "5世紀"
      ],
      "regions": [
        "北アフリカ（ローマ帝国）"
      ],
      "traditions": [
        "キリスト教哲学"
      ],
      "source": "https://plato.stanford.edu/entries/augustine/",
      "note": ""
    },
    "centuries": [
      "4世紀",
      "5世紀"
    ],
    "genres": [
      "宗教哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/augustine/",
    "note": "成立年代は4世紀末〜5世紀初頭の概数。"
  },
  {
    "id": "augustine:city-of-god",
    "title": "神の国",
    "original_title": "De civitate Dei",
    "author_info": {
      "id": "augustine",
      "name": "アウグスティヌス",
      "aliases": [
        "Augustine"
      ],
      "centuries": [
        "4世紀",
        "5世紀"
      ],
      "regions": [
        "北アフリカ（ローマ帝国）"
      ],
      "traditions": [
        "キリスト教哲学"
      ],
      "source": "https://plato.stanford.edu/entries/augustine/",
      "note": ""
    },
    "centuries": [
      "5世紀"
    ],
    "genres": [
      "宗教哲学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/augustine/",
    "note": "412〜426年頃。"
  },
  {
    "id": "boethius:consolation",
    "title": "哲学の慰め",
    "original_title": "Consolation of Philosophy",
    "author_info": {
      "id": "boethius",
      "name": "ボエティウス",
      "aliases": [
        "Boethius"
      ],
      "centuries": [
        "6世紀"
      ],
      "regions": [
        "イタリア（東ゴート王国）"
      ],
      "traditions": [
        "キリスト教哲学"
      ],
      "source": "https://plato.stanford.edu/entries/boethius/",
      "note": ""
    },
    "centuries": [
      "6世紀"
    ],
    "genres": [
      "倫理学",
      "宗教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/boethius/",
    "note": "524年頃。"
  },
  {
    "id": "al-farabi:virtuous-city",
    "title": "有徳都市の住民の見解",
    "original_title": "The Opinions of the People of the Virtuous City",
    "author_info": {
      "id": "al-farabi",
      "name": "ファーラービー",
      "aliases": [
        "al-Farabi"
      ],
      "centuries": [
        "10世紀"
      ],
      "regions": [
        "西アジア（アッバース朝）"
      ],
      "traditions": [
        "イスラーム哲学"
      ],
      "source": "https://plato.stanford.edu/entries/al-farabi/",
      "note": "出自の現代国籍への固定は避け、活動地域を記載。"
    },
    "centuries": [
      "10世紀"
    ],
    "genres": [
      "政治哲学",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/al-farabi/",
    "note": "邦題には表記の異同がある。"
  },
  {
    "id": "avicenna:healing",
    "title": "治癒の書",
    "original_title": "Kitab al-Shifa",
    "author_info": {
      "id": "avicenna",
      "name": "イブン・スィーナー",
      "aliases": [
        "Avicenna",
        "Ibn Sina"
      ],
      "centuries": [
        "10世紀",
        "11世紀"
      ],
      "regions": [
        "中央アジア",
        "ペルシア"
      ],
      "traditions": [
        "イスラーム哲学"
      ],
      "source": "https://plato.stanford.edu/entries/ibn-sina/",
      "note": ""
    },
    "centuries": [
      "11世紀"
    ],
    "genres": [
      "形而上学",
      "認識論",
      "論理学"
    ],
    "source": "https://plato.stanford.edu/entries/ibn-sina/",
    "note": "哲学・諸科学の大著。医学書の医学典範とは別。"
  },
  {
    "id": "averroes:decisive-treatise",
    "title": "決定的論考",
    "original_title": "Fasl al-Maqal",
    "author_info": {
      "id": "averroes",
      "name": "イブン・ルシュド",
      "aliases": [
        "Averroes",
        "Ibn Rushd"
      ],
      "centuries": [
        "12世紀"
      ],
      "regions": [
        "アンダルス",
        "北アフリカ"
      ],
      "traditions": [
        "イスラーム哲学"
      ],
      "source": "https://plato.stanford.edu/entries/ibn-rushd/",
      "note": ""
    },
    "centuries": [
      "12世紀"
    ],
    "genres": [
      "宗教哲学"
    ],
    "source": "https://plato.stanford.edu/entries/ibn-rushd/",
    "note": "邦題には表記の異同がある。"
  },
  {
    "id": "aquinas:summa",
    "title": "神学大全",
    "original_title": "Summa Theologiae",
    "author_info": {
      "id": "aquinas",
      "name": "トマス・アクィナス",
      "aliases": [
        "Thomas Aquinas"
      ],
      "centuries": [
        "13世紀"
      ],
      "regions": [
        "イタリア",
        "フランス"
      ],
      "traditions": [
        "スコラ哲学"
      ],
      "source": "https://plato.stanford.edu/entries/aquinas/",
      "note": ""
    },
    "centuries": [
      "13世紀"
    ],
    "genres": [
      "宗教哲学",
      "形而上学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/aquinas/",
    "note": "1265〜1274年。未完。"
  },
  {
    "id": "mencius:mengzi",
    "title": "孟子",
    "original_title": "Mengzi",
    "author_info": {
      "id": "mencius",
      "name": "孟子",
      "aliases": [
        "Mencius",
        "Mengzi"
      ],
      "centuries": [
        "紀元前4世紀",
        "紀元前3世紀"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "儒家"
      ],
      "source": "https://plato.stanford.edu/entries/mencius/",
      "note": ""
    },
    "centuries": [
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "genres": [
      "倫理学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/mencius/",
    "note": "対話・教説の編集テキスト。成立年代は概数。"
  },
  {
    "id": "xunzi:xunzi",
    "title": "荀子",
    "original_title": "Xunzi",
    "author_info": {
      "id": "xunzi",
      "name": "荀子",
      "aliases": [
        "Xunzi"
      ],
      "centuries": [
        "紀元前3世紀"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "儒家"
      ],
      "source": "https://plato.stanford.edu/entries/xunzi/",
      "note": ""
    },
    "centuries": [
      "紀元前3世紀"
    ],
    "genres": [
      "倫理学",
      "政治哲学",
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/xunzi/",
    "note": "伝承・後代の編集を含む。"
  },
  {
    "id": "mozi:mozi",
    "title": "墨子",
    "original_title": "Mozi",
    "author_info": {
      "id": "mozi",
      "name": "墨子",
      "aliases": [
        "Mozi"
      ],
      "centuries": [
        "紀元前5世紀",
        "紀元前4世紀"
      ],
      "regions": [
        "古代中国"
      ],
      "traditions": [
        "墨家"
      ],
      "source": "https://plato.stanford.edu/entries/mohism/",
      "note": "墨子と墨家の学派的伝承を区別。"
    },
    "centuries": [
      "紀元前5世紀",
      "紀元前4世紀",
      "紀元前3世紀"
    ],
    "genres": [
      "倫理学",
      "政治哲学",
      "論理学"
    ],
    "source": "https://plato.stanford.edu/entries/mohism/",
    "note": "複数の時期・担い手による編集テキスト。墨子本人の単独執筆ではない。"
  },
  {
    "id": "zhu-xi:four-books",
    "title": "四書章句集注",
    "original_title": "Commentaries on the Four Books",
    "author_info": {
      "id": "zhu-xi",
      "name": "朱熹",
      "aliases": [
        "Zhu Xi"
      ],
      "centuries": [
        "12世紀"
      ],
      "regions": [
        "中国（宋）"
      ],
      "traditions": [
        "儒家",
        "朱子学"
      ],
      "source": "https://plato.stanford.edu/entries/zhu-xi/",
      "note": ""
    },
    "centuries": [
      "12世紀"
    ],
    "genres": [
      "倫理学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/zhu-xi/",
    "note": "四書への注釈群。構成・巻を確認して版を選ぶ。"
  },
  {
    "id": "wang-yangming:instructions",
    "title": "伝習録",
    "original_title": "Instructions for Practical Living",
    "author_info": {
      "id": "wang-yangming",
      "name": "王陽明",
      "aliases": [
        "Wang Yangming"
      ],
      "centuries": [
        "15世紀",
        "16世紀"
      ],
      "regions": [
        "中国（明）"
      ],
      "traditions": [
        "儒家",
        "陽明学"
      ],
      "source": "https://plato.stanford.edu/entries/wang-yangming/",
      "note": ""
    },
    "centuries": [
      "16世紀"
    ],
    "genres": [
      "倫理学",
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/wang-yangming/",
    "note": "弟子が記録・編纂した語録と書簡。"
  },
  {
    "id": "vasubandhu:twenty-verses",
    "title": "唯識二十論",
    "original_title": "Vimsatika",
    "author_info": {
      "id": "vasubandhu",
      "name": "世親",
      "aliases": [
        "Vasubandhu"
      ],
      "centuries": [
        "4世紀",
        "5世紀"
      ],
      "regions": [
        "南アジア"
      ],
      "traditions": [
        "仏教",
        "唯識"
      ],
      "source": "https://plato.stanford.edu/entries/vasubandhu/",
      "note": "年代および同名人物についての議論がある。"
    },
    "centuries": [
      "4世紀",
      "5世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/vasubandhu/",
    "note": "年代は概数。"
  },
  {
    "id": "vasubandhu:thirty-verses",
    "title": "唯識三十頌",
    "original_title": "Trimsika",
    "author_info": {
      "id": "vasubandhu",
      "name": "世親",
      "aliases": [
        "Vasubandhu"
      ],
      "centuries": [
        "4世紀",
        "5世紀"
      ],
      "regions": [
        "南アジア"
      ],
      "traditions": [
        "仏教",
        "唯識"
      ],
      "source": "https://plato.stanford.edu/entries/vasubandhu/",
      "note": "年代および同名人物についての議論がある。"
    },
    "centuries": [
      "4世紀",
      "5世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/vasubandhu/",
    "note": "年代は概数。"
  },
  {
    "id": "tsongkhapa:lamrim",
    "title": "菩提道次第広論",
    "original_title": "Lam rim chen mo",
    "author_info": {
      "id": "tsongkhapa",
      "name": "ツォンカパ",
      "aliases": [
        "Tsongkhapa"
      ],
      "centuries": [
        "14世紀",
        "15世紀"
      ],
      "regions": [
        "チベット"
      ],
      "traditions": [
        "仏教",
        "中観"
      ],
      "source": "https://plato.stanford.edu/entries/tsongkhapa/",
      "note": ""
    },
    "centuries": [
      "15世紀"
    ],
    "genres": [
      "宗教哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/tsongkhapa/",
    "note": "1402年。邦題には表記の異同がある。"
  },
  {
    "id": "kukai:sokushin-jobutsu",
    "title": "即身成仏義",
    "original_title": "Sokushin jobutsu gi",
    "author_info": {
      "id": "kukai",
      "name": "空海",
      "aliases": [
        "Kukai"
      ],
      "centuries": [
        "8世紀",
        "9世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "仏教",
        "密教"
      ],
      "source": "https://plato.stanford.edu/entries/kukai/",
      "note": ""
    },
    "centuries": [
      "9世紀"
    ],
    "genres": [
      "宗教哲学",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/kukai/",
    "note": ""
  },
  {
    "id": "dogen:shobogenzo",
    "title": "正法眼蔵",
    "original_title": "Shobogenzo",
    "author_info": {
      "id": "dogen",
      "name": "道元",
      "aliases": [
        "Dogen"
      ],
      "centuries": [
        "13世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "仏教",
        "禅"
      ],
      "source": "https://plato.stanford.edu/entries/japanese-zen/",
      "note": ""
    },
    "centuries": [
      "13世紀"
    ],
    "genres": [
      "宗教哲学",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/japanese-zen/",
    "note": "巻数・構成が異なる諸本がある。"
  },
  {
    "id": "dogen:zuimonki",
    "title": "正法眼蔵随聞記",
    "original_title": "Shobogenzo Zuimonki",
    "author_info": {
      "id": "dogen",
      "name": "道元",
      "aliases": [
        "Dogen"
      ],
      "centuries": [
        "13世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "仏教",
        "禅"
      ],
      "source": "https://plato.stanford.edu/entries/japanese-zen/",
      "note": ""
    },
    "centuries": [
      "13世紀"
    ],
    "genres": [
      "宗教哲学",
      "倫理学"
    ],
    "source": "https://www.chikumashobo.co.jp/product/9784480080226/",
    "note": "懐奘が道元の教えを記録。本人執筆とは区別。"
  },
  {
    "id": "watsuji:ethics",
    "title": "倫理学",
    "original_title": "Rinrigaku",
    "author_info": {
      "id": "watsuji",
      "name": "和辻哲郎",
      "aliases": [
        "Watsuji Tetsuro"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "日本近代哲学"
      ],
      "source": "https://plato.stanford.edu/entries/watsuji-tetsuro/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/watsuji-tetsuro/",
    "note": "1937〜1949年の巻からなる。"
  },
  {
    "id": "watsuji:climate",
    "title": "風土",
    "original_title": "Fudo",
    "author_info": {
      "id": "watsuji",
      "name": "和辻哲郎",
      "aliases": [
        "Watsuji Tetsuro"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "日本"
      ],
      "traditions": [
        "日本近代哲学"
      ],
      "source": "https://plato.stanford.edu/entries/watsuji-tetsuro/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "社会哲学"
    ],
    "source": "https://plato.stanford.edu/entries/watsuji-tetsuro/",
    "note": "1935年。"
  },
  {
    "id": "locke:understanding",
    "title": "人間知性論",
    "original_title": "An Essay Concerning Human Understanding",
    "author_info": {
      "id": "locke",
      "name": "ジョン・ロック",
      "aliases": [
        "John Locke"
      ],
      "centuries": [
        "17世紀",
        "18世紀"
      ],
      "regions": [
        "イングランド"
      ],
      "traditions": [
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/locke/",
      "note": ""
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/locke/",
    "note": "初版は1690年付（刊行1689年）。"
  },
  {
    "id": "locke:government",
    "title": "統治二論",
    "original_title": "Two Treatises of Government",
    "author_info": {
      "id": "locke",
      "name": "ジョン・ロック",
      "aliases": [
        "John Locke"
      ],
      "centuries": [
        "17世紀",
        "18世紀"
      ],
      "regions": [
        "イングランド"
      ],
      "traditions": [
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/locke/",
      "note": ""
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/locke/",
    "note": "初版は1690年付（刊行1689年）。"
  },
  {
    "id": "leibniz:monadology",
    "title": "モナドロジー",
    "original_title": "Monadologie",
    "author_info": {
      "id": "leibniz",
      "name": "ライプニッツ",
      "aliases": [
        "Gottfried Wilhelm Leibniz"
      ],
      "centuries": [
        "17世紀",
        "18世紀"
      ],
      "regions": [
        "ドイツ諸邦"
      ],
      "traditions": [
        "近代合理論"
      ],
      "source": "https://plato.stanford.edu/entries/leibniz/",
      "note": ""
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/leibniz/",
    "note": "1714年執筆。刊行は死後。"
  },
  {
    "id": "rousseau:social-contract",
    "title": "社会契約論",
    "original_title": "Du contrat social",
    "author_info": {
      "id": "rousseau",
      "name": "ジャン＝ジャック・ルソー",
      "aliases": [
        "Jean-Jacques Rousseau"
      ],
      "centuries": [
        "18世紀"
      ],
      "regions": [
        "ジュネーヴ",
        "フランス"
      ],
      "traditions": [
        "啓蒙思想"
      ],
      "source": "https://plato.stanford.edu/entries/rousseau/",
      "note": ""
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/rousseau/",
    "note": "1762年。"
  },
  {
    "id": "rousseau:inequality",
    "title": "人間不平等起源論",
    "original_title": "Discours sur l’origine et les fondements de l’inégalité parmi les hommes",
    "author_info": {
      "id": "rousseau",
      "name": "ジャン＝ジャック・ルソー",
      "aliases": [
        "Jean-Jacques Rousseau"
      ],
      "centuries": [
        "18世紀"
      ],
      "regions": [
        "ジュネーヴ",
        "フランス"
      ],
      "traditions": [
        "啓蒙思想"
      ],
      "source": "https://plato.stanford.edu/entries/rousseau/",
      "note": ""
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "政治哲学",
      "社会哲学"
    ],
    "source": "https://plato.stanford.edu/entries/rousseau/",
    "note": "1755年。"
  },
  {
    "id": "hegel:phenomenology",
    "title": "精神現象学",
    "original_title": "Phänomenologie des Geistes",
    "author_info": {
      "id": "hegel",
      "name": "ヘーゲル",
      "aliases": [
        "Georg Wilhelm Friedrich Hegel"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ諸邦"
      ],
      "traditions": [
        "ドイツ観念論"
      ],
      "source": "https://plato.stanford.edu/entries/hegel/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/hegel/",
    "note": "1807年。"
  },
  {
    "id": "hegel:right",
    "title": "法の哲学",
    "original_title": "Grundlinien der Philosophie des Rechts",
    "author_info": {
      "id": "hegel",
      "name": "ヘーゲル",
      "aliases": [
        "Georg Wilhelm Friedrich Hegel"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ諸邦"
      ],
      "traditions": [
        "ドイツ観念論"
      ],
      "source": "https://plato.stanford.edu/entries/hegel/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "政治哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/hegel/",
    "note": "1821年付の初版。"
  },
  {
    "id": "schopenhauer:world",
    "title": "意志と表象としての世界",
    "original_title": "Die Welt als Wille und Vorstellung",
    "author_info": {
      "id": "schopenhauer",
      "name": "ショーペンハウアー",
      "aliases": [
        "Arthur Schopenhauer"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ諸邦"
      ],
      "traditions": [
        "意志の哲学"
      ],
      "source": "https://plato.stanford.edu/entries/schopenhauer/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "形而上学",
      "美学"
    ],
    "source": "https://plato.stanford.edu/entries/schopenhauer/",
    "note": "初版1819年付、第二巻は1844年。"
  },
  {
    "id": "kierkegaard:fear-trembling",
    "title": "恐れとおののき",
    "original_title": "Frygt og Bæven",
    "author_info": {
      "id": "kierkegaard",
      "name": "キルケゴール",
      "aliases": [
        "Soren Kierkegaard"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "デンマーク"
      ],
      "traditions": [
        "実存思想"
      ],
      "source": "https://plato.stanford.edu/entries/kierkegaard/",
      "note": "筆名で執筆された著作が多い。"
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "宗教哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/kierkegaard/",
    "note": "1843年。筆名ヨハネス・デ・シレンティオ。"
  },
  {
    "id": "kierkegaard:sickness",
    "title": "死に至る病",
    "original_title": "Sygdommen til Døden",
    "author_info": {
      "id": "kierkegaard",
      "name": "キルケゴール",
      "aliases": [
        "Soren Kierkegaard"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "デンマーク"
      ],
      "traditions": [
        "実存思想"
      ],
      "source": "https://plato.stanford.edu/entries/kierkegaard/",
      "note": "筆名で執筆された著作が多い。"
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "宗教哲学",
      "実存哲学"
    ],
    "source": "https://plato.stanford.edu/entries/kierkegaard/",
    "note": "1849年。筆名アンチ＝クリマクス。"
  },
  {
    "id": "marx:capital",
    "title": "資本論",
    "original_title": "Das Kapital",
    "author_info": {
      "id": "marx",
      "name": "カール・マルクス",
      "aliases": [
        "Karl Marx"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ諸邦",
        "イギリス"
      ],
      "traditions": [
        "マルクス主義"
      ],
      "source": "https://plato.stanford.edu/entries/marx/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "社会哲学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/marx/",
    "note": "第一巻1867年。第二・第三巻はエンゲルスの編集で死後刊行。"
  },
  {
    "id": "marx:manifesto",
    "title": "共産党宣言",
    "original_title": "Manifest der Kommunistischen Partei",
    "author_info": {
      "id": "marx",
      "name": "カール・マルクス",
      "aliases": [
        "Karl Marx"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ諸邦",
        "イギリス"
      ],
      "traditions": [
        "マルクス主義"
      ],
      "source": "https://plato.stanford.edu/entries/marx/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/marx/",
    "note": "1848年。フリードリヒ・エンゲルスとの共著。"
  },
  {
    "id": "nietzsche:zarathustra",
    "title": "ツァラトゥストラはこう語った",
    "original_title": "Also sprach Zarathustra",
    "author_info": {
      "id": "nietzsche",
      "name": "ニーチェ",
      "aliases": [
        "Friedrich Nietzsche"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ",
        "スイス"
      ],
      "traditions": [
        "生の哲学"
      ],
      "source": "https://plato.stanford.edu/entries/nietzsche/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "実存哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/nietzsche/",
    "note": "1883〜1885年。"
  },
  {
    "id": "nietzsche:genealogy",
    "title": "道徳の系譜",
    "original_title": "Zur Genealogie der Moral",
    "author_info": {
      "id": "nietzsche",
      "name": "ニーチェ",
      "aliases": [
        "Friedrich Nietzsche"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "ドイツ",
        "スイス"
      ],
      "traditions": [
        "生の哲学"
      ],
      "source": "https://plato.stanford.edu/entries/nietzsche/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/nietzsche/",
    "note": "1887年。"
  },
  {
    "id": "husserl:logical-investigations",
    "title": "論理学研究",
    "original_title": "Logische Untersuchungen",
    "author_info": {
      "id": "husserl",
      "name": "フッサール",
      "aliases": [
        "Edmund Husserl"
      ],
      "centuries": [
        "19世紀",
        "20世紀"
      ],
      "regions": [
        "オーストリア＝ハンガリー",
        "ドイツ"
      ],
      "traditions": [
        "現象学"
      ],
      "source": "https://plato.stanford.edu/entries/husserl/",
      "note": ""
    },
    "centuries": [
      "19世紀",
      "20世紀"
    ],
    "genres": [
      "論理学",
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/husserl/",
    "note": "1900〜1901年。世紀境界を跨ぐ。"
  },
  {
    "id": "husserl:ideas",
    "title": "イデーン I",
    "original_title": "Ideen I",
    "author_info": {
      "id": "husserl",
      "name": "フッサール",
      "aliases": [
        "Edmund Husserl"
      ],
      "centuries": [
        "19世紀",
        "20世紀"
      ],
      "regions": [
        "オーストリア＝ハンガリー",
        "ドイツ"
      ],
      "traditions": [
        "現象学"
      ],
      "source": "https://plato.stanford.edu/entries/husserl/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "認識論",
      "形而上学"
    ],
    "source": "https://plato.stanford.edu/entries/husserl/",
    "note": "1913年。"
  },
  {
    "id": "heidegger:being-time",
    "title": "存在と時間",
    "original_title": "Sein und Zeit",
    "author_info": {
      "id": "heidegger",
      "name": "ハイデガー",
      "aliases": [
        "Martin Heidegger"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "ドイツ"
      ],
      "traditions": [
        "現象学",
        "実存思想"
      ],
      "source": "https://plato.stanford.edu/entries/heidegger/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "形而上学",
      "実存哲学"
    ],
    "source": "https://plato.stanford.edu/entries/heidegger/",
    "note": "1927年。"
  },
  {
    "id": "wittgenstein:tractatus",
    "title": "論理哲学論考",
    "original_title": "Tractatus Logico-Philosophicus",
    "author_info": {
      "id": "wittgenstein",
      "name": "ウィトゲンシュタイン",
      "aliases": [
        "Ludwig Wittgenstein"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "オーストリア",
        "イギリス"
      ],
      "traditions": [
        "分析哲学"
      ],
      "source": "https://plato.stanford.edu/entries/wittgenstein/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "論理学",
      "言語哲学"
    ],
    "source": "https://plato.stanford.edu/entries/wittgenstein/",
    "note": "1921年ドイツ語版、1922年独英対訳版。"
  },
  {
    "id": "wittgenstein:investigations",
    "title": "哲学探究",
    "original_title": "Philosophische Untersuchungen",
    "author_info": {
      "id": "wittgenstein",
      "name": "ウィトゲンシュタイン",
      "aliases": [
        "Ludwig Wittgenstein"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "オーストリア",
        "イギリス"
      ],
      "traditions": [
        "分析哲学"
      ],
      "source": "https://plato.stanford.edu/entries/wittgenstein/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "言語哲学"
    ],
    "source": "https://plato.stanford.edu/entries/wittgenstein/",
    "note": "1953年死後刊行。"
  },
  {
    "id": "russell:problems",
    "title": "哲学の諸問題",
    "original_title": "The Problems of Philosophy",
    "author_info": {
      "id": "russell",
      "name": "バートランド・ラッセル",
      "aliases": [
        "Bertrand Russell"
      ],
      "centuries": [
        "19世紀",
        "20世紀"
      ],
      "regions": [
        "イギリス"
      ],
      "traditions": [
        "分析哲学"
      ],
      "source": "https://plato.stanford.edu/entries/russell/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "認識論"
    ],
    "source": "https://plato.stanford.edu/entries/russell/",
    "note": "1912年。"
  },
  {
    "id": "sartre:being-nothingness",
    "title": "存在と無",
    "original_title": "L’être et le néant",
    "author_info": {
      "id": "sartre",
      "name": "サルトル",
      "aliases": [
        "Jean-Paul Sartre"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "フランス"
      ],
      "traditions": [
        "実存主義"
      ],
      "source": "https://plato.stanford.edu/entries/sartre/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "形而上学",
      "実存哲学"
    ],
    "source": "https://plato.stanford.edu/entries/sartre/",
    "note": "1943年。"
  },
  {
    "id": "sartre:humanism",
    "title": "実存主義はヒューマニズムである",
    "original_title": "L’existentialisme est un humanisme",
    "author_info": {
      "id": "sartre",
      "name": "サルトル",
      "aliases": [
        "Jean-Paul Sartre"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "フランス"
      ],
      "traditions": [
        "実存主義"
      ],
      "source": "https://plato.stanford.edu/entries/sartre/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "倫理学",
      "実存哲学"
    ],
    "source": "https://plato.stanford.edu/entries/sartre/",
    "note": "1945年講演、1946年刊行。"
  },
  {
    "id": "arendt:human-condition",
    "title": "人間の条件",
    "original_title": "The Human Condition",
    "author_info": {
      "id": "arendt",
      "name": "ハンナ・アーレント",
      "aliases": [
        "Hannah Arendt"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "ドイツ",
        "アメリカ合衆国"
      ],
      "traditions": [
        "政治思想"
      ],
      "source": "https://plato.stanford.edu/entries/arendt/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "政治哲学",
      "社会哲学"
    ],
    "source": "https://plato.stanford.edu/entries/arendt/",
    "note": "1958年。"
  },
  {
    "id": "arendt:totalitarianism",
    "title": "全体主義の起原",
    "original_title": "The Origins of Totalitarianism",
    "author_info": {
      "id": "arendt",
      "name": "ハンナ・アーレント",
      "aliases": [
        "Hannah Arendt"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "ドイツ",
        "アメリカ合衆国"
      ],
      "traditions": [
        "政治思想"
      ],
      "source": "https://plato.stanford.edu/entries/arendt/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/arendt/",
    "note": "1951年。"
  },
  {
    "id": "foucault:discipline",
    "title": "監獄の誕生",
    "original_title": "Surveiller et punir",
    "author_info": {
      "id": "foucault",
      "name": "ミシェル・フーコー",
      "aliases": [
        "Michel Foucault"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "フランス"
      ],
      "traditions": [
        "ポスト構造主義"
      ],
      "source": "https://plato.stanford.edu/entries/foucault/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "社会哲学",
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/foucault/",
    "note": "1975年。"
  },
  {
    "id": "foucault:sexuality",
    "title": "性の歴史",
    "original_title": "Histoire de la sexualité",
    "author_info": {
      "id": "foucault",
      "name": "ミシェル・フーコー",
      "aliases": [
        "Michel Foucault"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "フランス"
      ],
      "traditions": [
        "ポスト構造主義"
      ],
      "source": "https://plato.stanford.edu/entries/foucault/",
      "note": ""
    },
    "centuries": [
      "20世紀",
      "21世紀"
    ],
    "genres": [
      "社会哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/foucault/",
    "note": "第一巻1976年。第三巻まで1984年。第四巻は2018年の死後刊行。"
  },
  {
    "id": "rawls:justice",
    "title": "正義論",
    "original_title": "A Theory of Justice",
    "author_info": {
      "id": "rawls",
      "name": "ジョン・ロールズ",
      "aliases": [
        "John Rawls"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "アメリカ合衆国"
      ],
      "traditions": [
        "リベラリズム"
      ],
      "source": "https://plato.stanford.edu/entries/rawls/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "政治哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/rawls/",
    "note": "1971年。"
  },
  {
    "id": "rawls:political-liberalism",
    "title": "政治的リベラリズム",
    "original_title": "Political Liberalism",
    "author_info": {
      "id": "rawls",
      "name": "ジョン・ロールズ",
      "aliases": [
        "John Rawls"
      ],
      "centuries": [
        "20世紀"
      ],
      "regions": [
        "アメリカ合衆国"
      ],
      "traditions": [
        "リベラリズム"
      ],
      "source": "https://plato.stanford.edu/entries/rawls/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/rawls/",
    "note": "1993年。"
  },
  {
    "id": "habermas:communicative-action",
    "title": "コミュニケーション的行為の理論",
    "original_title": "Theorie des kommunikativen Handelns",
    "author_info": {
      "id": "habermas",
      "name": "ユルゲン・ハーバーマス",
      "aliases": [
        "Jurgen Habermas"
      ],
      "centuries": [
        "20世紀",
        "21世紀"
      ],
      "regions": [
        "ドイツ"
      ],
      "traditions": [
        "批判理論"
      ],
      "source": "https://plato.stanford.edu/entries/habermas/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "社会哲学",
      "言語哲学"
    ],
    "source": "https://plato.stanford.edu/entries/habermas/",
    "note": "1981年。"
  },
  {
    "id": "habermas:facts-norms",
    "title": "事実性と妥当性",
    "original_title": "Faktizität und Geltung",
    "author_info": {
      "id": "habermas",
      "name": "ユルゲン・ハーバーマス",
      "aliases": [
        "Jurgen Habermas"
      ],
      "centuries": [
        "20世紀",
        "21世紀"
      ],
      "regions": [
        "ドイツ"
      ],
      "traditions": [
        "批判理論"
      ],
      "source": "https://plato.stanford.edu/entries/habermas/",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "政治哲学",
      "法哲学"
    ],
    "source": "https://plato.stanford.edu/entries/habermas/",
    "note": "1992年。"
  },
  {
    "id": "butler:gender-trouble",
    "title": "ジェンダー・トラブル",
    "original_title": "Gender Trouble",
    "author_info": {
      "id": "butler",
      "name": "ジュディス・バトラー",
      "aliases": [
        "Judith Butler"
      ],
      "centuries": [
        "20世紀",
        "21世紀"
      ],
      "regions": [
        "アメリカ合衆国"
      ],
      "traditions": [
        "フェミニズム",
        "クィア理論"
      ],
      "source": "https://vcresearch.berkeley.edu/faculty/judith-butler",
      "note": ""
    },
    "centuries": [
      "20世紀"
    ],
    "genres": [
      "社会哲学",
      "倫理学"
    ],
    "source": "https://vcresearch.berkeley.edu/faculty/judith-butler",
    "note": "1990年。"
  },
  {
    "id": "butler:afraid-gender",
    "title": "Who’s Afraid of Gender?",
    "original_title": "Who’s Afraid of Gender?",
    "author_info": {
      "id": "butler",
      "name": "ジュディス・バトラー",
      "aliases": [
        "Judith Butler"
      ],
      "centuries": [
        "20世紀",
        "21世紀"
      ],
      "regions": [
        "アメリカ合衆国"
      ],
      "traditions": [
        "フェミニズム",
        "クィア理論"
      ],
      "source": "https://vcresearch.berkeley.edu/faculty/judith-butler",
      "note": ""
    },
    "centuries": [
      "21世紀"
    ],
    "genres": [
      "社会哲学",
      "政治哲学"
    ],
    "source": "https://vcresearch.berkeley.edu/faculty/judith-butler",
    "note": "2024年。原著名で掲載。"
  },
  {
    "id": "sen:idea-justice",
    "title": "正義のアイデア",
    "original_title": "The Idea of Justice",
    "author_info": {
      "id": "sen",
      "name": "アマルティア・セン",
      "aliases": [
        "Amartya Sen"
      ],
      "centuries": [
        "20世紀",
        "21世紀"
      ],
      "regions": [
        "インド",
        "イギリス",
        "アメリカ合衆国"
      ],
      "traditions": [
        "ケイパビリティ論"
      ],
      "source": "https://philosophy.fas.harvard.edu/publications/idea-justice",
      "note": "活動地域は著述・研究との関係を表す。"
    },
    "centuries": [
      "21世紀"
    ],
    "genres": [
      "政治哲学",
      "倫理学"
    ],
    "source": "https://philosophy.fas.harvard.edu/publications/idea-justice",
    "note": "2009年。"
  },
  {
    "id": "hobbes:leviathan",
    "title": "リヴァイアサン",
    "original_title": "Leviathan",
    "author_info": {
      "id": "hobbes",
      "name": "トマス・ホッブズ",
      "aliases": [
        "Thomas Hobbes"
      ],
      "centuries": [
        "17世紀"
      ],
      "regions": [
        "イングランド"
      ],
      "traditions": [
        "社会契約論"
      ],
      "source": "https://plato.stanford.edu/entries/hobbes/",
      "note": ""
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/hobbes/",
    "note": "1651年。"
  },
  {
    "id": "mill:liberty",
    "title": "自由論",
    "original_title": "On Liberty",
    "author_info": {
      "id": "mill",
      "name": "ジョン・スチュアート・ミル",
      "aliases": [
        "John Stuart Mill"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "イギリス"
      ],
      "traditions": [
        "功利主義",
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/mill/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "政治哲学"
    ],
    "source": "https://plato.stanford.edu/entries/mill/",
    "note": "1859年。"
  },
  {
    "id": "mill:utilitarianism",
    "title": "功利主義",
    "original_title": "Utilitarianism",
    "author_info": {
      "id": "mill",
      "name": "ジョン・スチュアート・ミル",
      "aliases": [
        "John Stuart Mill"
      ],
      "centuries": [
        "19世紀"
      ],
      "regions": [
        "イギリス"
      ],
      "traditions": [
        "功利主義",
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/mill/",
      "note": ""
    },
    "centuries": [
      "19世紀"
    ],
    "genres": [
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/mill/",
    "note": "1861年連載、1863年単行本。"
  },
  {
    "id": "wollstonecraft:rights-woman",
    "title": "女性の権利の擁護",
    "original_title": "A Vindication of the Rights of Woman",
    "author_info": {
      "id": "wollstonecraft",
      "name": "メアリ・ウルストンクラフト",
      "aliases": [
        "Mary Wollstonecraft"
      ],
      "centuries": [
        "18世紀"
      ],
      "regions": [
        "イギリス"
      ],
      "traditions": [
        "啓蒙思想",
        "フェミニズム"
      ],
      "source": "https://plato.stanford.edu/entries/wollstonecraft/",
      "note": ""
    },
    "centuries": [
      "18世紀"
    ],
    "genres": [
      "政治哲学",
      "倫理学"
    ],
    "source": "https://plato.stanford.edu/entries/wollstonecraft/",
    "note": "1792年。"
  },
  {
    "id": "bacon:novum-organum",
    "title": "ノヴム・オルガヌム",
    "original_title": "Novum Organum",
    "author_info": {
      "id": "bacon",
      "name": "フランシス・ベーコン",
      "aliases": [
        "Francis Bacon"
      ],
      "centuries": [
        "16世紀",
        "17世紀"
      ],
      "regions": [
        "イングランド"
      ],
      "traditions": [
        "経験論"
      ],
      "source": "https://plato.stanford.edu/entries/francis-bacon/",
      "note": ""
    },
    "centuries": [
      "17世紀"
    ],
    "genres": [
      "認識論",
      "科学哲学"
    ],
    "source": "https://plato.stanford.edu/entries/francis-bacon/",
    "note": "1620年。"
  }
]''';
