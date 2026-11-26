# Leuchtturm – Übergabe (Stand 26.11.2026, v0.4.1)

Eigenes WoW-Forever-Addon für Daniel und Julia (weitere Spieler wie Björn möglich).
- Klassen-Leiste (v0.3): erinnert an fehlende/auslaufende Buffs und Ressourcen, Klick wirkt den Zauber, keine Automatisierung.
- Hinweissystem (v0.4, Ausbaustufe 2): charakterübergreifende Datenbasis, Hinweise beim Looten, Ausrüstungsbedarf über Handwerk, Tooltips, Datenabgleich per Syncthing. Keine Berufs-Leveling-Hilfe, keine Armory-Anbindung.

## Rahmenbedingungen (WoW: Forever)
- Forever läuft auf dem modernen Client (Mainline-API ca. 12.1.5), nicht auf Classic. Interface-Nummer laut Warcraft Wiki: 16001.
- Midnight-Addon-Einschränkungen gelten: Im Kampf sind Buffs (ggf. auch Waffenverzauberungen, Pet-Daten) „Secret Values“ und nicht lesbar. Lösung im Addon: außerhalb des Kampfes echt lesen, im Kampf ab eigenem Cast hochrechnen, Dauer lernen.
- Autocast ist weder erlaubt noch möglich. Erlaubt: SecureActionButton, Klick wirkt Zauber. Attribute, Show/Hide und Positionen nur außerhalb des Kampfes ändern, Alpha/Texturen/Text gehen immer.
- Ein Addon darf keine Netzwerkverbindungen aufbauen, keine Dateien lesen und nur seine eigenen gespeicherten Variablen schreiben. Lua-Dateien werden nur beim Login/Reload geladen, und nur die in der .toc. Darum läuft der Abgleich über ein Python-Hilfsskript, das `Index.lua` erzeugt.

## Aufbau
- `Leuchtturm.toc` – Interface 16001, Version 0.4.0, SavedVariables: LeuchtturmDB (kontoweit), SavedVariablesPerCharacter: LeuchtturmCharDB
- `Config.lua` – Charaktere (Name → spieler, klasse, rolle, spec), Leisten-Einträge je Klasse, Moduleinstellungen
- `Index.lua` – vom Hilfsskript erzeugt (Platzhalter im Repo): Metadaten + Inhalt aller Spielerdateien
- `Core.lua` – erkennt Charakter/Klasse/Spieler, liest Config, startet Module, Chatbefehle `/ltm`
- `Wissen.lua` – Berufe-Tabelle, alle Charaktere aller Spieler, Gegenstandsauswertung, Upgrade-Prüfung (`ns.W`)
- `Module/Leiste.lua` – die Leiste; Arten: buff, waffe, pet, zaehler, munition
- `Module/Daten.lua` – Schritt 1, Datenbasis in `LeuchtturmDB.spieler[Spieler].charaktere["Name-Realm"]`
- `Module/Beute.lua` – Schritt 2 und 3, Hinweise beim Looten (Rezept, Zutat, Upgrade über Handwerk)
- `Module/Tooltip.lua` – Schritt 4, „Könnte brauchen“ + bis zu 2 Vergleichs-Tooltips
- `Module/Abgleich.lua` – Schritt 5 Addon-Seite: liest Index, Datenstand, `/ltm daten`, `/ltm neu`
- `Werkzeug/leuchtturm_sync.py` + `leuchtturm_sync.ini` + `Abgleich_starten.bat` – Schritt 5 Hilfsskript
- `tests/` – Mock-Umgebung (Lua 5.1) und Gesamttest mit zwei PCs

## Entscheidungen
- Zaubernamen (deutscher Client) statt IDs in der Config; gewirkt wird der erste bekannte Name einer Liste.
- Rolle statt Spec als Hauptfilter (Tank/Heiler/DD, ohne Angabe = DD).
- Krieger-Schlachtruf warnt nur im Kampf, alle anderen Einträge auch außerhalb.
- Klick wirkt immer auf den Spieler selbst (unit = player).
- Nach Ladebildschirm 3 s Ruhe, Warnton höchstens 1×/s.
- v0.4: Syncthing-Ordner ist `Interface\AddOns\Leuchtturm_Sync` (neben dem Addon, ohne .toc, wird vom Spiel ignoriert), damit er ein Addon-Update übersteht. `Index.lua` liegt im Addon-Ordner und wird von jedem lokal erzeugt (nicht synchronisiert).
- v0.4: Spielerdateien werden im Addon per `loadstring` + `setfenv` in einer leeren Umgebung ausgeführt; eine kaputte Datei stört nichts.
- v0.4: Gespeicherte Ausrüstung und Rezept-Ergebnisse tragen Rüstungswert, Mindeststufe, Slot und Typ mit, damit die anderen ohne Item-Cache vergleichen können.
- v0.4: Rezept-Gegenstände werden über den Namen nach dem Doppelpunkt erkannt; Beruf und Mindestskill aus der Tooltip-Zeile „Benötigt Beruf (Skill)“, sonst aus der Item-Unterklasse.
- v0.4: Zwei-Slot-Gegenstände (Ringe, Schmuck, Einhand) werden gegen den schwächeren getragenen verglichen; freier Slot = immer Upgrade.
- v0.4: Rüstungstypen nach Classic-Regeln (Kette für Jäger/Schamane ab 40, Platte für Krieger/Paladin ab 40); Waffenfertigkeiten je Klasse als Tabelle in `Wissen.lua`.
- v0.4: Derselbe Gegenstand wird beim Looten höchstens alle 60 s gemeldet; nur eigene Beute.

## Gespielte Klassen und Rollen
Paladin Tank, Druide Tank, Priester Heilig; Krieger, Jäger, Magier, Hexenmeister, Schamane DD. Echte Namen bisher: Daniel – Guile (Krieger, Bergbau/Schmiedekunst), Gomez (Hexenmeister, Schneiderei/Verzauberkunst). Die übrigen Config-Namen sind noch Platzhalter.

## Stand
- v0.3-Logik (Leiste) getestet in nachgebauter WoW-Umgebung: alle Klassen, Kampf mit gesperrten Werten, Pet, Munition, Splitter, Waffe.
- v0.4: Hinweissystem, Mock-Test mit zwei PCs und echtem Python-Skript.
- 26.11.2026 erster Ingame-Test v0.4.0 (Daniel, Guile + Gomez): Build 16001 bestätigt, keine Lua-Fehler, alle 5 Module laden, Leiste erkennt fehlenden Schlachtruf. Befunde: Guile ohne Config-Eintrag landete unter Spieler „Unbekannt“, Realm beim Login leer („Guile-“), Berufe wurden beim Logout gelöscht, Rezepte wurden in keinem Beruf erfasst (0 Rezepte), Hinweise blieben deshalb leer.
- v0.4.1 behebt das: Spieler wird kontoweit gelernt und „Unbekannt“-Einträge umgezogen, Realm-Rückfall über `GetRealmName`, Berufe beim Logout nicht mehr neu gelesen, Berufserkennung unscharf („Classic-Schmiedekunst“), Rezepte erst über die moderne, dann über die klassische API, Meldung „X Rezepte gespeichert“, neuer Befehl `/ltm diagnose`.
- `tests/alle_tests.sh`: 66 Prüfungen (davon 13 für die Befunde des Ingame-Tests), alle bestanden.

## Offene Punkte
1. Zweiter Ingame-Test mit v0.4.1: Berufsfenster öffnen → erscheint „… Rezepte gespeichert“? Sonst `/ltm diagnose` bei offenem Fenster als Screenshot.
2. Danach Hinweise (Loot, `/ltm hinweis`, Tooltip) mit erfassten Rezepten prüfen.
3. Prüfen: Zauber-Namen im deutschen Client (unsicher v. a. Vergeltungsaura, Göttlicher Willen, Aura des Volltreffers), ob Klick den höchsten Rang wirkt.
4. Restliche echte Charakternamen eintragen (mit `spieler`), auch Julias.
5. Syncthing einrichten und Hilfsskript bei Daniel und Julia starten; prüfen, dass `loadstring`/`setfenv` in Forever erlaubt sind (`/ltm diagnose` zeigt das).
6. Spätere Ideen: Konfiguration im Spiel statt Datei, Autostart des Hilfsskripts, Hinweise optional zusätzlich im Tooltip.

## Ausbaustufe 2: Abweichungen vom Auftrag
1. Basis war schon die allgemeine Klassen-Leiste v0.3, nicht nur eine Krieger-Schlachtruf-Erinnerung. Die Leiste bleibt unverändert, das Hinweissystem kommt als neue Module dazu.
2. Ein Addon kann eine Indexdatei nicht zur Laufzeit lesen und keine Dateien nachladen (nur die Lua-Dateien aus der .toc, beim Login/Reload). Deshalb erzeugt das Skript `Index.lua` als Lua-Datei mit der Liste der Spielerdateien und deren Inhalt; das Addon liest darüber alle Spieler. Neue Spieler erscheinen trotzdem automatisch, ohne .toc-Änderung.
3. Der Syncthing-Ordner liegt neben dem Addon (`Interface\AddOns\Leuchtturm_Sync`) statt darin, damit er ein Addon-Update übersteht. `Index.lua` erzeugt jeder lokal; sie wird nicht synchronisiert (sonst würden alle dieselbe Datei schreiben).
4. Rezepte liefert das Spiel nur bei offenem Berufsfenster. Login, Logout und Ausrüstungswechsel aktualisieren Grunddaten, Berufe und Ausrüstung; Rezepte werden beim Öffnen des Berufsfensters erfasst und bleiben gespeichert.
5. Angeln, Erste Hilfe und Kochen werden gar nicht erst gespeichert (einfachste Lesart von „komplett ignorieren“).
6. Anzeige mit Charakternamen: „Julias Priesterin (Lyra)“, damit zwei Charaktere gleicher Klasse unterscheidbar sind. Der gerade gespielte Charakter fehlt im Tooltip (das Spiel vergleicht selbst); höchstens 2 Vergleichs-Tooltips.
7. Mindeststufen-Vergleich: neue Mindeststufe ≥ der des getragenen Gegenstands. Auch Hals und Distanz/Relikt vergleichen die Mindeststufe, Schilde den Rüstungswert. Bei zwei Slots zählt der schwächere, ein freier Slot ist immer ein Upgrade.
8. Die Forever-API ließ sich ohne Client nicht nachprüfen. Berufe und Rezepte sind deshalb für beide API-Familien umgesetzt (Mainline und Classic), Tooltips für `TooltipDataProcessor` und `OnTooltipSetItem`.
9. Rezept → Ergebnis-Gegenstand: aus den gespeicherten Rezepten; kennt niemand das Rezept, über den Namen (Ergebnis heißt fast immer wie das Rezept, klappt nur, wenn der Gegenstand im Cache ist).
10. Loot-Hinweise erscheinen im Chatfenster, höchstens einmal je Gegenstand in 60 s und nur für eigene Beute. Der Skill des Herstellers wird für Schritt 3 nicht geprüft (wer das Rezept kennt, kann es herstellen).
11. „Spezialisierung (Rolle)“ wird als `rolle` (aus der Config) und `spec` (Config oder Spiel) gespeichert.
