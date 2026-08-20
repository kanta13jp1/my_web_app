import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/affiliate_link_stats.dart';
import 'package:my_web_app/models/auction_listing.dart';
import 'package:my_web_app/models/budget_entry.dart';
import 'package:my_web_app/models/donation_project.dart';
import 'package:my_web_app/models/elearning_course.dart';
import 'package:my_web_app/models/event_ticketing_summary.dart';
import 'package:my_web_app/models/language_deck.dart';
import 'package:my_web_app/models/parking_reservation_entry.dart';
import 'package:my_web_app/models/scheduled_post_entry.dart';
import 'package:my_web_app/models/social_feed_post.dart';

/// hub_data 行 (nested metadata) を模したヘルパー。
Map<String, dynamic> row(Map<String, dynamic> metadata, {String? createdAt}) =>
    {
      'id': 'row-1',
      'created_at': createdAt ?? '2026-07-13T00:00:00Z',
      'metadata': {'user_id': 'u1', ...metadata},
    };

void main() {
  group('SocialFeedPost', () {
    test('nested metadata から本文・件数を読む', () {
      final posts = SocialFeedPost.listFromResponse({
        'posts': [
          row({'content': 'こんにちは', 'likes': 3, 'comments': 1}),
        ],
      });
      expect(posts.single.content, 'こんにちは');
      expect(posts.single.likes, 3);
      expect(posts.single.comments, 1);
    });

    test('flat キー(旧形式)でも読めるが空応答は空リスト', () {
      expect(SocialFeedPost.listFromResponse(null), isEmpty);
      final legacy = SocialFeedPost.listFromResponse({
        'posts': [
          {'id': 'x', 'content': 'flat', 'likes': 9},
        ],
      });
      expect(legacy.single.content, 'flat');
      expect(legacy.single.likes, 9);
    });
  });

  group('ScheduledPostEntry', () {
    test('platforms 配列と予約時刻を読む', () {
      final list = ScheduledPostEntry.listFromResponse({
        'posts': [
          row({
            'content': '予約投稿',
            'platforms': ['x', 'facebook'],
            'scheduled_at': '2026-07-20T10:00:00Z',
            'status': 'pending',
          }),
        ],
      });
      final p = list.single;
      expect(p.content, '予約投稿');
      expect(p.platforms, ['x', 'facebook']);
      expect(p.primaryPlatform, 'x');
      expect(p.platformsLabel, 'X / FACEBOOK');
      expect(p.displayTime, '2026-07-20T10:00:00Z');
    });

    test('予約時刻が無ければ作成時刻を使う', () {
      final list = ScheduledPostEntry.listFromResponse({
        'posts': [
          row({'content': 'x'}, createdAt: '2026-07-13T09:00:00Z'),
        ],
      });
      expect(list.single.displayTime, '2026-07-13T09:00:00Z');
      expect(list.single.platformsLabel, '-');
    });
  });

  group('EventTicketingSummary', () {
    test('残数は capacity - sold で算出', () {
      final list = EventTicketingSummary.listFromResponse({
        'events': [
          row({
            'title': 'ライブ',
            'date': '2026-08-01',
            'capacity': 100,
            'sold': 30,
          }),
        ],
      });
      expect(list.single.title, 'ライブ');
      expect(list.single.remaining, 70);
      expect(list.single.remainingLabel, '残 70枚');
    });

    test('定員未設定は 0 枚と偽らず null を返す', () {
      final list = EventTicketingSummary.listFromResponse({
        'events': [
          row({'title': '未定', 'sold': 5}),
        ],
      });
      expect(list.single.remaining, isNull);
      expect(list.single.remainingLabel, '定員未設定');
    });

    test('売り切れは 0 枚 (負にならない)', () {
      final list = EventTicketingSummary.listFromResponse({
        'events': [
          row({'title': '完売', 'capacity': 10, 'sold': 15}),
        ],
      });
      expect(list.single.remaining, 0);
    });
  });

  group('AuctionListing', () {
    test('current_bid を優先し ends_at を読む', () {
      final list = AuctionListing.listFromResponse({
        'auctions': [
          row({
            'title': '骨董品',
            'current_bid': 5000,
            'start_price': 1000,
            'ends_at': '2026-08-01T00:00:00Z',
          }),
        ],
      });
      expect(list.single.title, '骨董品');
      expect(list.single.displayPrice, 5000);
      expect(list.single.endsAt, '2026-08-01T00:00:00Z');
    });

    test('入札なしは開始価格にフォールバック', () {
      final list = AuctionListing.listFromResponse({
        'auctions': [
          row({'title': '新規', 'start_price': 800}),
        ],
      });
      expect(list.single.displayPrice, 800);
    });
  });

  group('AffiliateLinkStats', () {
    test('clicks/conversions/commission を読み summary を算出', () {
      final links = AffiliateLinkStats.listFromResponse({
        'links': [
          row({'title': 'A', 'code': 'aa', 'clicks': 10, 'conversions': 2}),
          row({'title': 'B', 'code': 'bb', 'clicks': 5, 'conversions': 1}),
        ],
      });
      expect(links.first.title, 'A');
      expect(links.first.clicks, 10);
      final summary = AffiliateSummary.fromLinks(links);
      expect(summary.totalClicks, 15);
      expect(summary.totalConversions, 3);
      expect(summary.linkCount, 2);
    });
  });

  group('DonationProject', () {
    test('goal/raised を読み progress をクランプ', () {
      final list = DonationProject.listFromResponse({
        'projects': [
          row({
            'title': '支援',
            'description': '説明',
            'goal_amount': 10000,
            'raised_amount': 2500,
          }),
        ],
      });
      expect(list.single.title, '支援');
      expect(list.single.progress, 0.25);
    });

    test('目標超過でも progress は 1.0 上限', () {
      final list = DonationProject.listFromResponse({
        'projects': [
          row({'title': 'x', 'goal_amount': 100, 'raised_amount': 500}),
        ],
      });
      expect(list.single.progress, 1.0);
    });
  });

  group('ParkingReservationEntry', () {
    test('spot/lot/fee を読む', () {
      final list = ParkingReservationEntry.listFromResponse({
        'reservations': [
          row({
            'lot_id': 'L1',
            'spot': 'A-3',
            'start_time': '2026-07-13T10:00:00Z',
            'fee': 500,
          }),
        ],
      });
      expect(list.single.spotLabel, 'A-3 (L1)');
      expect(list.single.fee, 500);
    });

    test('fee 未設定は null (¥0 と偽らない)', () {
      final list = ParkingReservationEntry.listFromResponse({
        'reservations': [
          row({'spot': 'B-1'}),
        ],
      });
      expect(list.single.fee, isNull);
      expect(list.single.spotLabel, 'B-1');
    });
  });

  group('ELearningCourse', () {
    test('コースに progress を join し受講中のみ抽出', () {
      final courses = ELearningCourse.listFromResponse({
        'courses': [
          {
            'id': 'c1',
            'metadata': {'title': '入門', 'level': 'beginner'},
          },
          {
            'id': 'c2',
            'metadata': {'title': '応用', 'level': 'advanced'},
          },
        ],
      });
      final progress = ELearningCourse.progressByCourseId({
        'enrollments': [
          row({'course_id': 'c1', 'progress': 40}),
        ],
      });
      final inProgress = ELearningCourse.inProgress(courses, progress);
      expect(inProgress.single.id, 'c1');
      expect(inProgress.single.progress, 40);
      expect(inProgress.single.title, '入門');
    });
  });

  group('LanguageDeck / Flashcard', () {
    test('deck は id/name を読む (deck_id ではない)', () {
      final decks = LanguageDeck.listFromResponse({
        'decks': [
          {
            'id': 'd1',
            'metadata': {'name': '英単語', 'language': 'en'},
          },
        ],
      });
      expect(decks.single.id, 'd1');
      expect(decks.single.name, '英単語');
    });

    test('card は front/back を読み review_session の cards キーも読む', () {
      final cards = Flashcard.listFromResponse({
        'cards': [
          {
            'id': 'f1',
            'metadata': {'front': 'apple', 'back': 'りんご'},
          },
        ],
      });
      expect(cards.single.front, 'apple');
      expect(cards.single.back, 'りんご');
    });

    test('stats は streak_days/total_cards を top-level から読む', () {
      final stats = LanguageStats.fromResponses(
        {'success': true, 'streak_days': 7},
        {'success': true, 'total_cards': 42},
      );
      expect(stats.streakDays, 7);
      expect(stats.totalCards, 42);
    });
  });

  group('BudgetEntry', () {
    test('category/amount を nested metadata から読みカテゴリ集計', () {
      final expenses = BudgetEntry.listFromResponse(
        {
          'expenses': [
            row({'category': 'food', 'amount': 1200}),
            row({'category': 'food', 'amount': 800}),
            row({'category': 'housing', 'amount': 50000}),
          ],
        },
        'expenses',
      );
      expect(BudgetEntry.sumForCategory(expenses, 'food'), 2000);
      expect(BudgetEntry.total(expenses), 52000);
    });

    test('income は source を category として扱う (income キー)', () {
      final incomes = BudgetEntry.listFromResponse(
        {
          'income': [
            row({'source': 'salary', 'amount': 300000}),
          ],
        },
        'income',
      );
      expect(incomes.single.category, 'salary');
      expect(incomes.single.amount, 300000);
    });
  });
}
