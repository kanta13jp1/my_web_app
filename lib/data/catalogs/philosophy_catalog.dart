import 'dart:convert';
import '../../domain/models/philosophy_reading.dart';

// Factual metadata only; attribution sources and edition sources are separate.
const philosophyCatalogVersion = '2026-10-12-remaining-japanese-editions';

class PhilosophyCatalogEdition {
  const PhilosophyCatalogEdition(
    this.workId,
    this.label,
    this.edition, {
    this.note = '',
  });
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
  PhilosophyCatalogEdition(
    'aristotle:metaphysics',
    '形而上学・講談社（講談社学術文庫）',
    ReadingEdition(
      publisher: '講談社',
      translator: '岩崎勉',
      year: '1994',
      isbn: '9784061591165',
      volume: '講談社学術文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002316016',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784061591165',
    ),
  ),
  PhilosophyCatalogEdition(
    'zhuangzi:zhuangzi',
    '荘子. 内篇・筑摩書房（ちくま学芸文庫 ; ソ4-1）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '福永光司・興膳宏',
      year: '2013',
      isbn: '9784480095404',
      volume: '内篇・ちくま学芸文庫 ; ソ4-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024645573',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480095404',
    ),
  ),
  PhilosophyCatalogEdition(
    'zhuangzi:zhuangzi',
    '荘子. 外篇・筑摩書房（ちくま学芸文庫 ; ソ4-2）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '福永光司・興膳宏',
      year: '2013',
      isbn: '9784480095411',
      volume: '外篇・ちくま学芸文庫 ; ソ4-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024714438',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480095411',
    ),
  ),
  PhilosophyCatalogEdition(
    'zhuangzi:zhuangzi',
    '荘子. 雑篇・筑摩書房（ちくま学芸文庫 ; ソ4-3）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '福永光司・興膳宏',
      year: '2013',
      isbn: '9784480095428',
      volume: '雑篇・ちくま学芸文庫 ; ソ4-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024799791',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480095428',
    ),
  ),
  PhilosophyCatalogEdition(
    'zhuangzi:zhuangzi',
    '荘子 : 全現代語訳. 上・講談社（講談社学術文庫 ; 2429）',
    ReadingEdition(
      publisher: '講談社',
      translator: '池田知久',
      year: '2017',
      isbn: '9784062924290',
      volume: '上・講談社学術文庫 ; 2429',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028136294',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784062924290',
    ),
  ),
  PhilosophyCatalogEdition(
    'zhuangzi:zhuangzi',
    '荘子 : 全現代語訳. 下・講談社（講談社学術文庫 ; 2430）',
    ReadingEdition(
      publisher: '講談社',
      translator: '池田知久',
      year: '2017',
      isbn: '9784062924306',
      volume: '下・講談社学術文庫 ; 2430',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028199639',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784062924306',
    ),
  ),
  PhilosophyCatalogEdition(
    'spinoza:ethics',
    'エティカ・中央公論新社（中公クラシックス ; W48）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '工藤喜作・斎藤博',
      year: '2007',
      isbn: '9784121600943',
      volume: '中公クラシックス ; W48',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008440421',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600943',
    ),
  ),
  PhilosophyCatalogEdition(
    'spinoza:ethics',
    'スピノザ全集. 3・岩波書店',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '上野修（翻訳・解説）',
      editor: '上野修・鈴木泉（編）',
      year: '2022',
      isbn: '9784000928533',
      volume: '3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032507023',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784000928533',
    ),
  ),
  PhilosophyCatalogEdition(
    'hume:treatise',
    '人間本性論. 第1巻・法政大学出版局',
    ReadingEdition(
      publisher: '法政大学出版局',
      translator: '木曾好能',
      year: '2019',
      isbn: '9784588121913',
      volume: '第1巻',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I029624544',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784588121913',
    ),
  ),
  PhilosophyCatalogEdition(
    'hume:treatise',
    '人間本性論. 第2巻・法政大学出版局',
    ReadingEdition(
      publisher: '法政大学出版局',
      translator: '石川徹・中釜浩一・伊勢俊彦',
      year: '2019',
      isbn: '9784588121920',
      volume: '第2巻',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I029790817',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784588121920',
    ),
  ),
  PhilosophyCatalogEdition(
    'hume:treatise',
    '人間本性論. 第3巻・法政大学出版局',
    ReadingEdition(
      publisher: '法政大学出版局',
      translator: '伊勢俊彦・石川徹・中釜浩一',
      year: '2019',
      isbn: '9784588121937',
      volume: '第3巻',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I030009469',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784588121937',
    ),
  ),
  PhilosophyCatalogEdition(
    'nishida:inquiry',
    '善の研究・岩波書店（岩波文庫 ; 33-124-1）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '2012',
      isbn: '9784003312414',
      volume: '岩波文庫 ; 33-124-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I023002681',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003312414',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'nishida:inquiry',
    '善の研究・講談社（講談社学術文庫）',
    ReadingEdition(
      publisher: '講談社',
      year: '2006',
      isbn: '9784061597815',
      volume: '講談社学術文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008297676',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784061597815',
    ),
    note: '日本語原著の版。訳者なし。小坂国継による全注釈。',
  ),
  PhilosophyCatalogEdition(
    'beauvoir:second-sex',
    '第二の性. 1・河出書房新社（河出文庫 ; ホ7-1）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '『第二の性』を原文で読み直す会',
      year: '2023',
      isbn: '9784309467795',
      volume: '1・河出文庫 ; ホ7-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032666232',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309467795',
    ),
  ),
  PhilosophyCatalogEdition(
    'beauvoir:second-sex',
    '第二の性. 2[-1]・河出書房新社（河出文庫 ; ホ7-2）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '『第二の性』を原文で読み直す会',
      year: '2023',
      isbn: '9784309467801',
      volume: '2[-1]・河出文庫 ; ホ7-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032728084',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309467801',
    ),
  ),
  PhilosophyCatalogEdition(
    'beauvoir:second-sex',
    '第二の性. 2[-2]・河出書房新社（河出文庫 ; ホ7-3）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '『第二の性』を原文で読み直す会',
      year: '2023',
      isbn: '9784309467818',
      volume: '2[-2]・河出文庫 ; ホ7-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032728085',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309467818',
    ),
  ),
  PhilosophyCatalogEdition(
    'epicurus:menoeceus',
    '自然について他・京都大学学術出版会（西洋古典叢書 ; G124）',
    ReadingEdition(
      publisher: '京都大学学術出版会',
      translator: '朴一功・和田利博',
      year: '2025',
      isbn: '9784814005598',
      volume: '西洋古典叢書 ; G124',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I034002308',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784814005598',
    ),
    note: '『自然について 他』に収録。選集全体のISBN。',
  ),
  PhilosophyCatalogEdition(
    'marcus-aurelius:meditations',
    '自省録・京都大学学術出版会（西洋古典叢書 ; 第1期）',
    ReadingEdition(
      publisher: '京都大学学術出版会',
      translator: '水地宗明',
      year: '1998',
      isbn: '9784876981090',
      volume: '西洋古典叢書 ; 第1期',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002682260',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784876981090',
    ),
  ),
  PhilosophyCatalogEdition(
    'marcus-aurelius:meditations',
    'マルクス・アウレリウス「自省録」・講談社（講談社学術文庫）',
    ReadingEdition(
      publisher: '講談社',
      translator: '鈴木照雄',
      year: '2006',
      isbn: '9784061597495',
      volume: '講談社学術文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008091872',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784061597495',
    ),
  ),
  PhilosophyCatalogEdition(
    'augustine:confessions',
    '告白録・教文館（キリスト教古典叢書）',
    ReadingEdition(
      publisher: '教文館',
      translator: '宮谷宣史',
      year: '2012',
      isbn: '9784764218048',
      volume: 'キリスト教古典叢書',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I023440249',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784764218048',
    ),
  ),
  PhilosophyCatalogEdition(
    'augustine:city-of-god',
    '神の国・教文館（キリスト教古典叢書）',
    ReadingEdition(
      publisher: '教文館',
      translator: '金子晴勇ほか',
      year: '2014',
      isbn: '9784764218079',
      volume: '上・キリスト教古典叢書',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025164102',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784764218079',
    ),
  ),
  PhilosophyCatalogEdition(
    'augustine:city-of-god',
    '神の国・教文館（キリスト教古典叢書）',
    ReadingEdition(
      publisher: '教文館',
      translator: '泉治典ほか',
      year: '2014',
      isbn: '9784764218086',
      volume: '下・キリスト教古典叢書',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025363487',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784764218086',
    ),
  ),
  PhilosophyCatalogEdition(
    'plotinus:enneads',
    'エネアデス(抄). 1・中央公論新社（中公クラシックス ; W50）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '田中美知太郎・水地宗明・田之頭安彦',
      editor: 'ポルピュリオス（編纂）',
      year: '2007',
      isbn: '9784121600998',
      volume: '1・中公クラシックス ; W50',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009193767',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600998',
    ),
    note: '『エネアデス抄』の抄訳。原著全体の完訳ではありません。',
  ),
  PhilosophyCatalogEdition(
    'plotinus:enneads',
    'エネアデス(抄). 2・中央公論新社（中公クラシックス ; W51）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '田中美知太郎・水地宗明・田之頭安彦',
      editor: 'ポルピュリオス（編纂）',
      year: '2007',
      isbn: '9784121601001',
      volume: '2・中公クラシックス ; W51',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009193770',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121601001',
    ),
    note: '『エネアデス抄』の抄訳。原著全体の完訳ではありません。',
  ),
  PhilosophyCatalogEdition(
    'mozi:mozi',
    '墨子・中央公論新社（中公クラシックス ; E16）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '金谷治',
      year: '2018',
      isbn: '9784121601797',
      volume: '中公クラシックス ; E16',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028810092',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121601797',
    ),
  ),
  PhilosophyCatalogEdition(
    'wang-yangming:instructions',
    '伝習録・中央公論新社（中公クラシックス ; E12）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '溝口雄三',
      year: '2005',
      isbn: '9784121600820',
      volume: '中公クラシックス ; E12',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007963657',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600820',
    ),
  ),
  PhilosophyCatalogEdition(
    'vasubandhu:twenty-verses',
    '大乗仏典. 15・中央公論新社（中公文庫）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '長尾雅人・梶山雄一・荒牧典俊',
      year: '2005',
      isbn: '9784122044807',
      volume: '15・中公文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007659656',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784122044807',
    ),
    note: '『大乗仏典15 世親論集』に唯識二十論を収録。訳者は論集全体の書誌表記。',
  ),
  PhilosophyCatalogEdition(
    'vasubandhu:thirty-verses',
    '大乗仏典. 15・中央公論新社（中公文庫）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '長尾雅人・梶山雄一・荒牧典俊',
      year: '2005',
      isbn: '9784122044807',
      volume: '15・中公文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007659656',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784122044807',
    ),
    note: '『大乗仏典15 世親論集』に唯識三十論を収録。訳者は論集全体の書誌表記。同じ書籍のISBN。',
  ),
  PhilosophyCatalogEdition(
    'kukai:sokushin-jobutsu',
    '空海コレクション. 2・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '頼富本宏（訳注）',
      year: '2004',
      isbn: '9784480087621',
      volume: '2・ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007586969',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480087621',
    ),
    note: '『空海コレクション2』に収録。即身成仏義の訳注は頼富本宏。宮坂宥勝は監修者。',
  ),
  PhilosophyCatalogEdition(
    'dogen:shobogenzo',
    '正法眼蔵 : 現代文訳. 1・河出書房新社（河出文庫）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '石井恭二',
      year: '2004',
      isbn: '9784309407197',
      volume: '1・河出文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007407975',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309407197',
    ),
  ),
  PhilosophyCatalogEdition(
    'dogen:shobogenzo',
    '正法眼蔵 : 現代文訳. 2・河出書房新社（河出文庫）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '石井恭二',
      year: '2004',
      isbn: '9784309407203',
      volume: '2・河出文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007452020',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309407203',
    ),
  ),
  PhilosophyCatalogEdition(
    'dogen:shobogenzo',
    '正法眼蔵 : 現代文訳. 3・河出書房新社（河出文庫）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '石井恭二',
      year: '2004',
      isbn: '9784309407210',
      volume: '3・河出文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007478677',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309407210',
    ),
  ),
  PhilosophyCatalogEdition(
    'dogen:shobogenzo',
    '正法眼蔵 : 現代文訳. 4・河出書房新社（河出文庫）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '石井恭二',
      year: '2004',
      isbn: '9784309407227',
      volume: '4・河出文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007509820',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309407227',
    ),
  ),
  PhilosophyCatalogEdition(
    'dogen:shobogenzo',
    '正法眼蔵 : 現代文訳. 5・河出書房新社（河出文庫）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '石井恭二',
      year: '2004',
      isbn: '9784309407234',
      volume: '5・河出文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007546610',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309407234',
    ),
  ),
  PhilosophyCatalogEdition(
    'watsuji:ethics',
    '倫理学. 1・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '2007',
      isbn: '9784003314494',
      volume: '1・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008451599',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003314494',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'watsuji:ethics',
    '倫理学. 2・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '2007',
      isbn: '9784003811016',
      volume: '2・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008473041',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003811016',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'watsuji:ethics',
    '倫理学. 3・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '2007',
      isbn: '9784003811023',
      volume: '3・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008505930',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003811023',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'watsuji:ethics',
    '倫理学. 4・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '2007',
      isbn: '9784003811030',
      volume: '4・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008531489',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003811030',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'watsuji:climate',
    '風土 : 人間学的考察・岩波書店（ワイド版岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      year: '1991',
      isbn: '9784000070720',
      volume: 'ワイド版岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002152790',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784000070720',
    ),
    note: '日本語原著の版。訳者なし。',
  ),
  PhilosophyCatalogEdition(
    'locke:government',
    '完訳統治二論・岩波書店（岩波文庫 ; 34-007-7）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '加藤節',
      year: '2010',
      isbn: '9784003400777',
      volume: '岩波文庫 ; 34-007-7',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000011056064',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003400777',
    ),
  ),
  PhilosophyCatalogEdition(
    'leibniz:monadology',
    'モナドロジー : 他二篇・岩波書店（岩波文庫 ; 33-616-1）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '谷川多佳子・岡部英男',
      year: '2019',
      isbn: '9784003361696',
      volume: '岩波文庫 ; 33-616-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I029584850',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003361696',
    ),
  ),
  PhilosophyCatalogEdition(
    'leibniz:monadology',
    'モナドロジー ; 形而上学叙説・中央公論新社（中公クラシックス）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '清水富雄・竹田篤司',
      year: '2005',
      isbn: '9784121600745',
      volume: '中公クラシックス',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007659755',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600745',
    ),
    note: '『モナドロジー・形而上学叙説』に収録。モナドロジーの訳者を記録。',
  ),
  PhilosophyCatalogEdition(
    'hegel:phenomenology',
    '精神現象学. 上・筑摩書房（ちくま学芸文庫 ; へ10-1）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '熊野純彦',
      year: '2018',
      isbn: '9784480097019',
      volume: '上・ちくま学芸文庫 ; へ10-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I029363965',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480097019',
    ),
  ),
  PhilosophyCatalogEdition(
    'hegel:phenomenology',
    '精神現象学. 下・筑摩書房（ちくま学芸文庫 ; へ10-2）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '熊野純彦',
      year: '2018',
      isbn: '9784480097026',
      volume: '下・ちくま学芸文庫 ; へ10-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I029363966',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480097026',
    ),
  ),
  PhilosophyCatalogEdition(
    'hegel:phenomenology',
    '精神現象学・作品社',
    ReadingEdition(
      publisher: '作品社',
      translator: '長谷川宏',
      year: '1998',
      isbn: '9784878932946',
      volume: '精神現象学',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002670845',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784878932946',
    ),
  ),
  PhilosophyCatalogEdition(
    'epictetus:discourses',
    '語録 要録・中央公論新社（中公クラシックス ; W92）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '鹿野治助',
      year: '2017',
      isbn: '9784121601728',
      volume: '中公クラシックス ; W92',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028004986',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121601728',
    ),
    note: '『語録 要録』に収録。選集の収録範囲は出典で確認してください。',
  ),
  PhilosophyCatalogEdition(
    'epictetus:enchiridion',
    '語録 要録・中央公論新社（中公クラシックス ; W92）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '鹿野治助',
      year: '2017',
      isbn: '9784121601728',
      volume: '中公クラシックス ; W92',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028004986',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121601728',
    ),
    note: '『語録 要録』所収の「要録」（提要）。語録と同じ書籍のISBN。',
  ),
  PhilosophyCatalogEdition(
    'locke:understanding',
    '人間知性論. 2・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '大槻春彦',
      year: '1997',
      isbn: '9784003400722',
      volume: '2・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002719746',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003400722',
    ),
    note: '第2巻のみ。原著全体を読むには他の巻も必要です。',
  ),
  PhilosophyCatalogEdition(
    'marx:capital',
    '資本論 : 経済学批判. 第1巻(第1部 上巻)・績文堂出版',
    ReadingEdition(
      publisher: '績文堂出版',
      translator: '長谷部文雄',
      editor: 'フリードリッヒ・エンゲルス',
      year: '2006',
      isbn: '9784881160237',
      volume: '第1巻(第1部 上巻)',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009103057',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784881160237',
    ),
  ),
  PhilosophyCatalogEdition(
    'marx:capital',
    '資本論 : 経済学批判. 第2巻(第1部 下巻)・績文堂出版',
    ReadingEdition(
      publisher: '績文堂出版',
      translator: '長谷部文雄',
      editor: 'フリードリッヒ・エンゲルス',
      year: '2006',
      isbn: '9784881160244',
      volume: '第2巻(第1部 下巻)',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009103047',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784881160244',
    ),
  ),
  PhilosophyCatalogEdition(
    'marx:capital',
    '資本論 : 経済学批判. 第3巻(第2部)・績文堂出版',
    ReadingEdition(
      publisher: '績文堂出版',
      translator: '長谷部文雄',
      editor: 'フリードリッヒ・エンゲルス',
      year: '2006',
      isbn: '9784881160251',
      volume: '第3巻(第2部)',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009103027',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784881160251',
    ),
  ),
  PhilosophyCatalogEdition(
    'marx:capital',
    '資本論 : 経済学批判. 第4巻(第3部 上巻)・績文堂出版',
    ReadingEdition(
      publisher: '績文堂出版',
      translator: '長谷部文雄',
      editor: 'フリードリッヒ・エンゲルス',
      year: '2006',
      isbn: '9784881160268',
      volume: '第4巻(第3部 上巻)',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009103002',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784881160268',
    ),
  ),
  PhilosophyCatalogEdition(
    'marx:capital',
    '資本論 : 経済学批判. 第5巻(第3部 下巻)・績文堂出版',
    ReadingEdition(
      publisher: '績文堂出版',
      translator: '長谷部文雄',
      editor: 'フリードリッヒ・エンゲルス',
      year: '2006',
      isbn: '9784881160275',
      volume: '第5巻(第3部 下巻)',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009102984',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784881160275',
    ),
  ),
  PhilosophyCatalogEdition(
    'husserl:logical-investigations',
    '論理学研究. 1・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '立松弘孝',
      year: '2015',
      isbn: '9784622079514',
      volume: '1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I026748760',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622079514',
    ),
  ),
  PhilosophyCatalogEdition(
    'husserl:logical-investigations',
    '論理学研究. 2・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '立松弘孝・松井良和・赤松宏',
      year: '2015',
      isbn: '9784622079521',
      volume: '2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I026748761',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622079521',
    ),
  ),
  PhilosophyCatalogEdition(
    'husserl:logical-investigations',
    '論理学研究. 3・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '立松弘孝・松井良和',
      year: '2015',
      isbn: '9784622079538',
      volume: '3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I026748763',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622079538',
    ),
  ),
  PhilosophyCatalogEdition(
    'husserl:logical-investigations',
    '論理学研究. 4・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '立松弘孝',
      year: '2015',
      isbn: '9784622079545',
      volume: '4',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I026748765',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622079545',
    ),
  ),
  PhilosophyCatalogEdition(
    'husserl:ideas',
    'イデーン : 純粋現象学と現象学的哲学のための諸構想. 1-2・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '渡辺二郎',
      year: '1984',
      isbn: '9784622019176',
      volume: '1-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000001682045',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622019176',
    ),
    note: 'イデーン第1巻の後半（1-2）のみ。イデーンII・IIIとは別著作です。',
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間. 1・岩波書店（岩波文庫 ; 33-651-1）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '熊野純彦',
      year: '2013',
      isbn: '9784003365144',
      volume: '1・岩波文庫 ; 33-651-1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024369563',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003365144',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間. 2・岩波書店（岩波文庫 ; 33-651-2）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '熊野純彦',
      year: '2013',
      isbn: '9784003365151',
      volume: '2・岩波文庫 ; 33-651-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024460797',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003365151',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間. 3・岩波書店（岩波文庫 ; 33-651-3）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '熊野純彦',
      year: '2013',
      isbn: '9784003365168',
      volume: '3・岩波文庫 ; 33-651-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024810234',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003365168',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間. 4・岩波書店（岩波文庫 ; 33-651-4）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '熊野純彦',
      year: '2013',
      isbn: '9784003365175',
      volume: '4・岩波文庫 ; 33-651-4',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025040393',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003365175',
    ),
  ),
  PhilosophyCatalogEdition(
    'wittgenstein:tractatus',
    '論理哲学論考・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '野矢茂樹',
      year: '2003',
      isbn: '9784003368916',
      volume: '岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000004221640',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003368916',
    ),
  ),
  PhilosophyCatalogEdition(
    'wittgenstein:tractatus',
    '論理哲学論考・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '中平浩司',
      year: '2005',
      isbn: '9784480089205',
      volume: 'ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007796799',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480089205',
    ),
  ),
  PhilosophyCatalogEdition(
    'wittgenstein:investigations',
    '哲学探究・講談社',
    ReadingEdition(
      publisher: '講談社',
      translator: '鬼界彰夫',
      year: '2020',
      isbn: '9784062199445',
      volume: '哲学探究',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I030721394',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784062199445',
    ),
  ),
  PhilosophyCatalogEdition(
    'sartre:being-nothingness',
    '存在と無 : 現象学的存在論の試み. 1・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '松浪信三郎',
      year: '2007',
      isbn: '9784480091062',
      volume: '1・ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009208971',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480091062',
    ),
  ),
  PhilosophyCatalogEdition(
    'sartre:being-nothingness',
    '存在と無 : 現象学的存在論の試み. 2・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '松浪信三郎',
      year: '2007',
      isbn: '9784480091079',
      volume: '2・ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009208963',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480091079',
    ),
  ),
  PhilosophyCatalogEdition(
    'sartre:being-nothingness',
    '存在と無 : 現象学的存在論の試み. 3・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '松浪信三郎',
      year: '2008',
      isbn: '9784480091086',
      volume: '3・ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009265216',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480091086',
    ),
  ),
  PhilosophyCatalogEdition(
    'arendt:totalitarianism',
    '全体主義の起原. 1・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '大久保和郎',
      year: '2017',
      isbn: '9784622086253',
      volume: '1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028436571',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622086253',
    ),
  ),
  PhilosophyCatalogEdition(
    'arendt:totalitarianism',
    '全体主義の起原. 2・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '大島通義・大島かおり',
      year: '2017',
      isbn: '9784622086260',
      volume: '2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028436572',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622086260',
    ),
  ),
  PhilosophyCatalogEdition(
    'arendt:totalitarianism',
    '全体主義の起原. 3・みすず書房',
    ReadingEdition(
      publisher: 'みすず書房',
      translator: '大久保和郎・大島かおり',
      year: '2017',
      isbn: '9784622086277',
      volume: '3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028436574',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784622086277',
    ),
  ),
  PhilosophyCatalogEdition(
    'foucault:discipline',
    '監獄の誕生 : 監視と処罰・新潮社',
    ReadingEdition(
      publisher: '新潮社',
      translator: '田村俶',
      year: '2020',
      isbn: '9784105067090',
      volume: '監獄の誕生 : 監視と処罰',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I030367995',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784105067090',
    ),
  ),
  PhilosophyCatalogEdition(
    'foucault:sexuality',
    '性の歴史. 1・新潮社',
    ReadingEdition(
      publisher: '新潮社',
      translator: '渡辺守章',
      year: '1986',
      isbn: '9784105067045',
      volume: '1',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000001815311',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784105067045',
    ),
  ),
  PhilosophyCatalogEdition(
    'foucault:sexuality',
    '性の歴史. 2・新潮社',
    ReadingEdition(
      publisher: '新潮社',
      translator: '田村俶',
      year: '1986',
      isbn: '9784105067052',
      volume: '2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000001823859',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784105067052',
    ),
  ),
  PhilosophyCatalogEdition(
    'foucault:sexuality',
    '性の歴史. 3・新潮社',
    ReadingEdition(
      publisher: '新潮社',
      translator: '田村俶',
      year: '1987',
      isbn: '9784105067069',
      volume: '3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000001856697',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784105067069',
    ),
  ),
  PhilosophyCatalogEdition(
    'foucault:sexuality',
    '性の歴史. 4・新潮社',
    ReadingEdition(
      publisher: '新潮社',
      translator: '慎改康之',
      editor: 'フレデリック・グロ（編）',
      year: '2020',
      isbn: '9784105067120',
      volume: '4',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I030805087',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784105067120',
    ),
  ),
  PhilosophyCatalogEdition(
    'rawls:justice',
    '正義論・紀伊國屋書店',
    ReadingEdition(
      publisher: '紀伊國屋書店',
      translator: '川本隆史・福間聡・神島裕子',
      year: '2010',
      isbn: '9784314010740',
      volume: '正義論',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000011058939',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784314010740',
    ),
  ),
  PhilosophyCatalogEdition(
    'rawls:political-liberalism',
    '政治的リベラリズム・筑摩書房',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '神島裕子・福間聡',
      year: '2022',
      isbn: '9784480867377',
      volume: '政治的リベラリズム',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I031889444',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480867377',
    ),
  ),
  PhilosophyCatalogEdition(
    'sen:idea-justice',
    '正義のアイデア・明石書店',
    ReadingEdition(
      publisher: '明石書店',
      translator: '池本幸生',
      year: '2011',
      isbn: '9784750334943',
      volume: '正義のアイデア',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I023183704',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784750334943',
    ),
  ),
  PhilosophyCatalogEdition(
    'hobbes:leviathan',
    'リヴァイアサン. 上・筑摩書房（ちくま学芸文庫 ; ホ22-2）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '加藤節',
      year: '2022',
      isbn: '9784480511430',
      volume: '上・ちくま学芸文庫 ; ホ22-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032518112',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480511430',
    ),
  ),
  PhilosophyCatalogEdition(
    'hobbes:leviathan',
    'リヴァイアサン. 下・筑摩書房（ちくま学芸文庫 ; ホ22-3）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '加藤節',
      year: '2022',
      isbn: '9784480511478',
      volume: '下・ちくま学芸文庫 ; ホ22-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032518113',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480511478',
    ),
  ),
  PhilosophyCatalogEdition(
    'mill:utilitarianism',
    '功利主義・岩波書店（岩波文庫 ; 34-116-11）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '関口正司',
      year: '2021',
      isbn: '9784003900048',
      volume: '岩波文庫 ; 34-116-11',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I031411590',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003900048',
    ),
  ),
  PhilosophyCatalogEdition(
    'mill:utilitarianism',
    '功利主義・日経BP（NIKKEI BP CLASSICS）',
    ReadingEdition(
      publisher: '日経BP',
      translator: '中山元',
      year: '2023',
      isbn: '9784296001729',
      volume: 'NIKKEI BP CLASSICS',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I033151088',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784296001729',
    ),
  ),
  PhilosophyCatalogEdition(
    'bacon:novum-organum',
    'ベーコン・河出書房新社（世界の大思想 : ワイド版 ; 2-4）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '服部英次郎',
      year: '2005',
      isbn: '9784309961842',
      volume: '世界の大思想 : ワイド版 ; 2-4',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007630203',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309961842',
    ),
    note: '『世界の大思想2-4 ベーコン』に収録。ノヴム・オルガヌムの訳者は服部英次郎。',
  ),
  PhilosophyCatalogEdition(
    'boethius:consolation',
    '哲学の慰め・講談社（講談社学術文庫 ; 2916）',
    ReadingEdition(
      publisher: '講談社',
      translator: '畠中尚志',
      year: '2026',
      isbn: '9784065433539',
      volume: '講談社学術文庫 ; 2916',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I034650700',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784065433539',
    ),
  ),
  PhilosophyCatalogEdition(
    'boethius:consolation',
    '哲学のなぐさめ・京都大学学術出版会（西洋古典叢書 ; L037）',
    ReadingEdition(
      publisher: '京都大学学術出版会',
      translator: '松﨑一平',
      year: '2023',
      isbn: '9784814004249',
      volume: '西洋古典叢書 ; L037',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032593314',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784814004249',
    ),
  ),
  PhilosophyCatalogEdition(
    'aquinas:summa',
    '精選神学大全. 1・岩波書店（岩波文庫 ; 33-621-3）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '稲垣良典',
      editor: '稲垣良典・山本芳久',
      year: '2023',
      isbn: '9784003362136',
      volume: '1・岩波文庫 ; 33-621-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I032895844',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003362136',
    ),
    note: '『精選神学大全』の選訳。神学大全全体の完訳ではありません。',
  ),
  PhilosophyCatalogEdition(
    'aquinas:summa',
    '精選神学大全. 2・岩波書店（岩波文庫 ; 33-621-4）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '稲垣良典',
      editor: '稲垣良典・山本芳久',
      year: '2024',
      isbn: '9784003362143',
      volume: '2・岩波文庫 ; 33-621-4',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I033277850',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003362143',
    ),
    note: '『精選神学大全』の選訳。神学大全全体の完訳ではありません。',
  ),
  PhilosophyCatalogEdition(
    'mencius:mengzi',
    '孟子. 上・岩波書店（ワイド版岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '小林勝人',
      year: '1994',
      isbn: '9784000071406',
      volume: '上・ワイド版岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002354841',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784000071406',
    ),
  ),
  PhilosophyCatalogEdition(
    'mencius:mengzi',
    '孟子. 下・岩波書店（ワイド版岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '小林勝人',
      year: '1994',
      isbn: '9784000071413',
      volume: '下・ワイド版岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002354842',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784000071413',
    ),
  ),
  PhilosophyCatalogEdition(
    'xunzi:xunzi',
    '荀子. 下・岩波書店（岩波文庫）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '金谷治',
      year: '2006',
      isbn: '9784003320822',
      volume: '下・岩波文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008905290',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003320822',
    ),
  ),
  PhilosophyCatalogEdition(
    'hegel:right',
    '法の哲学 : 自然法と国家学の要綱. 上・岩波書店（岩波文庫 ; 33-630-2）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '上妻精・佐藤康邦・山田忠彰',
      year: '2021',
      isbn: '9784003363027',
      volume: '上・岩波文庫 ; 33-630-2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I031184383',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003363027',
    ),
  ),
  PhilosophyCatalogEdition(
    'hegel:right',
    '法の哲学 : 自然法と国家学の要綱. 下・岩波書店（岩波文庫 ; 33-630-3）',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '上妻精・佐藤康邦・山田忠彰',
      year: '2021',
      isbn: '9784003363034',
      volume: '下・岩波文庫 ; 33-630-3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I031339747',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003363034',
    ),
  ),
  PhilosophyCatalogEdition(
    'kierkegaard:sickness',
    '死にいたる病・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '桝田啓三郎',
      year: '1996',
      isbn: '9784480082589',
      volume: 'ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002524367',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480082589',
    ),
  ),
  PhilosophyCatalogEdition(
    'kierkegaard:sickness',
    '死にいたる病 ; 現代の批判・中央公論新社（中公クラシックス）',
    ReadingEdition(
      publisher: '中央公論新社',
      translator: '桝田啓三郎',
      year: '2003',
      isbn: '9784121600547',
      volume: '中公クラシックス',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000004176663',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600547',
    ),
  ),
  PhilosophyCatalogEdition(
    'russell:problems',
    '哲学入門・筑摩書房（ちくま学芸文庫）',
    ReadingEdition(
      publisher: '筑摩書房',
      translator: '高村夏輝',
      year: '2005',
      isbn: '9784480089045',
      volume: 'ちくま学芸文庫',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007687640',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784480089045',
    ),
  ),
  PhilosophyCatalogEdition(
    'sartre:humanism',
    '実存主義とは何か・人文書院',
    ReadingEdition(
      publisher: '人文書院',
      translator: '伊吹武彦ほか',
      year: '1996',
      isbn: '9784409030424',
      volume: '実存主義とは何か',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002481478',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784409030424',
    ),
    note: '日本語書名『実存主義とは何か』。他の文章も含む増補新版。',
  ),
  PhilosophyCatalogEdition(
    'shankara:brahmasutrabhasya',
    'ブラフマ・スートラ : シャンカラの註釈. 上・大東出版社',
    ReadingEdition(
      publisher: '大東出版社',
      translator: '湯田豊（訳著）',
      year: '2006',
      isbn: '9784500007080',
      volume: '上',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008176165',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784500007080',
    ),
    note: '出版社・NDLでは湯田豊を著者と表記。シャンカラの註釈の翻訳と研究。',
  ),
  PhilosophyCatalogEdition(
    'shankara:brahmasutrabhasya',
    'ブラフマ・スートラ : シャンカラの註釈. 下・大東出版社',
    ReadingEdition(
      publisher: '大東出版社',
      translator: '湯田豊（訳著）',
      year: '2007',
      isbn: '9784500007097',
      volume: '下',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000009154016',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784500007097',
    ),
    note: '出版社・NDLでは湯田豊を著者と表記。シャンカラの註釈の翻訳と研究。',
  ),
  PhilosophyCatalogEdition(
    'avicenna:healing',
    '魂について : 治癒の書自然学第六篇・知泉書館',
    ReadingEdition(
      publisher: '知泉書館',
      translator: '木下雄介',
      year: '2012',
      isbn: '9784862851413',
      volume: '魂について : 治癒の書自然学第六篇',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I023978877',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784862851413',
    ),
    note: '『治癒の書』の自然学第六篇（魂について）の訳。原著全体の完訳ではありません。',
  ),
  PhilosophyCatalogEdition(
    'tsongkhapa:lamrim',
    '菩提道次第大論の研究・文栄堂書店',
    ReadingEdition(
      publisher: '文栄堂書店',
      translator: 'ツルティム・ケサン・藤仲孝司',
      year: '2005',
      isbn: '9784892431012',
      volume: '菩提道次第大論の研究',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008146446',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784892431012',
    ),
    note: '訳と研究を含む分冊。各巻の収録範囲は出典で確認してください。原著全体の完訳とは扱いません。',
  ),
  PhilosophyCatalogEdition(
    'tsongkhapa:lamrim',
    '菩提道次第大論の研究. 2・UNIO',
    ReadingEdition(
      publisher: 'UNIO',
      translator: 'ツルティム・ケサン・藤仲孝司',
      year: '2014',
      isbn: '9784434198175',
      volume: '2',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025816785',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784434198175',
    ),
    note: '訳と研究を含む分冊。各巻の収録範囲は出典で確認してください。原著全体の完訳とは扱いません。',
  ),
  PhilosophyCatalogEdition(
    'tsongkhapa:lamrim',
    '菩提道次第大論の研究. 3・UNIO',
    ReadingEdition(
      publisher: 'UNIO',
      translator: 'ツルティム・ケサン・藤仲孝司',
      year: '2017',
      isbn: '9784434236181',
      volume: '3',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I028517432',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784434236181',
    ),
    note: '訳と研究を含む分冊。各巻の収録範囲は出典で確認してください。原著全体の完訳とは扱いません。',
  ),
  PhilosophyCatalogEdition(
    'kierkegaard:fear-trembling',
    'キルケゴール・河出書房新社（世界の大思想 : ワイド版 ; 12）',
    ReadingEdition(
      publisher: '河出書房新社',
      translator: '桝田啓三郎',
      year: '2004',
      isbn: '9784309961729',
      volume: '世界の大思想 : ワイド版 ; 12',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000007493799',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784309961729',
    ),
    note: '『世界の大思想12 キルケゴール』に「おそれとおののき」を収録。作品ごとの訳者を記録。',
  ),
  PhilosophyCatalogEdition(
    'zhu-xi:four-books',
    '論語集注. 1・平凡社（東洋文庫 ; 841）',
    ReadingEdition(
      publisher: '平凡社',
      translator: '土田健次郎',
      year: '2013',
      isbn: '9784582808414',
      volume: '1・東洋文庫 ; 841',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I024878602',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784582808414',
    ),
    note: '四書章句集注のうち『論語集注』のみ。大学・中庸・孟子の集注は含みません。',
  ),
  PhilosophyCatalogEdition(
    'zhu-xi:four-books',
    '論語集注. 2・平凡社（東洋文庫 ; 850）',
    ReadingEdition(
      publisher: '平凡社',
      translator: '土田健次郎',
      year: '2014',
      isbn: '9784582808506',
      volume: '2・東洋文庫 ; 850',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025516024',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784582808506',
    ),
    note: '四書章句集注のうち『論語集注』のみ。大学・中庸・孟子の集注は含みません。',
  ),
  PhilosophyCatalogEdition(
    'zhu-xi:four-books',
    '論語集注. 3・平凡社（東洋文庫 ; 854）',
    ReadingEdition(
      publisher: '平凡社',
      translator: '土田健次郎',
      year: '2014',
      isbn: '9784582808544',
      volume: '3・東洋文庫 ; 854',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I025874797',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784582808544',
    ),
    note: '四書章句集注のうち『論語集注』のみ。大学・中庸・孟子の集注は含みません。',
  ),
  PhilosophyCatalogEdition(
    'zhu-xi:four-books',
    '論語集注. 4・平凡社（東洋文庫 ; 858）',
    ReadingEdition(
      publisher: '平凡社',
      translator: '土田健次郎',
      year: '2015',
      isbn: '9784582808582',
      volume: '4・東洋文庫 ; 858',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I026095432',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784582808582',
    ),
    note: '四書章句集注のうち『論語集注』のみ。大学・中庸・孟子の集注は含みません。',
  ),
  PhilosophyCatalogEdition(
    'habermas:communicative-action',
    'コミュニケイション的行為の理論 上・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '河上倫逸・M.フーブリヒト・平井俊彦',
      year: '1985',
      isbn: '9784624010751',
      volume: '上',
      sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784624010751',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624010751',
    ),
  ),
  PhilosophyCatalogEdition(
    'habermas:communicative-action',
    'コミュニケイション的行為の理論 中・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '藤沢賢一郎・岩倉正博・徳永恂・平野嘉彦・山口節郎',
      year: '1986',
      isbn: '9784624010805',
      volume: '中',
      sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784624010805',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624010805',
    ),
  ),
  PhilosophyCatalogEdition(
    'habermas:communicative-action',
    'コミュニケイション的行為の理論 下・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '丸山高司・丸山徳次・厚東洋輔・森田数実・馬場孚瑳江・脇圭平',
      year: '1987',
      isbn: '9784624010836',
      volume: '下',
      sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784624010836',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624010836',
    ),
  ),
  PhilosophyCatalogEdition(
    'habermas:facts-norms',
    '事実性と妥当性 上・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '河上倫逸・耳野健二',
      year: '2002',
      isbn: '9784624011628',
      volume: '上',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000003615315',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624011628',
    ),
  ),
  PhilosophyCatalogEdition(
    'habermas:facts-norms',
    '事実性と妥当性 下・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '河上倫逸・耳野健二',
      year: '2003',
      isbn: '9784624011635',
      volume: '下',
      sourceUrl: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000004134229',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624011635',
    ),
  ),
  PhilosophyCatalogEdition(
    'wollstonecraft:rights-woman',
    '女性の権利の擁護・未来社',
    ReadingEdition(
      publisher: '未来社',
      translator: '白井堯子',
      year: '1980',
      isbn: '9784624500276',
      volume: '単行本',
      sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784624500276',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784624500276',
    ),
  ),
  PhilosophyCatalogEdition(
    'xunzi:xunzi',
    '荀子 上・岩波書店',
    ReadingEdition(
      publisher: '岩波書店',
      translator: '金谷治（訳注）',
      year: '1961',
      isbn: '9784003320815',
      volume: '上',
      sourceUrl: 'https://www.hanmoto.com/bd/isbn/9784003320815',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003320815',
    ),
  ),
  PhilosophyCatalogEdition(
    'wittgenstein:tractatus',
    '論理哲学論考・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '丘沢静也',
      year: '2014',
      isbn: '9784334752842',
      volume: '論理哲学論考・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book182/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752842',
    ),
  ),
  PhilosophyCatalogEdition(
    'marx:manifesto',
    '共産党宣言・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '森田成也',
      year: '2020',
      isbn: '9784334754204',
      volume: '共産党宣言・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book319/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334754204',
    ),
  ),
  PhilosophyCatalogEdition(
    'schopenhauer:world',
    '意志と表象としての世界１・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2026',
      isbn: '9784334111458',
      volume: '意志と表象としての世界１・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book443/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334111458',
    ),
    note: '中山元訳の第1巻のみ。全4巻予定の刊行中シリーズ（2026年10月12日確認）。',
  ),
  PhilosophyCatalogEdition(
    'nietzsche:genealogy',
    '道徳の系譜学・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2009',
      isbn: '9784334751852',
      volume: '道徳の系譜学・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book84/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334751852',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間８・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2020',
      isbn: '9784334754358',
      volume: '存在と時間８・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book334/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334754358',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間７・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2020',
      isbn: '9784334754235',
      volume: '存在と時間７・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book322/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334754235',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間６・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2019',
      isbn: '9784334754068',
      volume: '存在と時間６・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book305/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334754068',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間５・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2018',
      isbn: '9784334753917',
      volume: '存在と時間５・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book290/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753917',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間４・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2018',
      isbn: '9784334753757',
      volume: '存在と時間４・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book274/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753757',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間３・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2017',
      isbn: '9784334753580',
      volume: '存在と時間３・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book257/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753580',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間２・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2016',
      isbn: '9784334753382',
      volume: '存在と時間２・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book237/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753382',
    ),
  ),
  PhilosophyCatalogEdition(
    'heidegger:being-time',
    '存在と時間１・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2015',
      isbn: '9784334753177',
      volume: '存在と時間１・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book216/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753177',
    ),
  ),
  PhilosophyCatalogEdition(
    'hobbes:leviathan',
    'リヴァイアサン２・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '角田安正',
      year: '2018',
      isbn: '9784334753719',
      volume: 'リヴァイアサン２・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book270/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753719',
    ),
    note: '光文社版の第1・2巻。各巻の収録範囲は出典を確認してください。',
  ),
  PhilosophyCatalogEdition(
    'hobbes:leviathan',
    'リヴァイアサン１・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '角田安正',
      year: '2014',
      isbn: '9784334753023',
      volume: 'リヴァイアサン１・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book201/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334753023',
    ),
    note: '光文社版の第1・2巻。各巻の収録範囲は出典を確認してください。',
  ),
  PhilosophyCatalogEdition(
    'rousseau:inequality',
    '人間不平等起源論・光文社古典新訳文庫',
    ReadingEdition(
      publisher: '光文社',
      translator: '中山元',
      year: '2008',
      isbn: '9784334751623',
      volume: '人間不平等起源論・光文社古典新訳文庫',
      sourceUrl: 'https://www.kotensinyaku.jp/books/book61/',
      bookUrl: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334751623',
    ),
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
