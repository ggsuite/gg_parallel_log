// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Talks to the real console of the process, which unit tests do not have.
// coverage:ignore-file

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'gg_parallel_log_console.dart';

// #############################################################################
/// The console of the process on POSIX (stty, poll, read) or Windows.
abstract final class GgParallelLogNativeConsole {
  // ...........................................................................
  /// Returns the console of the current platform.
  static GgParallelLogConsole create() =>
      Platform.isWindows ? _WindowsConsole() : _PosixConsole();
}

// #############################################################################
/// Uses `stty` for the modes and `poll` plus `read` on fd 0 for the keys.
///
/// A watchdog process restores the terminal should this process crash.
class _PosixConsole implements GgParallelLogConsole {
  // ...........................................................................
  @override
  bool enableRawMode() {
    final saved = _stty('-g');
    if (saved == null || saved.isEmpty) return false;
    if (_stty('-icanon -echo -isig -ixon -iexten min 0 time 0') == null) {
      return false;
    }
    _saved = saved;
    final tty = _ttyPath();
    if (tty != null) _startWatchdog(saved, tty);
    return true;
  }

  // ...........................................................................
  @override
  void disableRawMode() {
    final saved = _saved;
    if (saved == null) return;
    read();
    _stty(saved);
    _saved = null;
    unawaited(_watchdog?.then((process) => process.kill()));
  }

  // ...........................................................................
  @override
  String read() {
    while (_hasInput()) {
      final count = _read(0, _buffer, _bufferSize);
      if (count <= 0) break;
      _decoder.add(_buffer.asTypedList(count));
    }
    final keys = _keys.toString();
    _keys.clear();
    return keys;
  }

  // ######################
  // Private
  // ######################

  static const int _bufferSize = 4096;
  static const int _pollIn = 1;
  static final DynamicLibrary _libc = DynamicLibrary.process();

  /// `nfds_t` is an `unsigned int` on macOS and an `unsigned long` on Linux.
  static final int Function(Pointer<Void>, int, int) _poll = Platform.isMacOS
      ? _libc.lookupFunction<
          Int32 Function(Pointer<Void>, Uint32, Int32),
          int Function(Pointer<Void>, int, int)
        >('poll')
      : _libc.lookupFunction<
          Int32 Function(Pointer<Void>, UnsignedLong, Int32),
          int Function(Pointer<Void>, int, int)
        >('poll');

  static final int Function(int, Pointer<Uint8>, int) _read = _libc
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
        int Function(int, Pointer<Uint8>, int)
      >('read');

  static final Pointer<Void> Function(int) _malloc = _libc
      .lookupFunction<
        Pointer<Void> Function(IntPtr),
        Pointer<Void> Function(int)
      >('malloc');

  /// One `struct pollfd`: fd at 0, events at 4, revents at 6.
  static final Pointer<Int32> _pollFd = _malloc(8).cast();
  static final Pointer<Uint8> _buffer = _malloc(_bufferSize).cast();

  final StringBuffer _keys = StringBuffer();
  late final ByteConversionSink _decoder = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(StringConversionSink.fromStringSink(_keys));
  String? _saved;
  Future<Process>? _watchdog;

  // ...........................................................................
  /// Returns whether fd 0 has bytes to read, without waiting.
  bool _hasInput() {
    _pollFd[0] = 0;
    _pollFd.cast<Int16>()[2] = _pollIn;
    _pollFd.cast<Int16>()[3] = 0;
    if (_poll(_pollFd.cast(), 1, 0) <= 0) return false;
    return _pollFd.cast<Int16>()[3] & _pollIn != 0;
  }

  // ...........................................................................
  /// Starts a process that restores [saved] on [tty] once this one is gone.
  ///
  /// It runs detached without a `/dev/tty`, hence the path of the device.
  void _startWatchdog(String saved, String tty) {
    _watchdog = Process.start(
      'sh',
      [
        '-c',
        'while kill -0 "\$WATCHED" 2>/dev/null; do sleep 0.2; done; '
            'stty "\$SAVED" < "\$TTY"; printf "\\033[?25h" > "\$TTY"',
      ],
      environment: {'WATCHED': '$pid', 'SAVED': saved, 'TTY': tty},
      mode: ProcessStartMode.detached,
    );
    unawaited(_watchdog!.then((_) {}, onError: (Object _) {}));
  }

  // ...........................................................................
  /// Returns the device of the terminal, e.g. `/dev/pts/3`, or null.
  static String? _ttyPath() {
    final name = _sh('ps -o tty= -p $pid');
    if (name == null || name.isEmpty || name.startsWith('?')) return null;
    return name.startsWith('/') ? name : '/dev/$name';
  }

  // ...........................................................................
  /// Runs `stty` on `/dev/tty`, as a child process gets no terminal stdin.
  static String? _stty(String arguments) => _sh('stty $arguments < /dev/tty');

  // ...........................................................................
  /// Runs [command] with `sh` and returns its output, or null on failure.
  static String? _sh(String command) {
    try {
      final result = Process.runSync('sh', ['-c', command]);
      return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
    } on ProcessException {
      return null;
    }
  }
}

// #############################################################################
/// Uses console modes and `ReadConsoleInputW` with virtual terminal input.
///
/// Dart restores the console modes itself when the process exits.
class _WindowsConsole implements GgParallelLogConsole {
  // ...........................................................................
  @override
  bool enableRawMode() {
    if (_getConsoleMode(_input, _count) == 0) return false;
    final mode = _count.value;
    const off = _processedInput | _lineInput | _echoInput;
    final raw = (mode & ~off) | _virtualTerminalInput;
    if (_setConsoleMode(_input, raw) == 0) return false;
    _saved = mode;
    return true;
  }

  // ...........................................................................
  @override
  void disableRawMode() {
    final saved = _saved;
    if (saved == null) return;
    read();
    _setConsoleMode(_input, saved);
    _saved = null;
  }

  // ...........................................................................
  @override
  String read() {
    if (_numberOfEvents(_input, _count) == 0 || _count.value == 0) return '';
    final wanted = _count.value < _maxRecords ? _count.value : _maxRecords;
    if (_readConsoleInput(_input, _records, wanted, _count) == 0) return '';
    final units = <int>[];
    for (var i = 0; i < _count.value; i++) {
      final record = _records + i * _recordSize;
      if (record.cast<Uint16>().value != _keyEvent) continue;
      final keyDown = (record + 4).cast<Int32>().value != 0;
      final repeat = (record + 8).cast<Uint16>().value;
      final char = (record + 14).cast<Uint16>().value;
      if (keyDown && char != 0) units.addAll(List.filled(repeat, char));
    }
    return String.fromCharCodes(units);
  }

  // ######################
  // Private
  // ######################

  static const int _processedInput = 0x0001;
  static const int _lineInput = 0x0002;
  static const int _echoInput = 0x0004;
  static const int _virtualTerminalInput = 0x0200;
  static const int _keyEvent = 1;
  static const int _maxRecords = 256;

  /// One `INPUT_RECORD`: type at 0, key down at 4, repeat at 8, char at 14.
  static const int _recordSize = 20;

  static final DynamicLibrary _kernel = DynamicLibrary.open('kernel32.dll');

  static final int Function(int) _getStdHandle = _kernel
      .lookupFunction<IntPtr Function(Int32), int Function(int)>(
        'GetStdHandle',
      );

  static final int Function(int, Pointer<Uint32>) _getConsoleMode = _kernel
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetConsoleMode');

  static final int Function(int, int) _setConsoleMode = _kernel
      .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'SetConsoleMode',
      );

  static final int Function(int, Pointer<Uint32>) _numberOfEvents = _kernel
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetNumberOfConsoleInputEvents');

  static final int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
  _readConsoleInput = _kernel
      .lookupFunction<
        Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
        int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
      >('ReadConsoleInputW');

  static final Pointer<Void> Function(int, int) _localAlloc = _kernel
      .lookupFunction<
        Pointer<Void> Function(Uint32, IntPtr),
        Pointer<Void> Function(int, int)
      >('LocalAlloc');

  static final int _input = _getStdHandle(-10);
  static final Pointer<Uint32> _count = _localAlloc(0x40, 4).cast();
  static final Pointer<Uint8> _records = _localAlloc(
    0x40,
    _recordSize * _maxRecords,
  ).cast();

  int? _saved;
}
