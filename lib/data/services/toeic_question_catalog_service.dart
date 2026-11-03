abstract interface class ToeicQuestionCatalogService {
  List<Map<String, Object?>> loadQuestions();
}

/// ETS等の公式問題を転載せず、このアプリ用に独自作成した練習問題カタログ。
class LocalToeicQuestionCatalogService implements ToeicQuestionCatalogService {
  const LocalToeicQuestionCatalogService();

  @override
  List<Map<String, Object?>> loadQuestions() => _questions;

  static const List<Map<String, Object?>> _questions = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'p5-verb-01',
      'part': 'part5',
      'category': '動詞の形',
      'prompt':
          'The sales team _____ the revised proposal to the client yesterday.',
      'choices': <String>['send', 'sent', 'sending', 'will send'],
      'answer_index': 1,
      'explanation': 'yesterday があるため過去形 sent が適切です。',
    },
    <String, Object?>{
      'id': 'p5-word-02',
      'part': 'part5',
      'category': '語彙',
      'prompt': 'Please submit your travel receipts _____ five business days.',
      'choices': <String>['within', 'during', 'among', 'until'],
      'answer_index': 0,
      'explanation': '「5営業日以内に」は within five business days と表します。',
    },
    <String, Object?>{
      'id': 'p5-conjunction-03',
      'part': 'part5',
      'category': '接続詞',
      'prompt':
          '_____ the weather was poor, the outdoor event attracted many visitors.',
      'choices': <String>['Despite', 'Although', 'Because of', 'Unless'],
      'answer_index': 1,
      'explanation': '後ろが主語＋動詞の節なので Although を使います。',
    },
    <String, Object?>{
      'id': 'p5-adverb-04',
      'part': 'part5',
      'category': '品詞',
      'prompt':
          'The new booking system is _____ easier to use than the previous one.',
      'choices': <String>[
        'significant',
        'significance',
        'significantly',
        'signify',
      ],
      'answer_index': 2,
      'explanation': '比較級 easier を修飾する副詞 significantly が適切です。',
    },
    <String, Object?>{
      'id': 'p6-context-01',
      'part': 'part6',
      'category': '文脈',
      'passage':
          'To all staff: The third-floor meeting rooms will be unavailable on Friday while new video equipment is installed.',
      'prompt': 'Employees are _____ to reserve rooms on another floor.',
      'choices': <String>['advised', 'advising', 'advice', 'advisor'],
      'answer_index': 0,
      'explanation': 'be advised to do で「〜するよう勧められる」という表現です。',
    },
    <String, Object?>{
      'id': 'p6-transition-02',
      'part': 'part6',
      'category': 'つなぎ語',
      'passage':
          'Demand for the workshop exceeded our expectations. Every seat was reserved by Tuesday.',
      'prompt': '_____, we have scheduled a second session for next month.',
      'choices': <String>['However', 'As a result', 'For example', 'Meanwhile'],
      'answer_index': 1,
      'explanation': '満席になった結果、追加開催した流れなので As a result が適切です。',
    },
    <String, Object?>{
      'id': 'p6-tense-03',
      'part': 'part6',
      'category': '時制',
      'passage':
          'Thank you for ordering from Green Office Supply. Your package left our warehouse this morning.',
      'prompt': 'It _____ at your office by 4:00 P.M. tomorrow.',
      'choices': <String>['arrives', 'arrived', 'will arrive', 'has arrived'],
      'answer_index': 2,
      'explanation': 'tomorrow の未来の予定なので will arrive が適切です。',
    },
    <String, Object?>{
      'id': 'p6-word-04',
      'part': 'part6',
      'category': '語彙',
      'passage':
          'The east entrance is temporarily closed for repairs. Signs have been placed near the parking area.',
      'prompt': 'Please _____ the signs to the west entrance.',
      'choices': <String>['follow', 'attend', 'reach', 'carry'],
      'answer_index': 0,
      'explanation': '案内表示に従う、は follow the signs と表します。',
    },
    <String, Object?>{
      'id': 'p7-purpose-01',
      'part': 'part7',
      'category': '目的',
      'passage':
          'From: Mina Patel\nSubject: Friday client visit\n\nThe clients from West Bay Foods will arrive at 10:30 on Friday. Please move our weekly team meeting to Conference Room B and leave Conference Room A available for the visitors. Ken will greet them in the lobby and begin the product demonstration at 11:00.',
      'prompt': 'Why was the message written?',
      'choices': <String>[
        'To cancel a product demonstration',
        'To announce arrangements for a client visit',
        'To request a weekly sales report',
        'To invite staff to visit West Bay Foods',
      ],
      'answer_index': 1,
      'explanation': '来客に伴う会議室変更や担当者を伝えることがメールの目的です。',
    },
    <String, Object?>{
      'id': 'p7-detail-02',
      'part': 'part7',
      'category': '詳細情報',
      'passage':
          'From: Mina Patel\nSubject: Friday client visit\n\nThe clients from West Bay Foods will arrive at 10:30 on Friday. Please move our weekly team meeting to Conference Room B and leave Conference Room A available for the visitors. Ken will greet them in the lobby and begin the product demonstration at 11:00.',
      'prompt': 'What will Ken most likely do at 10:30?',
      'choices': <String>[
        'Lead the weekly team meeting',
        'Prepare a sales report',
        'Meet the visitors in the lobby',
        'Reserve Conference Room B',
      ],
      'answer_index': 2,
      'explanation': '本文に Ken will greet them in the lobby とあります。',
    },
    <String, Object?>{
      'id': 'p7-inference-03',
      'part': 'part7',
      'category': '推測',
      'passage':
          'Riverside Fitness is looking for a part-time front desk assistant. Applicants should be available from 5:00 P.M. to 9:00 P.M. on at least three weekdays. Experience in customer service is preferred but not required. Complimentary gym membership is included. Apply by September 12 at jobs@riverside.example.',
      'prompt': 'What is indicated about the position?',
      'choices': <String>[
        'It requires weekend work.',
        'It includes access to the gym.',
        'It is a full-time position.',
        'It requires previous fitness-industry experience.',
      ],
      'answer_index': 1,
      'explanation': 'Complimentary gym membership is included と明記されています。',
    },
    <String, Object?>{
      'id': 'p7-deadline-04',
      'part': 'part7',
      'category': '日付・期限',
      'passage':
          'Riverside Fitness is looking for a part-time front desk assistant. Applicants should be available from 5:00 P.M. to 9:00 P.M. on at least three weekdays. Experience in customer service is preferred but not required. Complimentary gym membership is included. Apply by September 12 at jobs@riverside.example.',
      'prompt': 'By when should an application be sent?',
      'choices': <String>[
        'September 5',
        'September 9',
        'September 12',
        'September 15',
      ],
      'answer_index': 2,
      'explanation': '最後の文に Apply by September 12 とあります。',
    },
  ];
}
