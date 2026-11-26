# Leuchtturm v0.4 – erster Ingame-Test

Dauer: etwa 20 Minuten. Zuerst allein mit dem Krieger testen, Syncthing kommt erst in Teil C.

## A. Installieren
1. ZIP entpacken. Darin liegen die Ordner `Leuchtturm` und `Werkzeug`.
2. Den Ordner `Leuchtturm` nach `World of Warcraft\_forever_\Interface\AddOns\` kopieren.
   Gibt es `_forever_` nicht, dann `_retail_`. Eine alte Version vorher löschen.
3. `Leuchtturm\Config.lua` mit Notepad++ öffnen. Bei `charaktere` die Platzhalter
   durch eure echten Charakternamen ersetzen, jeweils mit `spieler = "Daniel"` oder `"Julia"`.
   Speichern.
4. WoW starten. Im Charakter-Auswahlbildschirm unter „AddOns" den Eintrag Leuchtturm aktivieren
   und „Veraltete AddOns laden" anhaken, falls WoW das Addon als veraltet markiert.

## B. Allein testen (Krieger)
Nach dem Einloggen nacheinander in den Chat eingeben:

| Eingabe | Erwartung |
|---|---|
| `/dump select(4, GetBuildInfo())` | eine Zahl. Steht dort nicht 16001, mir die Zahl schicken |
| `/ltm` | Name, Klasse WARRIOR, Spieler Daniel, 5 aktive Module |
| `/ltm leiste` | Eintrag Schlachtruf mit Status |
| Berufsfenster öffnen (z. B. Schmiedekunst), wieder schließen | – |
| `/ltm daten` | dein Krieger mit Beruf, Skill und Anzahl der Rezepte |
| Maus über einen Gegenstand in der Tasche | normaler Tooltip, eventuell mit Zeile „Könnte brauchen …" |
| ein Material looten oder `/ltm hinweis` + Shift-Klick auf ein Material in der Tasche | Hinweis im Chat, wenn ein Rezept es noch braucht |

Danach mit einem zweiten Charakter (z. B. dem Paladin) einloggen und noch einmal `/ltm daten` eingeben:
Beide Charaktere sollten jetzt erscheinen.

## C. Abgleich mit Julia (erst wenn B klappt)
1. Python 3 installieren (python.org, beim Setup „Add to PATH" anhaken).
2. In Syncthing einen Ordner `World of Warcraft\_forever_\Interface\AddOns\Leuchtturm_Sync`
   anlegen und mit Julia teilen. Julia macht das Gleiche bei sich.
3. Den Ordner `Werkzeug` irgendwohin legen, `leuchtturm_sync.ini` öffnen,
   `wow_ordner` prüfen. Bei Julia steht dort `spieler = Julia`.
4. `Abgleich_starten.bat` doppelklicken und das Fenster offen lassen.
5. Einmal aus- und wieder einloggen. Im Fenster erscheint „Eigene Daten kopiert" und „Index neu erzeugt".
6. Nachdem Julia dasselbe gemacht hat, im Spiel `/ltm neu` eingeben. `/ltm daten` sollte jetzt auch Julias Charaktere zeigen.

## Was ich zurück brauche
- Jede rote Lua-Fehlermeldung als Text oder Screenshot (am besten mit dem Addon BugSack, sonst `/console scriptErrors 1`).
- Die Ausgabe von `/ltm` und `/ltm daten` als Screenshot.
- Bei Teil C: das Fenster des Skripts als Screenshot, falls dort etwas Rotes steht.
- Alles, was anders aussieht als in der Tabelle oben.
