// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Prints a line, then sleeps until it gets killed.
Future<void> main() async {
  print('sleeping');
  await Future<void>.delayed(const Duration(minutes: 1));
}
