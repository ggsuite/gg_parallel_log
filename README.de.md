# gg_parallel_log

[English](README.md) | Deutsch

[![CI](https://github.com/ggsuite/gg_parallel_log/actions/workflows/quick_check.yaml/badge.svg)](https://github.com/ggsuite/gg_parallel_log/actions/workflows/quick_check.yaml)
[![pub package](https://img.shields.io/pub/v/gg_parallel_log.svg)](https://pub.dev/packages/gg_parallel_log)

Interaktiver Kommandozeilen-Logger für parallele Prozesse: Übersicht direkt
im Terminal, Vollbild-Ansicht pro Lane, Fehlerfilter, Suche, Abbrechen und
eine schlichte Ausgabe ohne Terminal.

![Die Live-Übersicht über acht parallele Lanes](doc/images/overview.png)

## Motivation

Werkzeuge wie `gg` erledigen vieles gleichzeitig: Tests, Analyse und
Veröffentlichen über ein Dutzend Repositories hinweg. Landet all das in
einem Terminal, vermischt sich die Ausgabe zu einer Textwand, und die eine
Zeile, auf die es ankommt, der Fehler, geht darin unter.

`gg_parallel_log` gibt jedem Prozess eine eigene Lane und zeigt sie so,
wie es die Konsole von Claude Code tut:

- Eine kompakte Live-Übersicht bleibt unten im Terminal stehen, eine Zeile
  pro Lane, während der Verlauf darüber unberührt bleibt
- Jede Lane öffnet sich im Vollbild mit ihrer kompletten Ausgabe,
  einschließlich Suche
- Fehlgeschlagene Lanes werden am Ende wiederholt, damit kein Fehler mit
  der Live-Ansicht verschwindet
- Jede Lane ist ein gewöhnliches `GgLog`, daher läuft bestehender Code, der
  ein `ggLog` erwartet, ohne Änderung parallel

## Installation

```bash
dart pub add gg_parallel_log
```

## Verwendung

Lege ein Log an, führe jede Aufgabe in einer Lane aus und schließe das Log
am Ende ab. Die Lane reicht ihr `log` überall weiter, wo ein `GgLog`
erwartet wird; alles, was eine Aufgabe mit `print` ausgibt, landet ebenfalls
in ihrer Lane. Aus
[example/gg_parallel_log_example.dart](example/gg_parallel_log_example.dart),
das die Veröffentlichung von acht Paketen simuliert, drei gleichzeitig:

```dart
final log = GgParallelLog(title: 'gg do publish');
final queue = [..._packages.keys];
for (final package in queue) {
  log.lane(package);
}

Future<void> worker() async {
  while (queue.isNotEmpty) {
    final package = queue.removeAt(0);
    try {
      await log.run(package, (lane) => _publish(lane, _packages[package]!));
    } catch (_) {
      // The lane shows the error; the other packages go on.
    }
  }
}

try {
  await Future.wait([for (var i = 0; i < 3; i++) worker()]);
} finally {
  // Restores the terminal and leaves the summary, even after a crash.
  await log.finish();
}
```

Einen Kindprozess protokolliert eine Lane mit `await lane.pipe(process)`;
bricht der Nutzer die Lane ab, wird der Prozess beendet.

### Tasten

| Wo | Taste | Wirkung |
| --- | --- | --- |
| Übersicht | `↑` `↓` / `k` `j` | Lane auswählen |
| Übersicht | `⏎` / `→` | Lane im Vollbild öffnen |
| Übersicht | `f` | Nur fehlgeschlagene Lanes zeigen, oder wieder alle |
| Übersicht | `q` `q` | Alle laufenden Lanes abbrechen |
| Beide | `x` `x` | Ausgewählte Lane abbrechen |
| Beide | `s` | Ausgabe der Lane in eine Datei speichern |
| Vollbild | `↑` `↓` `PgUp` `PgDn` `Home` `End` | Scrollen; `End` folgt der Ausgabe |
| Vollbild | `←` `→` | Zur vorigen oder nächsten Lane wechseln |
| Vollbild | `/` `n` `N` | Suchen, zum nächsten oder vorigen Treffer springen |
| Vollbild | `Esc` | Zurück zur Übersicht |
| Überall | `Strg+C` | Alle Lanes abbrechen; ein zweites Mal beendet |

![Eine fehlgeschlagene Lane im Vollbild mit Suche](doc/images/detail_search.png)

Sind alle Lanes fertig, weicht die Live-Ansicht einer Zusammenfassung.
Fehlgeschlagene Lanes kommen zuerst, mit ihren letzten 40 Zeilen und dem
Pfad zum vollständigen Log, die Ergebnistabelle steht zuletzt:

![Die Zusammenfassung, wenn alle Lanes fertig sind](doc/images/summary.png)

Ohne Terminal, etwa in CI oder einer Pipe, schreibt das Log jede Zeile mit
ihrer Lane als Präfix, gefolgt von derselben Zusammenfassung.

## Grenzen

- Es protokolliert, es plant nicht: Wie viele Aufgaben gleichzeitig und in
  welcher Reihenfolge laufen, entscheidet der Aufrufer
- Die interaktive Ansicht liest stdin, das ein Prozess nur einmal abhören
  kann; Aufgaben dürfen stdin nicht lesen, solange die Ansicht offen ist
- Was direkt auf stdout geschrieben wird, etwa von einem Kindprozess mit
  `inheritStdio`, umgeht die Lanes und zerstört die Ansicht; leite es
  stattdessen in eine Lane
- Breite Zeichen werden mit einer eingebauten Tabelle vermessen; seltene
  Emoji können um eine Spalte danebenliegen

## Dokumentation

- [Code-Guide](doc/guides/code-guide.md)
- [Test-Guide](doc/guides/test-guide.md)
- [Entwicklungs-Guide](doc/guides/develop-guide.md)

## Status

Vor 1.0 kann sich die API zwischen Minor-Versionen ändern.

## Mitwirken

Folge dem [Entwicklungs-Guide](doc/guides/develop-guide.md).

## Lizenz

MIT, siehe [LICENSE](LICENSE).
