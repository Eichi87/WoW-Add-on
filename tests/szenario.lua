-- Leuchtturm-Testszenario. Aufruf: lua5.1 tests/szenario.lua <rolle> <wow-ordner>
--   julia1 : Julias PC, Priesterin, Schneiderei + Erste Hilfe – speichert Variablen
--   daniel : Daniels PC, Krieger (Schmiedekunst, Bergbau, Kochkunst), liest Julias Daten
--   julia2 : Julias PC, liest Daniels Daten über den Index
local rolle, wow = arg[1], arg[2]
local M = dofile("tests/mock_wow.lua")
local addon = wow .. "/Interface/AddOns/Leuchtturm"

local fehler, gut = 0, 0
local function Pruefe(bedingung, text)
  if bedingung then gut = gut + 1 else fehler = fehler + 1; print("  FEHLER: " .. text) end
end
local function Ausgabe() local t = table.concat(M.ausgabe, "\n"); M.ausgabe = {}; return t end
local function Enthaelt(t, muster) return t:find(muster, 1, true) ~= nil end

-- Gegenstände --------------------------------------------------------------
M.Item(2589, { name = "Leinenstoff", klasse = 7 })
M.Item(2840, { name = "Kupferbarren", klasse = 7 })
M.Item(2770, { name = "Kupfererz", klasse = 7 })
M.Item(3471, { name = "Kupferkettenweste", slot = "INVTYPE_CHEST", klasse = 4, unterklasse = 3, ruestung = 60, stufeMin = 5 })
M.Item(2570, { name = "Leinenumhang", slot = "INVTYPE_CLOAK", klasse = 4, unterklasse = 1, ruestung = 8, stufeMin = 3 })
M.Item(2569, { name = "Leinenstiefel", slot = "INVTYPE_FEET", klasse = 4, unterklasse = 1, ruestung = 9, stufeMin = 4 })
M.Item(1251, { name = "Leinenverband", klasse = 0 })
M.Item(9001, { name = "Robe der Eule", slot = "INVTYPE_ROBE", klasse = 4, unterklasse = 1, ruestung = 30, stufeMin = 12 })
M.Item(9002, { name = "Robe des Lehrlings", slot = "INVTYPE_ROBE", klasse = 4, unterklasse = 1, ruestung = 29, stufeMin = 10 })
M.Item(9003, { name = "Dünne Robe", slot = "INVTYPE_ROBE", klasse = 4, unterklasse = 1, ruestung = 25, stufeMin = 10 })
M.Item(9004, { name = "Lumpiges Wams", slot = "INVTYPE_CHEST", klasse = 4, unterklasse = 2, ruestung = 20, stufeMin = 1 })
M.Item(9005, { name = "Weiße Leinenrobe", slot = "INVTYPE_ROBE", klasse = 4, unterklasse = 1, ruestung = 35, stufeMin = 12 })
M.Item(9006, { name = "Muster: Weiße Leinenrobe", klasse = 9, unterklasse = 2, zeilen = { "Benötigt Schneiderei (70)" } })
M.Item(9007, { name = "Rezept: Gewürzbrot", klasse = 9, unterklasse = 5, zeilen = { "Benötigt Kochkunst (1)" } })
M.Item(9008, { name = "Kupferring", slot = "INVTYPE_FINGER", klasse = 4, unterklasse = 0, stufeMin = 11 })
M.Item(9009, { name = "Alter Ring", slot = "INVTYPE_FINGER", klasse = 4, unterklasse = 0, stufeMin = 8 })
M.Item(9010, { name = "Kettenhaube der Priester", slot = "INVTYPE_HEAD", klasse = 4, unterklasse = 3, ruestung = 40, stufeMin = 5 })
M.Item(9011, { name = "Pläne: Kupferkettenweste", klasse = 9, unterklasse = 4, zeilen = { "Benötigt Schmiedekunst (1)" } })

local function Login() M.Feuer("PLAYER_LOGIN"); M.Feuer("PLAYER_ENTERING_WORLD"); M.Timer() end
local function Fenster(f) M.fenster = f; M.Feuer("TRADE_SKILL_SHOW"); M.Timer() end
local function Loot(...) M.beute = { ... }; M.Feuer("LOOT_OPENED"); M.Timer(); M.Zeitsprung(61); return Ausgabe() end
local function Tooltip(id) GameTooltip:SetHyperlink(M.Link(id)); M.Timer(); return table.concat(GameTooltip.lines, "\n") end
local function Befehl(t) SlashCmdList.LEUCHTTURM(t); M.Timer(); return Ausgabe() end

-- ============================================================================
if rolle == "julia1" or rolle == "julia2" then
  M.spieler = { name = "Priestername", realm = "Forever", klasse = "PRIEST", stufe = 15, sex = 3 }
  M.ausruestung = { [5] = 9001, [11] = 9009, [12] = 9009 }
  M.berufe = { { name = "Schneiderei", stufe = 40, max = 75, skill = 197 }, { name = "Erste Hilfe", stufe = 60, max = 75, skill = 129 } }
  if rolle == "julia2" then
    local env = {}; local f = loadfile(wow .. "/WTF/Account/JULIA/SavedVariables/Leuchtturm.lua"); setfenv(f, env); f()
    LeuchtturmDB = env.LeuchtturmDB
  end
  M.LadeAddon(addon)
  Login()
  local login = Ausgabe()
  Pruefe(LeuchtturmDB.spieler.Julia.charaktere["Priestername-Forever"] ~= nil, "Charakter unter Spieler Julia gespeichert")
  Fenster({ professionID = 197, professionName = "Schneiderei", skillLevel = 40, maxSkillLevel = 75, rezepte = {
    { name = "Leinenumhang", farbe = 1, ergebnis = 2570, zutaten = { [2589] = 2 } },
    { name = "Leinenstiefel", farbe = 3, ergebnis = 2569, zutaten = { [2589] = 3 } },
  } })
  Fenster({ professionID = 129, professionName = "Erste Hilfe", skillLevel = 60, maxSkillLevel = 75, rezepte = {
    { name = "Leinenverband", farbe = 0, ergebnis = 1251, zutaten = { [2589] = 1 } },
  } })
  local c = LeuchtturmDB.spieler.Julia.charaktere["Priestername-Forever"]
  Pruefe(c.berufe.SCHNEIDEREI and c.berufe.SCHNEIDEREI.stufe == 40, "Schneiderei 40 erfasst")
  Pruefe(c.berufe.ERSTEHILFE == nil, "Erste Hilfe wird nicht erfasst")
  Pruefe(c.berufe.SCHNEIDEREI.rezepte.Leinenumhang.farbe == "gelb", "Rezeptfarbe gelb")
  Pruefe(c.berufe.SCHNEIDEREI.rezepte.Leinenstiefel.farbe == "grau", "Rezeptfarbe grau")
  Pruefe(c.berufe.SCHNEIDEREI.rezepte.Leinenumhang.zutaten[2589] == 2, "Zutaten erfasst")
  Pruefe(c.ausruestung[5] and c.ausruestung[5].ruestung == 30, "Ausrüstung mit Rüstungswert erfasst")
  Pruefe(c.stufe == 15 and c.klasse == "PRIEST" and c.geschlecht == 3 and c.rolle == "Heiler", "Grunddaten erfasst")
  Pruefe(c.aktualisiert ~= nil, "Zeitstempel gesetzt")

  -- Ausrüstungswechsel aktualisiert die Daten
  M.ausruestung[1] = 9010; M.Zeitsprung(10); M.Feuer("PLAYER_EQUIPMENT_CHANGED"); M.Timer()
  Pruefe(c.ausruestung[1] ~= nil, "Ausrüstungswechsel gespeichert")
  M.ausruestung[1] = nil; M.Feuer("PLAYER_EQUIPMENT_CHANGED"); M.Timer()

  if rolle == "julia2" then
    Pruefe(Enthaelt(login, "Daten von Daniel"), "Login-Meldung zeigt Stand von Daniel")
    local t = Loot(2840)
    print(t)
    Pruefe(Enthaelt(t, "Upgrade Kupferkettenweste für Daniels Krieger (Kriegername), Daniels Paladin (Paladinname)"), "Julia sieht Daniels Paladin-Upgrade")
    Pruefe(Enthaelt(t, "herstellbar von Daniels Krieger (Kriegername)"), "Julia sieht Daniels Krieger als Hersteller")
    local tt = Tooltip(9004)
    print(tt)
    Pruefe(Enthaelt(tt, "Daniels Paladin (Paladinname), trägt aktuell Lumpiges Wams"), "Tooltip zeigt Daniels Paladin für Lederwams")
    print(Befehl("daten"))
  end
  M.Feuer("PLAYER_LOGOUT")
  local wtf = wow .. "/WTF/Account/JULIA/SavedVariables"
  os.execute("mkdir -p '" .. wtf .. "'")
  M.SchreibeSV(wtf .. "/Leuchtturm.lua")

-- ============================================================================
elseif rolle == "daniel" then
  M.spieler = { name = "Kriegername", realm = "Forever", klasse = "WARRIOR", stufe = 20, sex = 2 }
  M.ausruestung = { [5] = 9004 }
  M.berufe = { { name = "Schmiedekunst", stufe = 50, max = 75, skill = 164 },
               { name = "Bergbau", stufe = 60, max = 75, skill = 186 },
               [5] = { name = "Kochkunst", stufe = 10, max = 75, skill = 185 } }
  -- Bereits gespeicherte Daten von Daniels Paladin (früherer Login)
  LeuchtturmDB = { spieler = { Daniel = { charaktere = { ["Paladinname-Forever"] = {
    name = "Paladinname", realm = "Forever", klasse = "PALADIN", geschlecht = 2, stufe = 8, rolle = "Tank",
    berufe = {}, ausruestung = { [5] = { link = M.Link(9004), ruestung = 20, stufeMin = 1 } },
    aktualisiert = time() - 3 * 86400 } } } } }
  M.LadeAddon(addon)
  Login()
  local login = Ausgabe()
  Pruefe(Enthaelt(login, "Daten von Julia"), "Login-Meldung zeigt Stand von Julia")
  Pruefe(MOCK.ns.fremd.Julia ~= nil, "Julias Datei über den Index geladen")
  Fenster({ professionID = 164, professionName = "Schmiedekunst", skillLevel = 50, maxSkillLevel = 75, rezepte = {
    { name = "Kupferkettenweste", farbe = 0, ergebnis = 3471, zutaten = { [2840] = 8 } },
  } })
  Fenster({ professionID = 186, professionName = "Bergbau", skillLevel = 60, maxSkillLevel = 75, rezepte = {
    { name = "Kupfer verhütten", farbe = 2, ergebnis = 2840, zutaten = { [2770] = 1 } },
  } })
  local c = LeuchtturmDB.spieler.Daniel.charaktere["Kriegername-Forever"]
  Pruefe(c.berufe.KOCHKUNST == nil, "Kochkunst wird nicht erfasst")
  Pruefe(c.berufe.SCHMIEDEKUNST.rezepte.Kupferkettenweste.ergebnisInfo.slot == "INVTYPE_CHEST", "Ergebnis-Werte gespeichert")

  -- Schritt 2: Zutaten
  local t = Loot(2589)
  print(t)
  Pruefe(Enthaelt(t, "Julias Priesterin (Priestername) – Schneiderei, 1 Rezept(e) nicht grau"), "Leinenstoff: Julia (Schneiderei)")
  Pruefe(not Enthaelt(t, "Erste Hilfe"), "Leinenstoff: keine Erste Hilfe")
  t = Loot(2840)
  print(t)
  Pruefe(Enthaelt(t, "Daniels Krieger (Kriegername) – Schmiedekunst"), "Kupferbarren: Krieger braucht ihn zum Leveln")
  -- Schritt 3: Handwerk
  Pruefe(Enthaelt(t, "Daniels Paladin (Paladinname) – herstellbar von Daniels Krieger (Kriegername)"), "Kupferbarren: Kupferweste für den Paladin")
  Pruefe(not Enthaelt(t, "Priesterin (Priestername) – herst"), "Priesterin bekommt keine Kettenweste")
  t = Loot(2770)
  Pruefe(Enthaelt(t, "Bergbau"), "Kupfererz: Bergbau-Hinweis")
  -- Schritt 2: Rezepte
  t = Loot(9006)
  print(t)
  Pruefe(Enthaelt(t, "Rezept fehlt bei: Julias Priesterin (Priestername)"), "Muster: Julia kennt es nicht")
  Pruefe(Enthaelt(t, "Skill 40/70, noch zu niedrig"), "Muster: Skill als Zusatzinfo")
  t = Loot(9007)
  Pruefe(t == "", "Kochrezept: keine Hinweise")
  t = Loot(9011)
  Pruefe(t == "", "Bekanntes Schmiede-Rezept: niemand braucht es")
  -- Kein Doppel-Hinweis innerhalb von 60 s
  M.beute = { 2589 }; M.Feuer("LOOT_OPENED"); M.Feuer("CHAT_MSG_LOOT", "Ihr erhaltet Beute: " .. M.Link(2589), "", "", "", "", "", 0, 0, "", 0, 1, "Player-1"); M.Timer()
  local einmal = Ausgabe(); local _, anzahl = einmal:gsub("Zum Leveln", "")
  Pruefe(anzahl == 1, "Hinweis nur einmal trotz Fenster + Chatmeldung")
  M.Zeitsprung(61)
  M.Feuer("CHAT_MSG_LOOT", "Mitspieler erhält Beute: " .. M.Link(2589), "", "", "", "", "", 0, 0, "", 0, 1, "Player-2"); M.Timer()
  Pruefe(Ausgabe() == "", "Beute anderer Gruppenmitglieder wird ignoriert")

  -- Schritt 4: Tooltips
  local tt = Tooltip(9002)
  print(tt)
  Pruefe(Enthaelt(tt, "Könnte brauchen: Julias Priesterin (Priestername), trägt aktuell Robe der Eule"), "Tooltip: Julia bei 29 von 30 Rüstung (≥ 95 %)")
  Pruefe(not Enthaelt(tt, "Krieger (Kriegername)"), "Tooltip: aktueller Charakter nicht aufgeführt")
  Pruefe(LeuchtturmVergleich1.shown and LeuchtturmVergleich1.item == M.Link(9001), "Vergleichs-Tooltip zeigt Robe der Eule")
  tt = Tooltip(9003)
  Pruefe(not Enthaelt(tt, "Könnte brauchen"), "Tooltip: 25 von 30 Rüstung (< 95 %) kein Hinweis")
  tt = Tooltip(9006)
  print(tt)
  Pruefe(Enthaelt(tt, "Könnte brauchen: Julias Priesterin (Priestername), trägt aktuell Robe der Eule"), "Rezept-Tooltip über Ergebnis-Gegenstand")
  tt = Tooltip(9008)
  Pruefe(Enthaelt(tt, "Julias Priesterin (Priestername), trägt aktuell Alter Ring"), "Ring: Mindeststufe 11 ≥ 8")
  Pruefe(not Enthaelt(tt, "Paladin (Paladinname)"), "Ring: Paladin Stufe 8 < 11")
  tt = Tooltip(9010)
  Pruefe(not Enthaelt(tt, "Priesterin"), "Kettenhaube: Priesterin trägt keine Kette")
  tt = Tooltip(9004)
  Pruefe(Enthaelt(tt, "Daniels Paladin (Paladinname), trägt aktuell Lumpiges Wams |cff999999(Stand vor 3 Tag(en))"), "Alte Daten tragen ihren Stand")

  -- Leiste läuft weiter
  t = Befehl("leiste")
  Pruefe(Enthaelt(t, "Schlachtruf"), "Klassen-Leiste: Schlachtruf vorhanden")
  t = Befehl("daten")
  print(t)
  Pruefe(Enthaelt(t, "Daniel (du): 2 Charakter(e), 2 Berufe, 2 Rezepte"), "/ltm daten: Daniels Zählung")
  Pruefe(Enthaelt(t, "Julia: 1 Charakter(e), 1 Berufe, 2 Rezepte"), "/ltm daten: Julias Zählung")
  Befehl("neu")
  Pruefe(M.reload, "/ltm neu lädt neu")
  M.Feuer("PLAYER_LOGOUT")
  local wtf = wow .. "/WTF/Account/DANIEL/SavedVariables"
  os.execute("mkdir -p '" .. wtf .. "'")
  M.SchreibeSV(wtf .. "/Leuchtturm.lua")
end

-- ============================================================================
-- Nachgestellte Befunde aus Daniels erstem Ingame-Test (26.11.2026)
if rolle == "befunde" then
  -- Guile ist nicht in der Config, Realm beim Login leer; Gomez (Daniel) gibt es schon,
  -- dazu ein alter Eintrag "Guile-" unter "Unbekannt" aus v0.4.0
  M.spieler = { name = "Guile", realm = "Forever", realmAnzeige = "Forever", klasse = "WARRIOR", stufe = 10, sex = 2 }
  M.realmLeer = true
  M.ausruestung = { [5] = 9004 }
  M.berufe = { { name = "Bergbau", stufe = 57, max = 75, skill = 186 }, { name = "Schmiedekunst", stufe = 34, max = 75, skill = 164 } }
  LeuchtturmDB = { spieler = {
    Daniel = { charaktere = { ["Gomez-Forever"] = { name = "Gomez", realm = "Forever", klasse = "WARLOCK", stufe = 23,
      berufe = { SCHNEIDEREI = { name = "Schneiderei", stufe = 74, max = 150, rezepte = {} } }, ausruestung = {}, aktualisiert = time() - 600 } } },
    Unbekannt = { charaktere = { ["Guile-"] = { name = "Guile", klasse = "WARRIOR", stufe = 10, berufe = {},
      ausruestung = {}, aktualisiert = time() - 900 } } } } }
  M.LadeAddon(addon)
  Leuchtturm_Config.charaktere.Guile = nil   -- Zustand beim ersten Test: Guile fehlte in der Config
  Login()
  Ausgabe()
  Pruefe(LeuchtturmDB.spieler.Unbekannt == nil, "kein Spieler 'Unbekannt' mehr")
  Pruefe(LeuchtturmDB.spieler.Daniel.charaktere["Guile-Forever"] ~= nil, "Guile unter Daniel mit Realm aus GetRealmName")
  Pruefe(LeuchtturmDB.spieler.Daniel.charaktere["Guile-"] == nil, "alter Schlüssel ohne Realm entfernt")
  Pruefe(LeuchtturmDB.ich == "Daniel", "Spieler des Kontos gemerkt")
  local t = Befehl("")
  Pruefe(Enthaelt(t, "Rolle: DD (Standard)") and Enthaelt(t, "Spieler: Daniel"), "/ltm zeigt Standardrolle und Spieler")
  Pruefe(Enthaelt(t, "nicht in Config.lua"), "/ltm weist auf fehlenden Config-Eintrag hin")
  local c = LeuchtturmDB.spieler.Daniel.charaktere["Guile-Forever"]
  -- /ltm hinweis ohne erfasste Rezepte erklärt warum
  t = Befehl("hinweis " .. M.Link(2840))
  Pruefe(Enthaelt(t, "Rezepte noch nicht erfasst bei") and Enthaelt(t, "Guile (Schmiedekunst)"), "Hinweis erklärt fehlende Rezepte")
  -- Moderne API mit unbekannter ID und Namen "Classic-Schmiedekunst"
  Fenster({ professionID = 2477, professionName = "Classic-Schmiedekunst", skillLevel = 34, maxSkillLevel = 75, rezepte = {
    { name = "Kupferkettenweste", farbe = 0, ergebnis = 3471, zutaten = { [2840] = 8 } } } })
  t = Ausgabe()
  Pruefe(c.berufe.SCHMIEDEKUNST.rezepte.Kupferkettenweste ~= nil, "unscharfe Berufserkennung (Classic-Schmiedekunst)")
  Pruefe(Enthaelt(t, "Schmiedekunst: 1 Rezepte gespeichert."), "Rückmeldung nach dem Erfassen")
  -- Moderne API liefert nichts → klassische API
  M.fenster = { professionID = 186, professionName = "Bergbau", skillLevel = 57, maxSkillLevel = 75, rezepte = {} }
  M.altFenster = { name = "Verhüttung", stufe = 57, max = 75, rezepte = {
    { name = "Kupfer verhütten", farbe = 2, ergebnis = 2840, zutaten = { [2770] = 1 } } } }
  M.Feuer("TRADE_SKILL_SHOW"); M.Timer()
  Pruefe(c.berufe.BERGBAU.rezepte["Kupfer verhütten"] and c.berufe.BERGBAU.rezepte["Kupfer verhütten"].farbe == "grün",
    "Rückfall auf klassische API")
  t = Befehl("diagnose")
  Pruefe(Enthaelt(t, "klassische API: trade: Beruf Verhüttung") and Enthaelt(t, "0 Rezept-IDs"), "/ltm diagnose zeigt beide APIs")
  -- Logout: Spiel liefert keine Berufe mehr → nichts löschen
  M.logout = true; M.Feuer("PLAYER_LOGOUT"); M.Timer()
  Pruefe(c.berufe.SCHMIEDEKUNST and c.berufe.BERGBAU, "Berufe überstehen den Logout")
  t = Befehl("daten")
  print(t)
  Pruefe(Enthaelt(t, "Gomez") and Enthaelt(t, "Rezepte offen"), "/ltm daten zeigt offene Rezepte")
end

print(("%s: %d Prüfungen bestanden, %d Fehler"):format(rolle, gut, fehler))
os.exit(fehler == 0 and 0 or 1)
