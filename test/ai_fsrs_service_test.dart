import 'package:flutter_test/flutter_test.dart';

String fsrsGradeLabel(int grade) {
  const labels = {1: 'Again', 2: 'Hard', 3: 'Good', 4: 'Easy'};
  return labels[grade] ?? 'Unknown';
}

int daysUntilNext(int grade, double stability) {
  double newStab = stability;
  double days = 1;
  if (grade == 1) {
    newStab = stability * 0.5 < 0.5 ? 0.5 : stability * 0.5;
    days = 1;
  } else if (grade == 2) {
    newStab = stability * 0.8;
    days = newStab < 1 ? 1 : newStab;
  } else if (grade == 3) {
    days = stability < 1 ? 1 : stability;
  } else {
    newStab = stability * 1.3;
    days = newStab * 1.3;
  }
  return days.round();
}

void main() {
  test('grade=1 (Again) sets 1 day', () {
    expect(daysUntilNext(1, 4.0), 1);
  });

  test('grade=3 (Good) uses stability as days', () {
    expect(daysUntilNext(3, 5.0), 5);
  });

  test('grade=4 (Easy) uses stability * 1.3 * 1.3 days', () {
    expect(daysUntilNext(4, 4.0), (4.0 * 1.3 * 1.3).round());
  });

  test('grade label strings', () {
    expect(fsrsGradeLabel(1), 'Again');
    expect(fsrsGradeLabel(4), 'Easy');
  });
}
