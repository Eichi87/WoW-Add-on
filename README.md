# Leuchtturm – WoW: Forever Addon

Eigenes Addon für Daniel und Julia (WoW: Forever, Interface 16001). Eine Klassen-Leiste
erinnert an fehlende oder auslaufende Buffs und Ressourcen; ein Klick wirkt den Zauber.
Keine Automatisierung. Dazu ein charakterübergreifendes Hinweissystem: wer braucht dieses
Rezept, dieses Material, diesen Gegenstand – über alle Spieler, abgeglichen per Syncthing.

Aktueller Stand: **v0.4.1** (v0.4.0 einmal im Spiel getestet, Befunde behoben; v0.4.1 noch nicht im Spiel getestet).

## Inhalt
- [`Leuchtturm/`](Leuchtturm/) – der Addon-Ordner, so wie er nach `Interface\AddOns\` kopiert wird
- [`Leuchtturm/LIESMICH.md`](Leuchtturm/LIESMICH.md) – Installation, Config, Befehle, Bedienung
- [`Werkzeug/`](Werkzeug/) – Hilfsskript für den Datenabgleich per Syncthing (Python 3)
- [`tests/`](tests/) – nachgebaute WoW-Umgebung und Gesamttest (`sh tests/alle_tests.sh`)
- [`docs/Erster_Ingame_Test.md`](docs/Erster_Ingame_Test.md), [`docs/Zweiter_Ingame_Test.md`](docs/Zweiter_Ingame_Test.md) – Anleitungen für die Tests im Spiel
- [`docs/Leuchtturm_Uebergabe.md`](docs/Leuchtturm_Uebergabe.md) – Rahmenbedingungen, Aufbau, Entscheidungen, offene Punkte

## Installation (kurz)
Ordner `Leuchtturm` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren,
`Config.lua` anpassen, im Spiel `/reload`. Details stehen in der [LIESMICH](Leuchtturm/LIESMICH.md).
