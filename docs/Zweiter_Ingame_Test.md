# Leuchtturm v0.4.1 – zweiter Ingame-Test

Dauer: etwa 10 Minuten. Diese Version behebt die Befunde aus dem ersten Test
(Guile als „Unbekannt", Berufe nach dem Ausloggen weg, 0 Rezepte).

## Installieren
1. Im Ordner `World of Warcraft\_forever_\Interface\AddOns\` den alten Ordner `Leuchtturm` löschen.
2. Den Ordner `Leuchtturm` aus der ZIP dorthin kopieren.
   Guile und Gomez stehen schon in der `Config.lua`. Weitere Charaktere trägst du bei Bedarf selbst ein.

## Testen
| Schritt | Erwartung |
|---|---|
| Mit Guile einloggen, `/ltm` eingeben | Spieler: Daniel, Rolle DD |
| Schmiedekunst-Fenster öffnen | im Chat: „Schmiedekunst: … Rezepte gespeichert." |
| Bergbau bzw. Verhüttung öffnen | im Chat: „Bergbau: … Rezepte gespeichert." |
| Kommt keine solche Zeile: bei **offenem** Fenster `/ltm diagnose` eingeben | Screenshot davon an mich |
| `/ltm daten` | Guile mit Rezeptzahlen. Gomez zeigt „Rezepte offen", bis du seine Berufe einmal öffnest |
| Ausloggen, mit Gomez einloggen, Schneiderei und Verzauberkunst öffnen, `/ltm daten` | beide Charaktere unter Daniel, alle Berufe mit Rezeptzahlen |
| `/ltm hinweis` + Shift-Klick auf Leinenstoff, Kupferbarren oder ein anderes Material | Hinweis, wer es zum Leveln braucht |
| Maus über eine Rüstung in der Tasche oder beim Händler | eventuell eine Zeile „Könnte brauchen: Daniels Hexenmeister (Gomez) …" |

## Was ich zurück brauche
- Screenshot von `/ltm daten` nach beiden Charakteren
- falls Rezepte fehlen: Screenshot von `/ltm diagnose` bei offenem Berufsfenster
- jede rote Lua-Fehlermeldung
