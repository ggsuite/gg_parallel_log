// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

// Starts sleep.dart as a child that writes to the same output, prints
// `child <pid>` and waits for it. With `--exit` it exits right away and
// leaves the child holding the output open.
Future<void> main(List<String> arguments) async {
  final child = await Process.start(Platform.resolvedExecutable, [
    Platform.script.resolve('sleep.dart').toFilePath(),
  ], mode: ProcessStartMode.inheritStdio);
  stdout.writeln('child ${child.pid}');
  await stdout.flush();
  if (arguments.contains('--exit')) exit(0);
  await child.exitCode;
}
