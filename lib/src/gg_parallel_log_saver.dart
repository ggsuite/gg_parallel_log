// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart';

import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_text.dart';

// #############################################################################
/// Writes the output of a lane into a file of its own.
class GgParallelLogSaver {
  /// Creates a saver writing into [directory], by default a temp folder.
  GgParallelLogSaver({Directory? directory})
    : directory =
          directory ??
          Directory(join(Directory.systemTemp.path, 'gg_parallel_log'));

  /// Creates an example saver writing into [directory].
  factory GgParallelLogSaver.example({Directory? directory}) =>
      GgParallelLogSaver(directory: directory);

  // ...........................................................................
  /// Writes all lines of [lane] without colors and returns the new file.
  ///
  /// Never overwrites a file; a name in use gets a counter appended.
  File save(GgParallelLogLane lane) {
    directory.createSync(recursive: true);
    final file = _create(_baseName(lane.name));
    file.writeAsStringSync(
      lane.lines.map((line) {
        final time = GgParallelLogText.duration(line.time);
        final prefix = line.isError ? '! ' : '';
        return '$time $prefix${GgParallelLogText.stripAnsi(line.text)}\n';
      }).join(),
    );
    return file;
  }

  // ...........................................................................
  /// The folder the logs are written to.
  final Directory directory;

  // ######################
  // Private
  // ######################

  // ...........................................................................
  File _create(String baseName) {
    for (var counter = 1; ; counter++) {
      final suffix = counter == 1 ? '' : '_$counter';
      final file = File(join(directory.path, '$baseName$suffix.log'));
      try {
        file.createSync(exclusive: true);
        return file;
      } on FileSystemException {
        if (!file.existsSync()) rethrow;
      }
    }
  }

  // ...........................................................................
  static String _baseName(String laneName) {
    final now = clock.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final safe = laneName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return '${safe}_$stamp';
  }
}
