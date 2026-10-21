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

Übergib `runAll` eine Aufgabe pro Lane. Jede Aufgabe bekommt ihre Lane,
deren `log` überall passt, wo ein `GgLog` erwartet wird; alles, was eine
Aufgabe mit `print` ausgibt, landet ebenfalls in ihrer Lane. `runAll`
listet alle Lanes sofort, führt höchstens `concurrency` gleichzeitig aus,
hinterlässt die Zusammenfassung und liefert das Ergebnis. Aus
[example/gg_parallel_log_example.dart](example/gg_parallel_log_example.dart),
das die Veröffentlichung von acht Paketen simuliert:

```dart
final log = GgParallelLog(title: 'gg do publish');
final result = await log.runAll({
  for (final MapEntry(key: package, value: tests) in _packages.entries)
    package: (lane) => _publish(lane, tests),
}, concurrency: 3);
exitCode = result.exitCode;
```

Für volle Kontrolle legst du Lanes mit `log.lane(name)` an, führst Aufgaben
mit `log.run(name, task)` aus und rufst `log.finish()` in einem `finally`
auf. `run` wirft, was die Aufgabe wirft, oder eine
`GgParallelLogCancelledException`, sobald der Nutzer die Lane abbricht.
Einen Kindprozess protokolliert eine Lane mit `await lane.pipe(process)`;
beim Abbruch wird der ganze Prozessbaum beendet.

### Tasten

| Wo | Taste | Wirkung |
| --- | --- | --- |
| Übersicht | `↑` `↓` / `k` `j` | Lane auswählen |
| Übersicht | `⏎` / `→` | Lane im Vollbild öffnen |
| Übersicht | `f` | Nur fehlgeschlagene Lanes zeigen, oder wieder alle |
| Übersicht | `q` `q` | Alle laufenden Lanes abbrechen |
| Beide | `x` `x` | Ausgewählte Lane abbrechen |
| Beide | `s` | Ausgabe der Lane in eine Datei speichern |
| Vollbild | `↑` `↓` / `k` `j` | Zeilenweise scrollen |
| Vollbild | `b` `Space` / `PgUp` `PgDn` | Seitenweise scrollen |
| Vollbild | `g` `G` / `Home` `End` | Zum Anfang, dem Ende folgen |
| Vollbild | `←` `→` | Zur vorigen oder nächsten Lane wechseln |
| Vollbild | `/` `n` `N` | Suchen, zum nächsten oder vorigen Treffer springen |
| Vollbild | `Esc` | Zurück zur Übersicht |
| Überall | `Strg+C` | Alle Lanes abbrechen; ein zweites Mal beendet mit 130 |

![Eine fehlgeschlagene Lane im Vollbild mit Suche](doc/images/detail_search.png)

Sind alle Lanes fertig, weicht die Live-Ansicht einer Zusammenfassung.
Fehlgeschlagene Lanes kommen zuerst, mit ihren letzten 40 Zeilen und dem
Pfad zum vollständigen Log, die Ergebnistabelle steht zuletzt:

![Die Zusammenfassung, wenn alle Lanes fertig sind](doc/images/summary.png)

Ohne Terminal, etwa in CI oder einer Pipe, schreibt das Log jede Zeile mit
ihrer Lane als Präfix, gefolgt von derselben Zusammenfassung.

## Plattformen

Die Live-Ansicht läuft unter Linux, macOS und Windows. Tasten werden direkt
von der Konsole gelesen (`poll` unter POSIX, die Konsoleneingabe unter
Windows), daher bleibt Darts `stdin` unberührt und ein Programm kann danach
noch Rückfragen stellen. Solange die Ansicht offen ist, kommen `Strg+C`,
`Strg+Z` und `Strg+S` als Tasten statt als Signale an und treffen daher
keine Kindprozesse. Der Terminalzustand wird mit `stty -g` gesichert und
bei `finish`, `SIGTERM` und `SIGHUP` wiederhergestellt; stürzt das Programm
ab, stellt ihn unter POSIX ein kleiner Wächterprozess wieder her, unter
Windows Dart selbst. Die CI testet auf
allen drei Systemen und bedient die Live-Ansicht unter Linux und macOS in
tmux ([tool/interactive_smoke_test.sh](tool/interactive_smoke_test.sh)).

## Grenzen

- Abbrechen ist für Aufgaben kooperativ: `run` kehrt sofort zurück, eine
  Aufgabe läuft aber weiter, bis sie `lane.isCancelled` prüft; gepipte
  Prozesse werden samt Prozessbaum beendet
- Was direkt auf stdout geschrieben wird, etwa von einem Kindprozess mit
  `inheritStdio`, umgeht die Lanes und zerstört die Ansicht; leite es
  stattdessen in eine Lane
- Breiten stammen aus einer eingebauten Tabelle: Seltene Emoji und
  Terminals, die mehrdeutige Zeichen breit zeichnen, können um eine Spalte
  danebenliegen
- Die Ausgabe ist UTF-8; ein Terminal mit anderer Kodierung zeigt die
  Symbole verstümmelt
- GNU screen ohne `altscreen on` kann die Vollbildansicht nicht sauber
  zeigen

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
