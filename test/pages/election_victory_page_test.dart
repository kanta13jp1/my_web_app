import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/election_victory_page.dart';

void main() {
  test('public election dashboard remains constructible', () {
    const page = ElectionVictoryPage(publicView: true);

    expect(page.publicView, isTrue);
  });
}
