import 'dart:math';

class FilterResult {
  final String number;
  final int sumValue;
  final int span;
  final String formType;
  final int oddCount;
  final int evenCount;
  final int bigCount;
  final int smallCount;

  FilterResult({
    required this.number,
    required this.sumValue,
    required this.span,
    required this.formType,
    required this.oddCount,
    required this.evenCount,
    required this.bigCount,
    required this.smallCount,
  });
}

class NumberFilterService {
  static List<FilterResult> filter({
    Set<int>? includeDigits,
    Set<int>? excludeDigits,
    int? minSum,
    int? maxSum,
    int? minSpan,
    int? maxSpan,
    String? formType,
    String? oddEvenRatio,
    String? bigSmallRatio,
    int? pos1Digit,
    int? pos2Digit,
    int? pos3Digit,
  }) {
    final results = <FilterResult>[];

    for (int a = 0; a <= 9; a++) {
      if (pos1Digit != null && a != pos1Digit) continue;
      if (excludeDigits != null && excludeDigits.contains(a)) continue;

      for (int b = 0; b <= 9; b++) {
        if (pos2Digit != null && b != pos2Digit) continue;
        if (excludeDigits != null && excludeDigits.contains(b)) continue;

        for (int c = 0; c <= 9; c++) {
          if (pos3Digit != null && c != pos3Digit) continue;
          if (excludeDigits != null && excludeDigits.contains(c)) continue;

          final digits = [a, b, c];

          if (includeDigits != null && !includeDigits.every((d) => digits.contains(d))) {
            continue;
          }

          final sumValue = a + b + c;
          if (minSum != null && sumValue < minSum) continue;
          if (maxSum != null && sumValue > maxSum) continue;

          final span = digits.reduce(max) - digits.reduce(min);
          if (minSpan != null && span < minSpan) continue;
          if (maxSpan != null && span > maxSpan) continue;

          String ft;
          if (a == b && b == c) {
            ft = '豹子';
          } else if (a == b || b == c || a == c) {
            ft = '组三';
          } else {
            ft = '组六';
          }
          if (formType != null && formType.isNotEmpty && ft != formType) continue;

          final oddCount = digits.where((d) => d % 2 == 1).length;
          final evenCount = 3 - oddCount;
          if (oddEvenRatio != null && oddEvenRatio.isNotEmpty) {
            if (!_matchRatio(oddEvenRatio, oddCount, evenCount)) continue;
          }

          final bigCount = digits.where((d) => d >= 5).length;
          final smallCount = 3 - bigCount;
          if (bigSmallRatio != null && bigSmallRatio.isNotEmpty) {
            if (!_matchRatio(bigSmallRatio, bigCount, smallCount)) continue;
          }

          results.add(FilterResult(
            number: '$a$b$c',
            sumValue: sumValue,
            span: span,
            formType: ft,
            oddCount: oddCount,
            evenCount: evenCount,
            bigCount: bigCount,
            smallCount: smallCount,
          ));
        }
      }
    }

    return results;
  }

  static bool _matchRatio(String ratio, int first, int second) {
    switch (ratio) {
      case '3:0':
        return first == 3;
      case '2:1':
        return first == 2 && second == 1;
      case '1:2':
        return first == 1 && second == 2;
      case '0:3':
        return second == 3;
      default:
        return true;
    }
  }
}
