import 'dart:math' as math;
import 'package:intl/intl.dart';

class CalcEngine {
  static final NumberFormat _fmt = NumberFormat("#,##0.########", "ru_RU");

  static String formatNumber(double val) {
    if (val.isNaN || val.isInfinite) return 'Ошибка';
    if (val.abs() > 1e14 || (val.abs() < 1e-6 && val != 0)) {
      return val.toStringAsExponential(6);
    }
    if (val % 1 == 0 && val.abs() < 1e12) {
      return val.toInt().toString();
    }
    return _fmt.format(val);
  }

  static double evaluate(String expr) {
    try {
      String clean = expr
          .replaceAll(' ', '')
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll(',', '.');

      if (clean.isEmpty) return 0.0;
      return _parseExpression(clean);
    } catch (_) {
      return double.nan;
    }
  }

  static double _parseExpression(String str) {
    str = str.replaceAll('π', math.pi.toString()).replaceAll('e', math.e.toString());

    List<String> tokens = [];
    int i = 0;
    while (i < str.length) {
      String c = str[i];
      if ('0123456789.'.contains(c)) {
        int j = i;
        while (j < str.length && '0123456789.'.contains(str[j])) {
          j++;
        }
        tokens.add(str.substring(i, j));
        i = j;
      } else if (c == '(' || c == ')') {
        tokens.add(c);
        i++;
      } else if ('+-*/%^'.contains(c)) {
        if (c == '-' && (i == 0 || '+-*/(^'.contains(str[i - 1]))) {
          int j = i + 1;
          while (j < str.length && '0123456789.'.contains(str[j])) {
            j++;
          }
          if (j > i + 1) {
            tokens.add('-' + str.substring(i + 1, j));
            i = j;
          } else {
            tokens.add(c);
            i++;
          }
        } else {
          tokens.add(c);
          i++;
        }
      } else {
        i++;
      }
    }

    List<double> values = [];
    List<String> ops = [];

    int precedence(String op) {
      if (op == '+' || op == '-') return 1;
      if (op == '*' || op == '/' || op == '%') return 2;
      if (op == '^') return 3;
      return 0;
    }

    void applyOp() {
      if (ops.isEmpty || values.length < 2) return;
      String op = ops.removeLast();
      double b = values.removeLast();
      double a = values.removeLast();
      double res = 0.0;
      switch (op) {
        case '+': res = a + b; break;
        case '-': res = a - b; break;
        case '*': res = a * b; break;
        case '/': res = b != 0 ? a / b : double.nan; break;
        case '%': res = a * (b / 100.0); break;
        case '^': res = math.pow(a, b).toDouble(); break;
      }
      values.add(res);
    }

    for (var tok in tokens) {
      if (double.tryParse(tok) != null) {
        values.add(double.parse(tok));
      } else if (tok == '(') {
        ops.add(tok);
      } else if (tok == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          applyOp();
        }
        if (ops.isNotEmpty && ops.last == '(') ops.removeLast();
      } else if ('+-*/%^'.contains(tok)) {
        while (ops.isNotEmpty && precedence(ops.last) >= precedence(tok)) {
          applyOp();
        }
        ops.add(tok);
      }
    }

    while (ops.isNotEmpty) {
      applyOp();
    }

    return values.isNotEmpty ? values.first : 0.0;
  }

  static double applyFunction(String fn, double val) {
    try {
      switch (fn) {
        case 'sin': return math.sin(val * math.pi / 180);
        case 'cos': return math.cos(val * math.pi / 180);
        case 'tan': return math.tan(val * math.pi / 180);
        case '√': return val < 0 ? double.nan : math.sqrt(val);
        case 'x²': return val * val;
        case 'x³': return val * val * val;
        case 'log': return val <= 0 ? double.nan : math.log(val) / math.ln10;
        case 'ln': return val <= 0 ? double.nan : math.log(val);
        case '1/x': return val == 0 ? double.nan : 1 / val;
        case '!':
          if (val < 0 || val != val.roundToDouble() || val > 170) return double.nan;
          double r = 1;
          for (int k = 2; k <= val.toInt(); k++) {
            r *= k;
          }
          return r;
        default: return val;
      }
    } catch (_) {
      return double.nan;
    }
  }
}
