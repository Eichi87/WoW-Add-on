# Leuchtturm – Addon für WoW: Forever (v0.4.2)

Zwei Teile:
- **Klassen-Leiste** (seit v0.3): erinnert an fehlende/auslaufende Buffs und Ressourcen, Klick wirkt den Zauber.
- **Hinweissystem** (neu in v0.4): merkt sich alle eure Charaktere (Berufe, Rezepte, Ausrüstung) und sagt euch
  beim Looten und im Tooltip, welcher Charakter von wem etwas brauchen kann – über alle Spieler hinweg.

## Installation
1. Den Ordner `Leuchtturm` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren
   (gibt es `_forever_` nicht, dann `_retail_`). Bei alten Versionen vorher den alten
   Ordner `Leuchtturm` löschen – der Ordner `Leuchtturm_Sync` daneben bleibt stehen.
2. Im Spiel prüfen: `/dump select(4, GetBuildInfo())` – steht da nicht `16001`,
   die Zahl in `Leuchtturm.toc` (`## Interface:`) anpassen.
3. Im Charakter-Auswahlbildschirm unter „AddOns" aktivieren.

Jeder von euch braucht den Ordner auf seinem eigenen PC. Die `Config.lua` kann
bei allen gleich sein und alle eure Charaktere enthalten.

## Config
`Config.lua` mit einem Texteditor öffnen (z. B. Notepad++), Charakternamen eintragen und
bei jedem Charakter `spieler` setzen (Daniel, Julia, später Björn …), im Spiel `/reload`.
Fehlt ein Charakter in der Config, ordnet Leuchtturm ihn automatisch dem Spieler zu, dem die
anderen Charaktere dieses WoW-Kontos gehören. Nur wenn auf einem Konto noch gar kein Charakter
bekannt ist, einmal `/ltm ich Daniel` (bzw. Julia) eingeben. Ohne Config-Eintrag gilt Rolle „DD".
Klasse wird automatisch erkannt, Rolle und Spec kommen aus der Config. Was die Leiste je
Klasse anzeigt, steht ebenfalls dort. Unter `module` lässt sich jedes Modul abschalten.

## Befehle
| Befehl           | Wirkung                                                           |
|------------------|-------------------------------------------------------------------|
| `/ltm`           | erkannter Charakter, Klasse, Rolle, Spec, aktive Module, Befehle  |
| `/ltm leiste`    | alle Einträge der Leiste und Status (zeigt auch falsche Namen)    |
| `/ltm test`      | Warnungen der Leiste durchspielen                                 |
| `/ltm verschieben` | Leiste entsperren: ziehen = verschieben, Mausrad = Größe; nochmal eingeben = fertig |
| `/ltm groesse 80` | Größe der Leiste in Prozent (50–250)                            |
| `/ltm reset`     | Leiste zurück in die Bildschirmmitte, Größe 100 %                 |
| `/ltm daten`     | alle Spieler und Charaktere mit Berufen, Rezeptzahl und Datenstand |
| `/ltm neu`       | neu laden (= `/reload`), um frische Daten der anderen einzulesen  |
| `/ltm hinweis [Link]` | Hinweise zu einem Gegenstand (Link per Shift-Klick einfügen) |
| `/ltm ich Name`  | Spieler für dieses WoW-Konto setzen (meist nicht nötig, siehe unten) |
| `/ltm diagnose`  | technische Infos zur Fehlersuche (bei offenem Berufsfenster)      |

## Leiste
- Ein Button pro Eintrag. Linksklick wirkt den Zauber auf dich selbst,
  beim Jäger-Begleiter wirkt Rechtsklick „Tier wiederbeleben".
- Verschieben und Größe: `/ltm verschieben` eingeben, dann erscheint ein blauer Griff über der Leiste.
  Mit der linken Maustaste ziehen, mit dem Mausrad die Größe ändern (5-%-Schritte), zum Abschluss
  wieder `/ltm verschieben`. Alternativ `/ltm groesse 80` bzw. Shift + Rechtsklick ziehen.
  Geht nur außerhalb des Kampfes (bei Kampfbeginn sperrt sich die Leiste automatisch) und wird je
  Charakter gespeichert.
- Blass/grau: in Ordnung. Gelb: läuft bald aus / wird knapp / Begleiter unglücklich.
  Rot: fehlt bzw. leer. Seelensplitter und Munition zeigen immer ihre Anzahl.
- Zauber, die der Charakter noch nicht kennt, erscheinen nicht.

## Hinweissystem
**Was gespeichert wird** (bei Login, Logout, jedem Ausrüstungswechsel, Stufen- und Skill-Änderung):
Name, Klasse, Rolle/Spec, Stufe, Berufe mit Skill, getragene Ausrüstung je Slot und ein Zeitstempel.
**Rezepte** liefert das Spiel nur bei offenem Berufsfenster: also jeden Beruf **einmal öffnen**,
danach aktualisiert sich die Liste bei jedem Öffnen; Leuchtturm meldet dann z. B. „Schmiedekunst: 42 Rezepte
gespeichert.". `/ltm daten` zeigt „Rezepte offen", solange ein Beruf noch nicht geöffnet wurde.
Angeln, Erste Hilfe und Kochen werden ignoriert.

**Beim Looten** (Beutefenster oder „Ihr erhaltet …") erscheint im Chat:
- *Rezept fehlt bei:* alle Charaktere mit dem Beruf, die das Rezept noch nicht kennen
  (zu niedriger Skill steht grau dahinter).
- *Zum Leveln gebraucht von:* wer das Material noch braucht (mindestens ein Rezept damit ist nicht grau).
  Stoff zählt dadurch nur für Schneider.
- *Upgrade … für … – herstellbar von …:* was ein Handwerker daraus herstellen kann, das für einen
  Charakter ein Upgrade wäre (z. B. Kupferkettenweste für den neuen Paladin).

**Im Tooltip** jedes Gegenstands (bei Rezepten: des Ergebnis-Gegenstands) steht
*Könnte brauchen: Julias Priesterin (Name), trägt aktuell Robe der Eule*, wenn Slot, Rüstungstyp,
Klasse und Mindeststufe passen und der Rüstungswert mindestens 95 % des getragenen beträgt
(Schmuck, Ringe, Hals, Umhang, Waffen: Mindeststufe statt Rüstung). Daneben öffnet sich der getragene
Gegenstand als Vergleichs-Tooltip. Der gerade gespielte Charakter fehlt dort – für ihn vergleicht das
Spiel selbst (Shift).

## Datenabgleich mit Syncthing
Ein Addon darf keine Dateien lesen und keine Verbindungen aufbauen. Deshalb gibt es ein Hilfsskript.

**Einmalig einrichten (jeder auf seinem PC):**
1. Python 3 installieren (python.org, beim Setup „Add to PATH" anhaken).
2. In Syncthing einen gemeinsamen Ordner anlegen:
   `World of Warcraft\_forever_\Interface\AddOns\Leuchtturm_Sync` – mit allen Mitspielern teilen.
3. Den Ordner `Werkzeug` (aus dem Repo) irgendwohin kopieren, `leuchtturm_sync.ini` öffnen,
   `wow_ordner` und `spieler` eintragen (Julia trägt `spieler = Julia` ein).

**Beim Spielen:** `Abgleich_starten.bat` doppelklicken und das Fenster offen lassen.
Das Skript kopiert nach jedem Logout/Charakterwechsel/Reload deine Variablen-Datei als
`Leuchtturm_Sync\<Spieler>.lua` (jeder schreibt nur seine eigene) und baut daraus
`Leuchtturm\Index.lua`. Neue Spieler tauchen dadurch automatisch auf.

Das Spiel liest die Daten der anderen nur beim Login oder Reload. Beim Login meldet Leuchtturm,
wie alt die Daten der anderen sind; `/ltm daten` zeigt alles, `/ltm neu` lädt frische Daten ein.

**Grenzen:**
- Im Kampf darf ein Addon in Forever keine Buffs lesen. Dann rechnet die Leiste
  ab deinem eigenen Cast hoch. Buffs, die du im Kampf von anderen bekommst
  (oder verlierst, z. B. durch Bannen), sieht sie erst nach dem Kampf.
- Zaubernamen müssen exakt wie im deutschen Client geschrieben sein.
  `/ltm leiste` zeigt „nicht im Zauberbuch", wenn ein Name nicht passt.
- Rezept-Gegenstände werden über den Namen erkannt („Muster: Kupferweste" → Rezept „Kupferweste").

## Neues Modul anlegen
Neue Datei in `Module\`, in `Leuchtturm.toc` eintragen, Aufbau wie `Leiste.lua`:
`ns:RegistriereModul{ name, klassen, specs, standard, init }`. Gemeinsame Hilfen für
Charaktere, Gegenstände und Berufe stehen in `Wissen.lua` (`ns.W`).

## Tests
`tests/alle_tests.sh` spielt alles in einer nachgebauten WoW-Umgebung durch
(Lua 5.1 + Python 3): zwei PCs, Syncthing per Kopie nachgestellt.
