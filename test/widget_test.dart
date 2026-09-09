import 'package:flutter_test/flutter_test.dart';
import 'package:trade_around_the_world/services/jalali_date.dart';
import 'package:trade_around_the_world/ui.dart';

void main() {
  test('formats global currency with Persian digits', () {
    expect(money(1200000), '۱٬۲۰۰٬۰۰۰');
    expect(persianDigits('0.4.0'), '۰.۴.۰');
  });

  test('converts Gregorian dates to Jalali dates', () {
    final nowruz = jalaliDateFor(DateTime(2024, 3, 20));
    final autumn = jalaliDateFor(DateTime(2026, 9, 9));

    expect([nowruz.year, nowruz.month, nowruz.day], [1403, 1, 1]);
    expect([autumn.year, autumn.month, autumn.day], [1405, 6, 18]);
  });
}
