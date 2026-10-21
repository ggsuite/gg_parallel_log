// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// Greets whoever asks.
class GgParallelLog {
  /// Constructor
  const GgParallelLog({this.greeting = 'Hello'});

  /// A realistic instance; tests pass only what they care about.
  factory GgParallelLog.example({String? greeting}) =>
      GgParallelLog(greeting: greeting ?? 'Hello');

  // ...........................................................................
  /// Greets [name].
  String greet(String name) => '$greeting, $name!';

  /// The word to greet with.
  final String greeting;
}
