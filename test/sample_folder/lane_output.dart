// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

// Writes `out` to stdout and `err` to stderr, then exits with code 3.
void main() {
  stdout.writeln('out');
  stderr.writeln('err');
  exitCode = 3;
}
