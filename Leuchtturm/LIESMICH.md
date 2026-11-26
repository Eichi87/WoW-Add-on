# Leuchtturm – Addon für WoW: Forever (v0.3)

## Installation
1. Den Ordner `Leuchtturm` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren
   (gibt es `_forever_` nicht, dann `_retail_`). Bei alten Versionen vorher den
   alten Ordner löschen.
2. Im Spiel prüfen: `/dump select(4, GetBuildInfo())` – steht da nicht `16001`,
   die Zahl in `Leuchtturm.toc` (`## Interface:`) anpassen.
3. Im Charakter-Auswahlbildschirm unter „AddOns" aktivieren.

Jeder von euch braucht den Ordner auf seinem eigenen PC. Die `Config.lua` kann
bei beiden gleich sein und alle eure Charaktere enthalten.

## Config
`Config.lua` mit einem Texteditor öffnen (z. B. Notepad++), Charakternamen eintragen,
im Spiel `/reload`. Klasse wird automatisch erkannt, Rolle und Spec kommen aus der Config.
Was die Leiste je Klasse anzeigt (Buffs, Waffenverzauberung, Begleiter, Seelensplitter,
Munition), steht ebenfalls dort und lässt sich frei ändern.

## Befehle
| Befehl        | Wirkung                                                  |
|---------------|----------------------------------------------------------|
| `/ltm`        | erkannter Charakter, Klasse, Rolle, Spec, aktive Module  |
| `/ltm leiste` | alle Einträge und Status (zeigt auch falsche Namen)      |
| `/ltm test`   | Warnungen durchspielen                                   |
| `/ltm reset`  | Leiste zurück in die Bildschirmmitte                     |

## Leiste
- Ein Button pro Eintrag. Linksklick wirkt den Zauber auf dich selbst,
  beim Jäger-Begleiter wirkt Rechtsklick „Tier wiederbeleben".
- Shift + Rechtsklick ziehen verschiebt die Leiste (nur außerhalb des Kampfes).
- Blass/grau: in Ordnung. Gelb: läuft bald aus / wird knapp / Begleiter unglücklich.
  Rot: fehlt bzw. leer. Seelensplitter und Munition zeigen immer ihre Anzahl.
- Zauber, die der Charakter noch nicht kennt, erscheinen nicht.

**Grenzen:**
- Im Kampf darf ein Addon in Forever keine Buffs lesen. Dann rechnet Leuchtturm
  ab deinem eigenen Cast hoch. Buffs, die du im Kampf von anderen bekommst
  (oder verlierst, z. B. durch Bannen), sieht es erst nach dem Kampf.
- Zaubernamen müssen exakt wie im deutschen Client geschrieben sein.
  `/ltm leiste` zeigt „nicht im Zauberbuch", wenn ein Name nicht passt.

## Neues Modul anlegen
Neue Datei in `Module\`, in `Leuchtturm.toc` eintragen, Aufbau wie `Leiste.lua`:
`ns:RegistriereModul{ name, klassen, specs, standard, init }`.
