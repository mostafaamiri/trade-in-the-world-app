import 'package:flutter_test/flutter_test.dart';
import 'package:trade_around_the_world/ui.dart';

void main() {
  test('formats global currency with Persian digits', () {
    expect(money(1200000), '۱٬۲۰۰٬۰۰۰');
    expect(persianDigits('0.4.0'), '۰.۴.۰');
  });
}
