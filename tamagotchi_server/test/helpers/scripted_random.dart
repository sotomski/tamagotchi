import 'dart:math';

/// A [Random] whose [nextDouble] returns a scripted queue in order.
///
/// Throws [StateError] if drawn past the end — turning "consumed no draws"
/// into an assertable property. [nextInt] always returns 0 (sufficient for
/// fullRefusalLine() picks). [nextBool] is not implemented.
class ScriptedRandom implements Random {
  ScriptedRandom(this._doubles);

  final List<double> _doubles;
  int _i = 0;

  @override
  double nextDouble() {
    if (_i >= _doubles.length) {
      throw StateError(
        'ScriptedRandom: nextDouble() called more times than scripted',
      );
    }
    return _doubles[_i++];
  }

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => throw UnimplementedError();
}
