import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_attribution.dart';
import 'package:my_web_app/models/shop_login_continuation.dart';

void main() {
  test('missing labels are direct with no invented campaign or post', () {
    final labels = ShopAttribution.fromUri(Uri.parse('/shop/product'));
    expect(labels.isValid, isTrue);
    expect(labels.toRequest(), {
      'source': 'direct', 'campaign': '', 'content_id': '',
    });
  });

  test('all three ASCII labels have a single canonical representation', () {
    final labels = ShopAttribution.fromUri(Uri(
      path: '/shop/product',
      queryParameters: {
        'utm_source': ' X ', 'utm_campaign': ' Launch-1 ',
        'utm_content': ' Growth_Game_T30_R1 ', 'amount': '1',
      },
    ),);
    expect(labels.toRequest(), {
      'source': 'x', 'campaign': 'launch-1',
      'content_id': 'growth_game_t30_r1',
    });
    expect(ShopAttribution.fromUri(Uri(queryParameters: labels.toQuery()))
        .toRequest(), labels.toRequest(),);
  });

  test('invalid values never alias another post or become direct', () {
    for (final value in [
      'a' * 65, 'post/a', 'post a', '日本語', 'test@example.invalid',
    ]) {
      for (final key in ['utm_source', 'utm_campaign', 'utm_content']) {
        final labels = ShopAttribution.fromUri(Uri(queryParameters: {key: value}));
        expect(labels.isValid, isFalse, reason: key);
        expect(labels.toRequest(), {'attribution_valid': false});
        expect(ShopAttribution.fromUri(Uri(queryParameters: labels.toQuery()))
            .isValid, isFalse,);
      }
    }
  });

  test('64 characters remain intact', () {
    expect(ShopAttribution.parse(contentId: 'a' * 64).contentId, 'a' * 64);
  });

  test('duplicate query keys are ambiguous even if their values match', () {
    for (final key in ['utm_source', 'utm_campaign', 'utm_content']) {
      expect(ShopAttribution.fromUri(Uri.parse('/?$key=a&$key=a')).isValid,
          isFalse,);
    }
  });

  test('server return keeps unavailable attribution unavailable', () {
    final labels = ShopAttribution.fromUri(Uri.parse(
      '/shop/product?product_id=hexciv-win64&purchase=canceled'
      '&shop_attribution=unavailable',
    ),);
    expect(labels.toRequest(), {'attribution_valid': false});
  });

  test('different posts and campaigns remain distinct', () {
    expect(ShopAttribution.parse(contentId: 'post-a').toRequest(),
        isNot(ShopAttribution.parse(contentId: 'post-b').toRequest()),);
    expect(ShopAttribution.parse(campaign: 'a').toRequest(),
        isNot(ShopAttribution.parse(campaign: 'b').toRequest()),);
  });

  test('login round trip retains only product and labels', () {
    final labels = ShopAttribution.parse(
      source: 'x', campaign: 'launch', contentId: 'post-a',
    );
    final login = ShopLoginContinuation.loginUri(
      productId: 'hexciv-win64', attribution: labels,
    );
    final product = ShopLoginContinuation.productUri(login)!;
    expect(login.path, '/login');
    expect(product.path, '/shop/product');
    expect(product.hasAuthority, isFalse);
    expect(product.queryParameters, {
      'product_id': 'hexciv-win64', ...labels.toQuery(),
    });
  });

  test('two login locations retain their own product and campaign', () {
    final first = ShopLoginContinuation.loginUri(
      productId: 'hexciv-win64',
      attribution: ShopAttribution.parse(contentId: 'post-a'),
    );
    final second = ShopLoginContinuation.loginUri(
      productId: 'another-product',
      attribution: ShopAttribution.parse(contentId: 'post-b'),
    );
    expect(ShopLoginContinuation.productUri(first)!.queryParameters,
        containsPair('utm_content', 'post-a'),);
    expect(ShopLoginContinuation.productUri(second)!.queryParameters,
        containsPair('product_id', 'another-product'),);
  });

  test('invalid labels survive login without keeping raw private values', () {
    final login = ShopLoginContinuation.loginUri(
      productId: 'hexciv-win64',
      attribution: ShopAttribution.parse(contentId: 'person@example.invalid'),
    );
    expect(login.toString(), isNot(contains('person')));
    expect(ShopAttribution.fromUri(ShopLoginContinuation.productUri(login)!)
        .isValid, isFalse,);
  });

  test('arbitrary redirect, purchase, identity and token parameters are ignored', () {
    final product = ShopLoginContinuation.productUri(Uri.parse(
      '/login?shop_product=hexciv-win64&return_to=https://evil.invalid'
      '&purchase=success&user_id=test&access_token=synthetic#secret',
    ),)!;
    expect(product.toString(),
        '/shop/product?product_id=hexciv-win64&utm_source=direct',);
  });

  test('invalid product and non-login paths cannot become a return target', () {
    for (final uri in [
      '/login', '/login?shop_product=../admin',
      '/login?shop_product=https://evil.invalid',
      '/login?shop_product=a&shop_product=b', '/other?shop_product=hexciv-win64',
    ]) {
      expect(ShopLoginContinuation.productUri(Uri.parse(uri)), isNull);
    }
    expect(ShopLoginContinuation.loginUri(
      productId: '../admin', attribution: ShopAttribution.parse(),
    ).toString(), '/login',);
  });

  test('OAuth callback uses trusted origin, not input authority or credentials', () {
    final callback = ShopLoginContinuation.callbackUri(
      base: Uri.parse('https://store.example.invalid:8443/current?token=secret'),
      loginLocation: Uri.parse(
        'https://evil.invalid/login?shop_product=hexciv-win64&utm_content=post-a'
        '&redirect=https://evil.invalid&access_token=synthetic#secret',
      ),
    )!;
    expect(callback.origin, 'https://store.example.invalid:8443');
    expect(callback.path, '/login');
    expect(callback.queryParameters, {
      'shop_product': 'hexciv-win64', 'utm_source': 'direct',
      'utm_content': 'post-a',
    });
    expect(callback.fragment, isEmpty);
    expect(callback.userInfo, isEmpty);
  });

  test('non-shop login keeps the existing default callback', () {
    expect(ShopLoginContinuation.callbackUri(
      base: Uri.parse('https://store.example.invalid'),
      loginLocation: Uri.parse('/login'),
    ), isNull,);
    expect(ShopLoginContinuation.callbackUri(
      base: Uri.parse('file:///local'),
      loginLocation: Uri.parse('/login?shop_product=hexciv-win64'),
    ), isNull,);
  });
}
