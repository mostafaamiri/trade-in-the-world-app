import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trade_around_the_world/models.dart';
import 'package:trade_around_the_world/services/jalali_date.dart';
import 'package:trade_around_the_world/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('parses the complete zoo collection from the API', () {
    final zoo = ZooStatus.fromJson({
      'isUnlocked': true,
      'animalCount': 124,
      'animals': ['شیر', 'لاما', 'باسیلیسک'],
      'dailyReward': {'coins': 100, 'tokens': 200},
    });

    expect(zoo.animalCount, 124);
    expect(zoo.animals, ['شیر', 'لاما', 'باسیلیسک']);
  });

  test('loads 160 unique and ordered world-route cells', () async {
    final raw = await rootBundle.loadString(
      'assets/data/world_trade_config.json',
    );
    final cities = (jsonDecode(raw) as Map)['cities'] as List;
    final routeOrders = cities
        .map((city) => (city as Map)['routeOrder'] as int)
        .toList();
    final cityIds = cities
        .map((city) => (city as Map)['cityId'] as String)
        .toSet();

    expect(cities, hasLength(160));
    expect(cityIds, hasLength(160));
    expect(routeOrders, List<int>.generate(160, (index) => index));
  });
}
