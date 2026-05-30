import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_profile.dart';

void main() {
  test('UserProfile maps lifestyle fields for asset AI context', () {
    final profile = UserProfile.fromJson(
      <String, dynamic>{
        'user_id': 'user-1',
        'display_name': 'kanta',
        'birth_date': '1978-09-30T00:00:00.000',
        'gender': '男',
        'occupation': '自営業',
        'annual_income': 5433780,
        'address': '東京都豊島区',
        'education': '大学卒',
        'career_history': '営業、Web開発',
        'hobbies': 'AIツール検証',
        'alcohol_use': '時々',
        'smoking_use': '吸わない',
        'favorite_foods': 'カレー',
      },
    );

    expect(profile.gender, '男');
    expect(profile.occupation, '自営業');
    expect(profile.annualIncome, 5433780);
    expect(profile.address, '東京都豊島区');
    expect(profile.favoriteFoods, 'カレー');

    final json = profile.toJson();
    expect(json['gender'], '男');
    expect(json['occupation'], '自営業');
    expect(json['annual_income'], 5433780);
    expect(json['career_history'], '営業、Web開発');
    expect(json['alcohol_use'], '時々');
    expect(json['smoking_use'], '吸わない');
  });
}
