import 'dart:math' as math;
import 'package:intl/intl.dart';

class CalcEngine {
  static final NumberFormat _fmt = NumberFormat("#,##0.########", "ru_RU");

  static String formatNumber(double val) {
    if (val.isNaN || val.isInfinite) return 'Ошибка';
    if (val % 1 == 0 && val.abs() < 1e15) {
      return val.toInt().toString();
    }
    return _fmt.format(val);
  }

  /// Evaluates a basic arithmetic expression (+ - × ÷ %), used by the
  /// standard calculator keypad.
  static double evaluate(String expr) {
    try {
      String clean = expr.replaceAll(' ', '').replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
      if (clean.isEmpty) return 0.0;

      List<dynamic> tokens = [];
      int i = 0;
      while (i < clean.length) {
        String c = clean[i];
        if ('0123456789.'.contains(c)) {
          int j = i;
          while (j < clean.length && '0123456789.'.contains(clean[j])) {
            j++;
          }
          tokens.add(double.parse(clean.substring(i, j)));
          i = j;
        } else if ('+-*/%'.contains(c)) {
          if (c == '-' && (i == 0 || '+-*/'.contains(clean[i - 1]))) {
            int j = i + 1;
            while (j < clean.length && '0123456789.'.contains(clean[j])) {
              j++;
            }
            tokens.add(-double.parse(clean.substring(i + 1, j)));
            i = j;
          } else {
            tokens.add(c);
            i++;
          }
        } else {
          i++;
        }
      }

      List<dynamic> nextTokens = [];
      i = 0;
      while (i < tokens.length) {
        var t = tokens[i];
        if (t == '*' || t == '/') {
          double prev = (nextTokens.removeLast() as num).toDouble();
          double nxt = (tokens[i + 1] as num).toDouble();
          double res = t == '*' ? prev * nxt : (nxt != 0 ? prev / nxt : 0.0);
          nextTokens.add(res);
          i += 2;
        } else if (t == '%') {
          double prev = (nextTokens.removeLast() as num).toDouble();
          nextTokens.add(prev / 100.0);
          i += 1;
        } else {
          nextTokens.add(t);
          i++;
        }
      }

      if (nextTokens.isEmpty) return 0.0;
      double result = (nextTokens[0] as num).toDouble();
      i = 1;
      while (i < nextTokens.length) {
        String op = nextTokens[i];
        double nxt = (nextTokens[i + 1] as num).toDouble();
        if (op == '+') result += nxt;
        else if (op == '-') result -= nxt;
        i += 2;
      }
      return result;
    } catch (_) {
      return 0.0;
    }
  }

  /// Applies a single scientific function to the current numeric value
  /// shown on screen. Used by the scientific keypad row.
  static double applyFunction(String fn, double val) {
    try {
      switch (fn) {
        case 'sin':
          return math.sin(val * math.pi / 180);
        case 'cos':
          return math.cos(val * math.pi / 180);
        case 'tan':
          return math.tan(val * math.pi / 180);
        case '√':
          return val < 0 ? double.nan : math.sqrt(val);
        case 'x²':
          return val * val;
        case 'log':
          return val <= 0 ? double.nan : math.log(val) / math.ln10;
        case 'ln':
          return val <= 0 ? double.nan : math.log(val);
        case '1/x':
          return val == 0 ? double.nan : 1 / val;
        case '!':
          if (val < 0 || val != val.roundToDouble() || val > 170) return double.nan;
          double r = 1;
          for (int k = 2; k <= val.toInt(); k++) {
            r *= k;
          }
          return r;
        default:
          return val;
      }
    } catch (_) {
      return double.nan;
    }
  }
}
