import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/view_models/shop_community_view_model.dart';

import '../support/fake_shop_community.dart';

void main() {
  late FakeShopCommunity repository;
  late ShopCommunityViewModel model;
  setUp(() {
    repository = FakeShopCommunity();
    model = ShopCommunityViewModel(productId: 'test', repository: repository);
  });
  tearDown(() async {
    model.dispose();
    await repository.sessions.close();
  });

  test('empty is a verified zero with no invented rating', () async {
    await model.load();
    expect(model.page!.count, 0);
    expect(model.page!.average, isNull);
    expect(model.canReview, isTrue);
  });
  test('logged-out and unpaid users cannot save', () async {
    repository.signedIn = false;
    await model.load();
    expect(await model.save(5, 'text'), isFalse);
    repository.signedIn = true;
    repository.paid = false;
    await model.load();
    expect(await model.save(5, 'text'), isFalse);
    expect(repository.saves, 0);
  });
  test('save, reload, edit and delete retain one review', () async {
    await model.load();
    expect(await model.save(5, ' 初回 '), isTrue);
    expect(model.own.review!.body, '初回');
    expect(model.page!.average, 5);
    await model.load();
    expect(await model.save(2, '編集済み'), isTrue);
    expect(model.page!.count, 1);
    expect(model.page!.average, 2);
    expect(model.own.review!.body, '編集済み');
    expect(await model.delete(), isTrue);
    expect(model.page!.count, 0);
    expect(model.own.review, isNull);
  });
  test('refunded users can delete but cannot edit', () async {
    repository.saved = FakeShopCommunity.review('own');
    repository.paid = false;
    await model.load();
    expect(await model.save(2, ''), isFalse);
    expect(await model.delete(), isTrue);
  });
  test('rating and Unicode length are validated before network call', () async {
    await model.load();
    expect(await model.save(0, ''), isFalse);
    expect(await model.save(6, ''), isFalse);
    expect(await model.save(4, 'あ' * 2001), isFalse);
    expect(repository.saves, 0);
    expect(await model.save(4, ''), isTrue);
  });
  test('double submission is prevented', () async {
    await model.load();
    repository.writeGate = Completer<void>();
    final first = model.save(3, 'text');
    expect(await model.save(5, 'again'), isFalse);
    repository.writeGate!.complete();
    expect(await first, isTrue);
    expect(repository.saves, 1);
  });
  test('failed reads are not reported as zero or successful permission', () async {
    repository.failRead = true;
    await model.load();
    expect(model.page, isNull);
    expect(model.reviewError, isNotNull);
    expect(model.releaseError, isNotNull);
    expect(model.ownerError, isNotNull);
    expect(model.canReview, isFalse);
    expect(model.reviewError, isNot(contains('private-internal')));
  });
  test('failed writes keep editor open and do not claim success', () async {
    await model.load();
    repository.failWrite = true;
    expect(await model.save(3, 'text'), isFalse);
    expect(model.notice, isNull);
    expect(model.working, isFalse);
    expect(model.actionError, isNot(contains('private-internal')));
  });
  test('pagination uses a cursor and refresh returns to newest', () async {
    repository.publicItems.addAll(List.generate(12, (i) => FakeShopCommunity.review('$i')));
    await model.load();
    expect(model.page!.items.length, 10);
    await model.nextPage();
    expect(model.pageNumber, 2);
    expect(model.page!.items.first.id, '10');
    expect(model.page!.count, 12);
    expect(model.page!.hasMore, isFalse);
    await model.load();
    expect(model.pageNumber, 1);
  });
  test('session changes clear the previous account review immediately', () async {
    repository.saved = FakeShopCommunity.review('own');
    await model.load();
    repository.signedIn = false;
    repository.sessions.add(null);
    expect(model.own.review, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(model.canReview, isFalse);
  });
  test('late loads after disposal cannot notify', () async {
    final delayed = FakeShopCommunity()..readGate = Completer<void>();
    final other = ShopCommunityViewModel(productId: 'test', repository: delayed);
    final pending = other.load();
    other.dispose();
    delayed.readGate!.complete();
    await pending;
    await delayed.sessions.close();
  });
  test('an account change during save cannot claim success for the new account', () async {
    await model.load();
    repository.writeGate = Completer<void>();
    final pending = model.save(4, 'previous account');
    repository.signedIn = false;
    repository.sessions.add(null);
    repository.writeGate!.complete();
    expect(await pending, isFalse);
    expect(model.notice, isNull);
    expect(model.actionError, isNull);
  });
  test('malformed aggregate is rejected rather than invented', () {
    expect(() => ShopReviewPage.fromRow({'count': 3, 'average': null, 'items': []}), throwsFormatException);
    final empty = ShopReviewPage.fromRow({'count': 0, 'average': null, 'items': []});
    expect(empty.average, isNull);
  });
}
