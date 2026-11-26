--[[ Leuchtturm – Kern
  Erkennt Charakter, Klasse und Spezialisierung, liest die Config und
  startet die passenden Module. Module registrieren sich über
  ns:RegistriereModul{ ... } (siehe Module\Leiste.lua).
  Gespeicherte Variablen:
   LeuchtturmDB     – kontoweit: Datenbasis aller eigenen Charaktere
                      (wird per Hilfsskript mit den anderen Spielern geteilt)
   LeuchtturmCharDB – je Charakter: Einstellungen der Module (z. B. Leistenposition)
]]

local ADDON, ns = ...

ns.module   = {}
ns.befehle  = {}
ns.kontext  = nil

-- ---------------------------------------------------------------------
-- Hilfsfunktionen
-- ---------------------------------------------------------------------

function ns.Ausgabe(...)
  local teile = {}
  for i = 1, select("#", ...) do teile[#teile + 1] = tostring((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7Leuchtturm:|r " .. table.concat(teile, " "))
end

-- Tiefe Kopie + Zusammenführung: Werte aus "ueber" überschreiben "basis"
local function Zusammenfuehren(basis, ueber)
  local ergebnis = {}
  for k, v in pairs(basis or {}) do
    ergebnis[k] = (type(v) == "table") and Zusammenfuehren(v, nil) or v
  end
  for k, v in pairs(ueber or {}) do
    if type(v) == "table" and type(ergebnis[k]) == "table" then
      ergebnis[k] = Zusammenfuehren(ergebnis[k], v)
    else
      ergebnis[k] = v
    end
  end
  return ergebnis
end
ns.Zusammenfuehren = Zusammenfuehren

-- Ist ein Wert ein "Secret Value" (Midnight/Forever-Kampfsperre)?
function ns.IstGeheim(wert)
  return issecretvalue ~= nil and issecretvalue(wert) == true
end

function ns.ZauberName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- Nur für bekannte Zauber (Zauberbuch): Name, Icon, ID – sonst nil
function ns.ZauberInfo(nameOderId)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, nameOderId)
    if ok and info then return info.name, info.iconID, info.spellID end
    return nil
  end
  if GetSpellInfo then
    local name, _, icon, _, _, _, id = GetSpellInfo(nameOderId)
    if name then return name, icon, id end
  end
end

function ns.ZauberIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  if GetSpellInfo then return select(3, GetSpellInfo(id)) end
end

-- ---------------------------------------------------------------------
-- Modul-Registrierung
-- ---------------------------------------------------------------------
-- def = {
--   name     = "schlachtruf",          -- Schlüssel in Config.module
--   titel    = "Schlachtruf-Erinnerung",
--   klassen  = { WARRIOR = true },      -- nil = alle Klassen
--   specs    = { Schutz = true },       -- optional, nil = alle Specs
--   standard = { ... },                 -- Standard-Einstellungen
--   init     = function(ctx, einst) end -- wird beim Login aufgerufen
-- }
function ns:RegistriereModul(def)
  self.module[#self.module + 1] = def
end

-- Module können Unterbefehle für /ltm anmelden
function ns:RegistriereBefehl(wort, hilfe, funktion)
  self.befehle[wort] = { hilfe = hilfe, funktion = funktion }
end

-- ---------------------------------------------------------------------
-- Charakter erkennen
-- ---------------------------------------------------------------------

local function ErmittleSpecAusSpiel()
  -- Forever hat evtl. keine Spezialisierungen wie Retail. Falls doch,
  -- nehmen wir den Namen; sonst bleibt es beim Eintrag aus der Config.
  if not (GetSpecialization and GetSpecializationInfo) then return nil end
  local ok, index = pcall(GetSpecialization)
  if not ok or type(index) ~= "number" then return nil end
  local ok2, _, name = pcall(GetSpecializationInfo, index)
  if ok2 and type(name) == "string" and name ~= "" then return name end
end

-- Spieler dieses WoW-Kontos: per /ltm ich gesetzt oder automatisch gelernt
function ns.KontoSpieler()
  local db = LeuchtturmDB or {}
  if db.ich then return db.ich end
  local gefunden
  for name in pairs(db.spieler or {}) do
    if name ~= "Unbekannt" then
      if gefunden then return nil end   -- mehrere Spieler: nicht raten
      gefunden = name
    end
  end
  return gefunden
end

local function ErmittleKontext()
  local cfg      = Leuchtturm_Config or {}
  local name     = UnitName("player")
  local realm    = GetNormalizedRealmName and GetNormalizedRealmName() or nil
  if (realm == nil or realm == "") and GetRealmName then   -- beim Login teils noch leer
    realm = (GetRealmName() or ""):gsub("[%s%-]", "")
  end
  if realm == "" then realm = nil end
  local _, klasse = UnitClass("player")

  local liste  = cfg.charaktere or {}
  local eintrag = (realm and liste[name .. "-" .. realm]) or liste[name]

  local ctx = {
    name     = name,
    realm    = realm,
    klasse   = klasse,
    eintrag  = eintrag,
    -- Spieler: aus der Config, sonst /ltm ich <Name>, sonst der Spieler, dem
    -- die übrigen Charaktere dieses Kontos gehören (Datenbasis ist kontoweit)
    spieler  = (eintrag and eintrag.spieler) or ns.KontoSpieler() or nil,
    rolle    = eintrag and eintrag.rolle or nil,
    spec     = (eintrag and eintrag.spec) or ErmittleSpecAusSpiel(),
  }

  if eintrag and eintrag.klasse and eintrag.klasse ~= klasse then
    ns.Ausgabe(("|cffff5555Achtung:|r %s steht in der Config als %s, ist aber %s."):format(
      name, tostring(eintrag.klasse), tostring(klasse)))
  end
  return ctx
end

local function ModulPasst(def, ctx)
  if def.klassen and not def.klassen[ctx.klasse] then return false end
  if def.specs and not (ctx.spec and def.specs[ctx.spec]) then return false end
  return true
end

-- ---------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------

local function Starte()
  LeuchtturmCharDB = LeuchtturmCharDB or {}
  LeuchtturmDB     = LeuchtturmDB or {}
  local ctx = ErmittleKontext()
  ctx.db = LeuchtturmCharDB
  ctx.aktiveModule = {}
  ns.kontext = ctx

  local cfg = Leuchtturm_Config or {}
  for _, def in ipairs(ns.module) do
    if ModulPasst(def, ctx) then
      local einst = Zusammenfuehren(def.standard, cfg.module and cfg.module[def.name])
      if ctx.eintrag and ctx.eintrag.module then
        einst = Zusammenfuehren(einst, ctx.eintrag.module[def.name])
      end
      if einst.aktiv ~= false then
        ctx.db[def.name] = ctx.db[def.name] or {}
        local ok, fehler = pcall(def.init, ctx, einst, ctx.db[def.name])
        if ok then
          ctx.aktiveModule[#ctx.aktiveModule + 1] = def.titel or def.name
        else
          ns.Ausgabe("|cffff5555Fehler in Modul " .. def.name .. ":|r " .. tostring(fehler))
        end
      end
    end
  end

  if not ctx.eintrag then
    ns.Ausgabe(("%s steht nicht in der Config – es zählt nur die Klasse (%s)."):format(
      ctx.name, tostring(ctx.klasse)))
  end
end

local start = CreateFrame("Frame")
start:RegisterEvent("PLAYER_LOGIN")
start:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Starte()
end)

-- ---------------------------------------------------------------------
-- Chat-Befehle: /ltm bzw. /leuchtturm
-- ---------------------------------------------------------------------

SLASH_LEUCHTTURM1 = "/ltm"
SLASH_LEUCHTTURM2 = "/leuchtturm"
SlashCmdList.LEUCHTTURM = function(eingabe)
  local wort, rest = (eingabe or ""):match("^%s*(%S*)%s*(.-)%s*$")
  wort = (wort or ""):lower()

  if wort == "" or wort == "info" then
    local ctx = ns.kontext
    if not ctx then return end
    ns.Ausgabe(("%s-%s | Klasse: %s | Rolle: %s | Spec: %s | Spieler: %s"):format(
      tostring(ctx.name), tostring(ctx.realm or "?"), tostring(ctx.klasse), ctx.rolle or "DD (Standard)",
      tostring(ctx.spec or "–"), tostring(ctx.spieler or "–")))
    if not ctx.eintrag then
      ns.Ausgabe("Dieser Charakter steht nicht in Config.lua – Rolle und Spec dort eintragen.")
    end
    ns.Ausgabe("Aktive Module: " .. (#ctx.aktiveModule > 0 and table.concat(ctx.aktiveModule, ", ") or "keine"))
    local woerter = {}
    for w in pairs(ns.befehle) do woerter[#woerter + 1] = w end
    table.sort(woerter)
    for _, w in ipairs(woerter) do ns.Ausgabe("  /ltm " .. w .. " – " .. ns.befehle[w].hilfe) end
    return
  end

  local befehl = ns.befehle[wort]
  if befehl then
    befehl.funktion(rest)
  else
    ns.Ausgabe("Unbekannter Befehl. /ltm zeigt die Übersicht.")
  end
end
