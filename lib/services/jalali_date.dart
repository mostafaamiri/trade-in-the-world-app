class JalaliDate {
  const JalaliDate({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;
}

JalaliDate jalaliDateFor(DateTime date) {
  const daysUntilMonth = [
    0,
    31,
    59,
    90,
    120,
    151,
    181,
    212,
    243,
    273,
    304,
    334,
  ];
  final originalYear = date.year;
  var year = originalYear <= 1600 ? 0 : 979;
  var gregorianYear = originalYear - (originalYear <= 1600 ? 621 : 1600);
  final gregorianYearForLeap = date.month > 2
      ? gregorianYear + 1
      : gregorianYear;
  var days =
      365 * gregorianYear +
      ((gregorianYearForLeap + 3) ~/ 4) -
      ((gregorianYearForLeap + 99) ~/ 100) +
      ((gregorianYearForLeap + 399) ~/ 400) -
      80 +
      date.day +
      daysUntilMonth[date.month - 1];
  year += 33 * (days ~/ 12053);
  days %= 12053;
  year += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    year += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final month = days < 186 ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final day = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
  return JalaliDate(year: year, month: month, day: day);
}
