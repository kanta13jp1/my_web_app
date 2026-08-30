Map<String, dynamic> growthWeeklyDigestSuccessFixture() => <String, dynamic>{
      'success': true,
      'digest': <String, dynamic>{
        'currentWeek': <String, dynamic>{
          'startDate': '2026-08-23',
          'endDate': '2026-08-29',
        },
        'priorWeek': <String, dynamic>{
          'startDate': '2026-08-16',
          'endDate': '2026-08-22',
        },
        'channels': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'landing',
            'label': 'ランディングページ',
            'touches': 20,
            'signupSubmits': 1,
            'cvr': 5,
            'touchesDelta': 8,
            'signupSubmitsDelta': 1,
          },
          <String, dynamic>{
            'id': 'profile',
            'label': 'X profile',
            'touches': 15,
            'signupSubmits': 0,
            'cvr': 0,
            'touchesDelta': -5,
            'signupSubmitsDelta': -2,
          },
        ],
        'importPreviews': <Map<String, dynamic>>[],
        'signupSubmitTotal': 1,
        'signupSubmitDelta': -1,
        'referralsCompleted': 3,
        'referralsDelta': 2,
        'importCtaClicks': 3,
        'publicMemoCtaClicks': 2,
        'decision': <String, dynamic>{
          'id': 'growth-weekly:2026-08-29:profile:cvr-5',
          'week': <String, dynamic>{
            'startDate': '2026-08-23',
            'endDate': '2026-08-29',
          },
          'owner': '79edc36b-b31d-4841-a0cb-64e75b98ab3a',
          'priorityChannel': <String, dynamic>{
            'id': 'profile',
            'label': 'X profile',
          },
          'threshold': <String, dynamic>{
            'metric': 'cvr_percent',
            'operator': '>=',
            'target': 5,
            'minimumTouches': 10,
          },
          'nextAction': 'X profileのCTA導線を1つ改善し、CVR 5%以上を検証する。',
          'dueDate': '2026-09-05',
          'outcome': <String, dynamic>{
            'status': 'pending',
            'measureWeek': <String, dynamic>{
              'startDate': '2026-08-30',
              'endDate': '2026-09-05',
            },
          },
        },
        'previousDecisionOutcome': <String, dynamic>{
          'decisionId': 'growth-weekly:2026-08-22:landing:cvr-5',
          'decisionWeek': <String, dynamic>{
            'startDate': '2026-08-16',
            'endDate': '2026-08-22',
          },
          'measuredWeek': <String, dynamic>{
            'startDate': '2026-08-23',
            'endDate': '2026-08-29',
          },
          'owner': '79edc36b-b31d-4841-a0cb-64e75b98ab3a',
          'priorityChannel': <String, dynamic>{
            'id': 'landing',
            'label': 'ランディングページ',
          },
          'threshold': <String, dynamic>{
            'metric': 'cvr_percent',
            'operator': '>=',
            'target': 5,
            'minimumTouches': 10,
          },
          'nextAction': 'ランディングページのCTA導線を1つ改善し、CVR 5%以上を検証する。',
          'dueDate': '2026-08-29',
          'actual': <String, dynamic>{
            'cvr': 5,
            'touches': 20,
            'signupSubmits': 1,
          },
          'status': 'met',
        },
        'brief': 'fixture brief',
      },
    };

Map<String, dynamic> growthWeeklyDigestErrorFixture(String error) =>
    <String, dynamic>{'success': false, 'error': error};
