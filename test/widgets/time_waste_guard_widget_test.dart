import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/time_waste_guard_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('records refresh actions for the selected day', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final date = DateTime(2026, 5, 2, 10);

    await TimeWasteGuardWidget.recordRefreshAction(
      date: date,
      action: '10分だけ外を歩く',
    );
    await TimeWasteGuardWidget.recordRefreshAction(
      date: date,
      action: '画面から離れて本を1ページ読む',
    );

    expect(await TimeWasteGuardWidget.loadRefreshActionCountFor(date), 2);
    expect(
      await TimeWasteGuardWidget.loadLastRefreshActionFor(date),
      '画面から離れて本を1ページ読む',
    );
  });
}
