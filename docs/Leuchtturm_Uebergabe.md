# Leuchtturm – Übergabe (Stand 26.11.2026, v0.3)

Eigenes WoW-Forever-Addon für Daniel und Julia. Ziel: eine Klassen-Leiste, die an fehlende/auslaufende Buffs und Ressourcen erinnert und per Klick nachbuffen lässt – ohne Automatisierung.

## Rahmenbedingungen (WoW: Forever)
- Forever läuft auf dem modernen Client (Mainline-API ca. 12.1.5), nicht auf Classic. Interface-Nummer laut Warcraft Wiki: 16001.
- Midnight-Addon-Einschränkungen gelten: Im Kampf sind Buffs (ggf. auch Waffenverzauberungen, Pet-Daten) „Secret Values“ und nicht lesbar. Lösung im Addon: außerhalb des Kampfes echt lesen, im Kampf ab eigenem Cast hochrechnen, Dauer lernen.
- Autocast ist weder erlaubt noch möglich. Erlaubt: SecureActionButton, Klick wirkt Zauber. Attribute, Show/Hide und Positionen nur außerhalb des Kampfes ändern, Alpha/Texturen/Text gehen immer.

## Aufbau
- `Leuchtturm.toc` – Interface 16001, SavedVariablesPerCharacter: LeuchtturmCharDB
- `Config.lua` – Charaktere (Name → spieler, klasse, rolle, spec) und Leisten-Einträge je Klasse
- `Core.lua` – erkennt Charakter/Klasse, liest Config, startet Module, Chatbefehle `/ltm`
- `Module/Leiste.lua` – die Leiste; Arten: buff, waffe, pet, zaehler, munition

## Entscheidungen
- Zaubernamen (deutscher Client) statt IDs in der Config; gewirkt wird der erste bekannte Name einer Liste.
- Rolle statt Spec als Hauptfilter (Tank/Heiler/DD, ohne Angabe = DD).
- Krieger-Schlachtruf warnt nur im Kampf, alle anderen Einträge auch außerhalb.
- Klick wirkt immer auf den Spieler selbst (unit = player).
- Nach Ladebildschirm 3 s Ruhe, Warnton höchstens 1×/s.

## Gespielte Klassen und Rollen
Paladin Tank, Druide Tank, Priester Heilig; Krieger, Jäger, Magier, Hexenmeister, Schamane DD. Charakternamen in der Config sind noch Platzhalter.

## Stand
- Logik getestet in nachgebauter WoW-Umgebung (Lua 5.1 + Mock-API): alle Klassen, Kampf mit gesperrten Werten, Pet, Munition, Splitter, Waffe.
- NICHT im echten Client getestet.

## Offene Punkte
1. Erster Ingame-Test (Krieger zuerst): `/ltm`, `/ltm leiste`, Lua-Fehler zurückmelden.
2. Prüfen: Interface-Nummer, Zauber-IDs/Namen im deutschen Client (unsicher v. a. Vergeltungsaura, Göttlicher Willen, Aura des Volltreffers), ob Klick den höchsten Rang wirkt.
3. Echte Charakternamen eintragen.
4. Spätere Ideen: Konfiguration im Spiel statt Datei, weitere Module.
