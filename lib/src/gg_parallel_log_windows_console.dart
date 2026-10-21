// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Talks to the Windows console, which unit tests do not have.
// coverage:ignore-file

import 'dart:ffi';
import 'dart:io';

typedef _GetStdHandleC = IntPtr Function(Int32 handle);
typedef _GetStdHandle = int Function(int handle);
typedef _GetConsoleModeC = Int32 Function(IntPtr handle, Pointer<Uint32> mode);
typedef _GetConsoleMode = int Function(int handle, Pointer<Uint32> mode);
typedef _SetConsoleModeC = Int32 Function(IntPtr handle, Uint32 mode);
typedef _SetConsoleMode = int Function(int handle, int mode);
typedef _LocalAllocC = Pointer<Void> Function(Uint32 flags, IntPtr bytes);
typedef _LocalAlloc = Pointer<Void> Function(int flags, int bytes);
typedef _LocalFreeC = Pointer<Void> Function(Pointer<Void> memory);
typedef _LocalFree = Pointer<Void> Function(Pointer<Void> memory);

// #############################################################################
/// Switches the Windows console input to escape sequences for special keys.
///
/// Without it, Windows swallows arrow keys, Escape and Page Up/Down once
/// `stdin.lineMode` is off.
abstract final class GgParallelLogWindowsConsole {
  // ...........................................................................
  /// Enables virtual terminal input and returns the previous mode.
  ///
  /// Returns null on other platforms or when stdin is not a console.
  static int? enableVirtualTerminalInput() {
    if (!Platform.isWindows) return null;
    final handle = _kernel.getStdHandle(_stdInputHandle);
    final mode = _kernel.consoleMode(handle);
    if (mode == null) return null;
    _kernel.setConsoleMode(handle, mode | _virtualTerminalInput);
    return mode;
  }

  // ...........................................................................
  /// Restores the console input [mode] returned by the enable call.
  static void restoreInputMode(int mode) {
    if (!Platform.isWindows) return;
    _kernel.setConsoleMode(_kernel.getStdHandle(_stdInputHandle), mode);
  }

  // ######################
  // Private
  // ######################

  static const int _stdInputHandle = -10;
  static const int _virtualTerminalInput = 0x0200;
  static final _Kernel32 _kernel = _Kernel32();
}

// #############################################################################
class _Kernel32 {
  _Kernel32() : _library = DynamicLibrary.open('kernel32.dll');

  // ...........................................................................
  int getStdHandle(int handle) => _getStdHandle(handle);

  // ...........................................................................
  int? consoleMode(int handle) {
    final memory = _localAlloc(0x40, 4);
    try {
      final mode = memory.cast<Uint32>();
      return _getConsoleMode(handle, mode) == 0 ? null : mode.value;
    } finally {
      _localFree(memory);
    }
  }

  // ...........................................................................
  void setConsoleMode(int handle, int mode) => _setConsoleMode(handle, mode);

  // ######################
  // Private
  // ######################

  final DynamicLibrary _library;

  late final _GetStdHandle _getStdHandle = _library
      .lookupFunction<_GetStdHandleC, _GetStdHandle>('GetStdHandle');
  late final _GetConsoleMode _getConsoleMode = _library
      .lookupFunction<_GetConsoleModeC, _GetConsoleMode>('GetConsoleMode');
  late final _SetConsoleMode _setConsoleMode = _library
      .lookupFunction<_SetConsoleModeC, _SetConsoleMode>('SetConsoleMode');
  late final _LocalAlloc _localAlloc = _library
      .lookupFunction<_LocalAllocC, _LocalAlloc>('LocalAlloc');
  late final _LocalFree _localFree = _library
      .lookupFunction<_LocalFreeC, _LocalFree>('LocalFree');
}
