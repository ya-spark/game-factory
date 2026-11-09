/// A tiny arithmetic evaluator used to check maths items that declare an
/// `expression`: numbers, `+ - * / ^`, the symbols for times and divide,
/// unary minus and parentheses.
library;

/// Thrown when an expression cannot be parsed or evaluated.
class ExpressionException implements Exception {
  ExpressionException(this.message);
  final String message;
  @override
  String toString() => 'ExpressionException: $message';
}

/// Evaluates [source] and returns its value.
double evaluateExpression(String source) {
  final v = _Parser(source).parse();
  if (!v.isFinite) throw ExpressionException('result is not finite');
  return v;
}

class _Parser {
  _Parser(String s)
    : _s = s
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll(RegExp(r'\s+'), '');
  final String _s;
  int _i = 0;

  double parse() {
    if (_s.isEmpty) throw ExpressionException('empty expression');
    final v = _sum();
    if (_i != _s.length) {
      throw ExpressionException('unexpected "${_s[_i]}" at $_i');
    }
    return v;
  }

  bool _eat(String c) {
    if (_i < _s.length && _s[_i] == c) {
      _i++;
      return true;
    }
    return false;
  }

  double _sum() {
    var v = _product();
    while (true) {
      if (_eat('+')) {
        v += _product();
      } else if (_eat('-')) {
        v -= _product();
      } else {
        return v;
      }
    }
  }

  double _product() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v *= _unary();
      } else if (_eat('/')) {
        final d = _unary();
        if (d == 0) throw ExpressionException('division by zero');
        v /= d;
      } else {
        return v;
      }
    }
  }

  double _unary() {
    if (_eat('-')) return -_unary();
    if (_eat('+')) return _unary();
    return _power();
  }

  double _power() {
    final base = _atom();
    if (_eat('^')) return _pow(base, _unary());
    return base;
  }

  double _pow(double b, double e) {
    if (e != e.roundToDouble() || e < 0 || e > 64) {
      throw ExpressionException('exponent must be a whole number 0 to 64');
    }
    var r = 1.0;
    for (var k = 0; k < e; k++) {
      r *= b;
    }
    return r;
  }

  double _atom() {
    if (_eat('(')) {
      final v = _sum();
      if (!_eat(')')) throw ExpressionException('missing )');
      return v;
    }
    final m = RegExp(r'\d+\.?\d*|\.\d+').matchAsPrefix(_s, _i);
    if (m == null) {
      throw ExpressionException(
        _i < _s.length ? 'unexpected "${_s[_i]}"' : 'unexpected end',
      );
    }
    _i = m.end;
    return double.parse(m.group(0)!.replaceFirst(RegExp(r'\.$'), ''));
  }
}
