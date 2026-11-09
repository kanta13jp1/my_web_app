class DietDebateNote {
  const DietDebateNote({
    required this.topic,
    required this.questioner,
    required this.answerer,
    required this.question,
    required this.answer,
    required this.questionOrder,
    required this.answerOrder,
  });

  static const meetingId = '121115104X01220230516';
  static const date = '2023-05-16';
  static const meeting = '参議院 文教科学委員会';
  static final billUrl = Uri.parse(
    'https://www.sangiin.go.jp/japanese/joho1/kousei/gian/211/meisai/m211080211051.htm',
  );
  final String topic;
  final String questioner;
  final String answerer;
  final String question;
  final String answer;
  final int questionOrder;
  final int answerOrder;
  String get articleId => "${meetingId}_${questionOrder.toString().padLeft(3, '0')}";

  Uri source(int order) => Uri.https('kokkai.ndl.go.jp', '/txt/$meetingId/$order');

  static DietDebateNote? forSpeech(String id) {
    for (final note in entries) {
      if (id == "${meetingId}_${note.questionOrder.toString().padLeft(3, '0')}" ||
          id == "${meetingId}_${note.answerOrder.toString().padLeft(3, '0')}") {
        return note;
      }
    }
    return null;
  }

  static const entries = [
    DietDebateNote(
      topic: '学校での対話型AIの利用',
      questioner: '伊藤孝恵',
      answerer: '永岡桂子 文部科学大臣',
      question: '生成AIを学校で積極的に使うという考えについて、大臣の見解を尋ねた。',
      answer: '情報を使いこなす力の重要性に触れ、専門家の意見と国内外の事例を集めて、学校向けの資料をまとめたいと答えた。',
      questionOrder: 139,
      answerOrder: 140,
    ),
    DietDebateNote(
      topic: '著作物の利用を続けるための再申請',
      questioner: '赤松健',
      answerer: '杉浦久弘 政府参考人',
      question: '新しい裁定制度で3年を超えて作品を利用するとき、再申請の負担を軽くできるか尋ねた。',
      answer: '再申請は可能だと説明した。前の申請資料を再利用する方法など、手続きを簡単にする工夫を検討すると答えた。',
      questionOrder: 10,
      answerOrder: 11,
    ),
  ];
}
