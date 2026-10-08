import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/python_block_review.dart';

void main() {
  test('implementation followed by usage is not treated as the last block', () {
    final review = PythonBlockReview.inspect('```python\ndef parse_duration(s):\n    return 1\n```\n```python\nprint(parse_duration("1s"))\n```', 'parse_duration');
    expect(review.blocks.length, 2);
    expect(review.candidates, [0]);
  });
  test('two implementations remain ambiguous', () {
    final review = PythonBlockReview.inspect('```py\ndef f():\n    pass\n```\n```python\ndef f():\n    pass\n```', 'f');
    expect(review.candidates, [0, 1]);
  });
  test('missing and invalid function names are rejected', () {
    expect(() => PythonBlockReview.inspect('', ''), throwsFormatException);
    expect(() => PythonBlockReview.inspect('', 'a('), throwsFormatException);
  });
}
