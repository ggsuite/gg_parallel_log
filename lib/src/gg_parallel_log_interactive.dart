// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:gg_console_colors/gg_console_colors.dart';

import 'gg_parallel_log_detail.dart';
import 'gg_parallel_log_fake_terminal.dart';
import 'gg_parallel_log_key.dart';
import 'gg_parallel_log_lane.dart';
import 'gg_parallel_log_line.dart';
import 'gg_parallel_log_overview.dart';
import 'gg_parallel_log_renderer.dart';
import 'gg_parallel_log_saver.dart';
import 'gg_parallel_log_terminal.dart';
import 'gg_parallel_log_text.dart';
import 'gg_parallel_log_view_state.dart';

// #############################################################################
/// Shows an inline overview of all lanes and one lane in fullscreen.
///
/// Redraws on every [tick] and right after each key.
class GgParallelLogInteractive implements GgParallelLogRenderer {
  /// Creates the view of the [lanes] of the log called [title].
  GgParallelLogInteractive({
    required this.title,
    required this.terminal,
    required this._lanes,
    GgParallelLogSaver? saver,
    this.tick = const Duration(milliseconds: 100),
    void Function(int code)? exit,
  }) : saver = saver ?? GgParallelLogSaver(),
       _exit = exit ?? io.exit;

  /// Creates an example view on a fake terminal.
  factory GgParallelLogInteractive.example({
    GgParallelLogTerminal? terminal,
    List<GgParallelLogLane>? lanes,
    GgParallelLogSaver? saver,
    void Function(int code)? exit,
  }) {
    final all = lanes ?? [GgParallelLogLane.example()];
    return GgParallelLogInteractive(
      title: 'gg do publish',
      terminal: terminal ?? GgParallelLogFakeTerminal(),
      lanes: () => all,
      saver: saver,
      exit: exit,
    );
  }

  // ...........................................................................
  @override
  void start() {
    _startedAt = clock.now();
    terminal.enableRawMode();
    terminal.write(_hideCursor);
    _subscriptions.addAll([
      terminal.input.listen(_onInput),
      terminal.interrupts.listen((_) => _onInterrupt()),
    ]);
    _timer = Timer.periodic(tick, (_) => render());
    render();
  }

  // ...........................................................................
  @override
  void laneChanged(GgParallelLogLane lane, GgParallelLogLine? line) {}

  // ...........................................................................
  @override
  Future<void> finish(String summary) async {
    if (_isFinished) return;
    _isFinished = true;
    _timer?.cancel();
    // Windows closes stdin on cancel, so restore its mode before
    terminal.disableRawMode();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (_state.mode != GgParallelLogMode.overview) {
      terminal.write(_leaveFullscreen);
    }
    terminal.write('${_toBlockStart()}\x1B[J$summary$_showCursor');
  }

  // ...........................................................................
  /// Draws the current view, unless it did not change since the last time.
  void render() {
    if (_isFinished) return;
    _clampState();
    if (_state.mode == GgParallelLogMode.overview) {
      _renderOverview();
    } else {
      _renderDetail();
    }
  }

  // ...........................................................................
  /// The title shown in the overview.
  final String title;

  /// The terminal drawn on.
  final GgParallelLogTerminal terminal;

  /// The time between two redraws.
  final Duration tick;

  /// Saves the output of a lane when the user presses s.
  final GgParallelLogSaver saver;

  /// What the view currently shows.
  GgParallelLogViewState get state => _state;

  // ######################
  // Private
  // ######################

  static const String _hideCursor = '\x1B[?25l';
  static const String _showCursor = '\x1B[?25h';
  static const String _enterFullscreen = '\x1B[?1049h\x1B[2J';
  static const String _leaveFullscreen = '\x1B[?1049l';
  static const String _syncStart = '\x1B[?2026h';
  static const String _syncEnd = '\x1B[?2026l';

  final List<GgParallelLogLane> Function() _lanes;
  final void Function(int code) _exit;
  final List<StreamSubscription<void>> _subscriptions = [];
  GgParallelLogViewState _state = const GgParallelLogViewState();
  String? _selectedName;
  DateTime _startedAt = clock.now();
  Timer? _timer;
  bool _isFinished = false;
  bool _isInterrupted = false;
  String? _lastFrame;
  int _lastWidth = 0;
  List<String> _blockLines = [];

  // ...........................................................................
  List<GgParallelLogLane> get _visible => _state.visibleLanes(_lanes());

  GgParallelLogLane? get _selectedLane {
    final visible = _visible;
    return visible.isEmpty ? null : visible[_state.selected];
  }

  int get _frame => clock.now().difference(_startedAt).inMilliseconds ~/ 80;

  int get _bodyHeight => GgParallelLogDetail.bodyHeight(terminal.height);

  // ...........................................................................
  void _renderOverview() {
    final lines = GgParallelLogOverview(
      title: title,
      lanes: _lanes(),
      state: _state,
      width: terminal.width,
      height: terminal.height,
      elapsed: clock.now().difference(_startedAt),
      frame: _frame,
    ).lines();
    if (!_changed(lines)) return;
    final body = lines.map((line) => '$line\x1B[K').join('\r\n');
    terminal.write('$_syncStart${_toBlockStart()}$body\x1B[J$_syncEnd');
    _blockLines = lines;
  }

  // ...........................................................................
  void _renderDetail() {
    final visible = _visible;
    if (visible.isEmpty) {
      _setMode(GgParallelLogMode.overview);
      _renderOverview();
      return;
    }
    final lines = GgParallelLogDetail(
      lane: visible[_state.selected],
      state: _state,
      index: _state.selected,
      count: visible.length,
      width: terminal.width,
      height: terminal.height,
      frame: _frame,
    ).lines();
    if (!_changed(lines)) return;
    final body = lines.map((line) => '$line\x1B[K').join('\r\n');
    terminal.write('$_syncStart\x1B[H$body\x1B[J$_syncEnd');
  }

  // ...........................................................................
  bool _changed(List<String> lines) {
    final frame = lines.join('\n');
    if (frame == _lastFrame && terminal.width == _lastWidth) return false;
    _lastFrame = frame;
    _lastWidth = terminal.width;
    return true;
  }

  // ...........................................................................
  /// Moves the cursor to the first row of the inline block drawn last.
  String _toBlockStart() {
    if (_blockLines.isEmpty) return '';
    final width = max(1, terminal.width);
    final rows = _blockLines.fold(0, (sum, line) {
      final w = GgParallelLogText.visibleWidth(line);
      return sum + max(1, (w / width).ceil());
    });
    return rows > 1 ? '\r\x1B[${rows - 1}A' : '\r';
  }

  // ...........................................................................
  void _clampState() {
    final visible = _visible;
    var index = visible.indexWhere((l) => l.name == _selectedName);
    if (index < 0) index = _state.selected.clamp(0, max(0, visible.length - 1));
    _selectedName = visible.isEmpty ? null : visible[index].name;
    if (index != _state.selected) _state = _state.copyWith(selected: index);
  }

  // ...........................................................................
  void _setMode(GgParallelLogMode mode) {
    const overview = GgParallelLogMode.overview;
    if (_state.mode == overview && mode != overview) {
      terminal.write(_enterFullscreen);
    }
    if (_state.mode != overview && mode == overview) {
      terminal.write(_leaveFullscreen);
    }
    _state = _state.copyWith(mode: mode);
    _lastFrame = null;
  }

  // ...........................................................................
  void _onInput(String input) {
    for (final key in GgParallelLogKey.parse(input)) {
      _onKey(key);
    }
    render();
  }

  // ...........................................................................
  void _onInterrupt() {
    if (_isInterrupted) {
      unawaited(finish('').then((_) => _exit(130)));
      return;
    }
    _isInterrupted = true;
    for (final lane in _lanes()) {
      lane.cancel();
    }
    _state = _state.copyWith(
      notice: cWarn('Cancelled all lanes · Ctrl+C again to exit'),
    );
    render();
  }

  // ...........................................................................
  void _onKey(GgParallelLogKey key) {
    if (key.type == GgParallelLogKeyType.ctrlC) return _onInterrupt();
    final confirm = _state.confirm;
    _state = _state.copyWith(notice: '', confirm: GgParallelLogConfirm.none);
    switch (_state.mode) {
      case GgParallelLogMode.overview:
        _onOverviewKey(key, confirm);
      case GgParallelLogMode.detail:
        _onDetailKey(key, confirm);
      case GgParallelLogMode.search:
        _onSearchKey(key);
    }
  }

  // ...........................................................................
  void _onOverviewKey(GgParallelLogKey key, GgParallelLogConfirm confirm) {
    if (_isUp(key)) return _select(_state.selected - 1);
    if (_isDown(key)) return _select(_state.selected + 1);
    if (key.type == GgParallelLogKeyType.home) return _select(0);
    if (key.type == GgParallelLogKeyType.end) return _select(_visible.length);
    if (_isRight(key) || key.type == GgParallelLogKeyType.enter) {
      if (_selectedLane != null) _setMode(GgParallelLogMode.detail);
      return;
    }
    if (key.isChar('f')) {
      _state = _state.copyWith(errorsOnly: !_state.errorsOnly);
      return;
    }
    if (key.isChar('q')) return _cancelAll(confirm);
    _onLaneKey(key, confirm);
  }

  // ...........................................................................
  void _onDetailKey(GgParallelLogKey key, GgParallelLogConfirm confirm) {
    final type = key.type;
    if (type == GgParallelLogKeyType.escape || key.isChar('q')) {
      return _setMode(GgParallelLogMode.overview);
    }
    if (_isLeft(key)) return _switchLane(-1);
    if (_isRight(key)) return _switchLane(1);
    if (_isUp(key)) return _scrollTo(_state.scroll + 1);
    if (_isDown(key)) return _scrollTo(_state.scroll - 1);
    if (type == GgParallelLogKeyType.pageUp) {
      return _scrollTo(_state.scroll + _bodyHeight);
    }
    if (type == GgParallelLogKeyType.pageDown) {
      return _scrollTo(_state.scroll - _bodyHeight);
    }
    if (type == GgParallelLogKeyType.home || key.isChar('g')) {
      return _scrollTo(_selectedLane!.lines.length);
    }
    if (type == GgParallelLogKeyType.end || key.isChar('G')) {
      return _scrollTo(0);
    }
    if (key.isChar('/')) {
      _state = _state.copyWith(input: '');
      return _setMode(GgParallelLogMode.search);
    }
    if (key.isChar('n')) return _jump(1);
    if (key.isChar('N')) return _jump(-1);
    _onLaneKey(key, confirm);
  }

  // ...........................................................................
  void _onSearchKey(GgParallelLogKey key) {
    switch (key.type) {
      case GgParallelLogKeyType.escape:
        _setMode(GgParallelLogMode.detail);
      case GgParallelLogKeyType.enter:
        _setMode(GgParallelLogMode.detail);
        _search(_state.input);
      case GgParallelLogKeyType.backspace:
        final input = _state.input;
        final shorter = input.isEmpty
            ? ''
            : input.substring(0, input.length - 1);
        _state = _state.copyWith(input: shorter);
      case GgParallelLogKeyType.char:
        _state = _state.copyWith(input: '${_state.input}${key.char}');
      default:
        break;
    }
  }

  // ...........................................................................
  void _onLaneKey(GgParallelLogKey key, GgParallelLogConfirm confirm) {
    final lane = _selectedLane;
    if (lane == null) return;
    if (key.isChar('s')) {
      final file = saver.save(lane);
      _state = _state.copyWith(notice: 'Saved ${lane.name} to ${file.path}');
    }
    if (!key.isChar('x')) return;
    if (lane.status.isDone) {
      _state = _state.copyWith(notice: '${lane.name} is already done');
    } else if (confirm == GgParallelLogConfirm.cancelLane) {
      lane.cancel();
      _state = _state.copyWith(notice: cWarn('Cancelled ${lane.name}'));
    } else {
      _state = _state.copyWith(confirm: GgParallelLogConfirm.cancelLane);
    }
  }

  // ...........................................................................
  void _cancelAll(GgParallelLogConfirm confirm) {
    final running = _lanes().where((l) => !l.status.isDone).toList();
    if (running.isEmpty) {
      _state = _state.copyWith(notice: 'No running lanes');
    } else if (confirm == GgParallelLogConfirm.cancelAll) {
      for (final lane in running) {
        lane.cancel();
      }
      _state = _state.copyWith(
        notice: cWarn('Cancelled ${running.length} lanes'),
      );
    } else {
      _state = _state.copyWith(confirm: GgParallelLogConfirm.cancelAll);
    }
  }

  // ...........................................................................
  void _select(int index) {
    final visible = _visible;
    if (visible.isEmpty) return;
    final selected = index.clamp(0, visible.length - 1);
    _selectedName = visible[selected].name;
    _state = _state.copyWith(selected: selected);
  }

  // ...........................................................................
  void _switchLane(int delta) {
    _select(_state.selected + delta);
    _state = _state.copyWith(scroll: 0, match: -1);
  }

  // ...........................................................................
  void _scrollTo(int scroll) {
    final total = _selectedLane!.lines.length;
    final maxScroll = max(0, total - _bodyHeight);
    _state = _state.copyWith(scroll: scroll.clamp(0, maxScroll));
  }

  // ...........................................................................
  void _search(String query) {
    _state = _state.copyWith(query: query, match: -1);
    final matches = GgParallelLogDetail.matches(_selectedLane!, query);
    if (query.isNotEmpty && matches.isEmpty) {
      _state = _state.copyWith(notice: cWarn('No match for "$query"'));
      return;
    }
    if (matches.isNotEmpty) _showLine(matches.last);
  }

  // ...........................................................................
  void _jump(int direction) {
    final matches = GgParallelLogDetail.matches(_selectedLane!, _state.query);
    if (matches.isEmpty) return;
    final current = _state.match;
    final next = direction > 0
        ? matches.firstWhere((m) => m > current, orElse: () => matches.first)
        : matches.lastWhere((m) => m < current, orElse: () => matches.last);
    _showLine(next);
  }

  // ...........................................................................
  void _showLine(int index) {
    final total = _selectedLane!.lines.length;
    final body = _bodyHeight;
    _state = _state.copyWith(match: index);
    _scrollTo(total - (index - body ~/ 2) - body);
  }

  // ...........................................................................
  static bool _isUp(GgParallelLogKey key) =>
      key.type == GgParallelLogKeyType.up || key.isChar('k');

  static bool _isDown(GgParallelLogKey key) =>
      key.type == GgParallelLogKeyType.down || key.isChar('j');

  static bool _isLeft(GgParallelLogKey key) =>
      key.type == GgParallelLogKeyType.left || key.isChar('h');

  static bool _isRight(GgParallelLogKey key) =>
      key.type == GgParallelLogKeyType.right || key.isChar('l');
}
