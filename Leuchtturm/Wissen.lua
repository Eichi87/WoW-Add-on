--[[ Leuchtturm – Wissen (gemeinsame Grundlagen der Hinweis-Module)

  - Berufe: Schlüssel, deutsche Namen, Skill-Linien, Rezept-Unterklassen
  - Alle Charaktere aller Spieler (eigene LeuchtturmDB + Index der anderen)
  - Gegenstände auswerten (Slot, Rüstungstyp, Rüstungswert, Mindeststufe,
    Klassen-Beschränkung, Rezept-Anforderung)
  - Prüfung "Könnte dieser Charakter das brauchen?" (Schritt 3 und 4)

  Kein eigenes Modul, sondern Hilfsfunktionen unter ns.W.
]]

local ADDON, ns = ...
local W = {}
ns.W = W

-- ---------------------------------------------------------------------
-- Berufe
-- ---------------------------------------------------------------------
-- skill = Skill-Linie (Mainline-API), rezeptKlasse = Unterklasse der
-- Rezept-Gegenstände (Item-Klasse 9), ignoriert = in allen Hinweisen
-- komplett übergangen (Vorgabe: Angeln, Erste Hilfe, Kochen).
W.BERUFE = {
  ALCHEMIE          = { name = "Alchemie",          skill = 171, rezeptKlasse = 6,  namen = { "Alchemy" } },
  SCHMIEDEKUNST     = { name = "Schmiedekunst",     skill = 164, rezeptKlasse = 4,  namen = { "Blacksmithing" } },
  VERZAUBERKUNST    = { name = "Verzauberkunst",    skill = 333, rezeptKlasse = 8,  namen = { "Enchanting" } },
  INGENIEURSKUNST   = { name = "Ingenieurskunst",   skill = 202, rezeptKlasse = 3,  namen = { "Engineering" } },
  LEDERVERARBEITUNG = { name = "Lederverarbeitung", skill = 165, rezeptKlasse = 1,  namen = { "Leatherworking" } },
  SCHNEIDEREI       = { name = "Schneiderei",       skill = 197, rezeptKlasse = 2,  namen = { "Tailoring" } },
  JUWELIERSKUNST    = { name = "Juwelierskunst",    skill = 755, rezeptKlasse = 10, namen = { "Jewelcrafting" } },
  INSCHRIFTENKUNDE  = { name = "Inschriftenkunde",  skill = 773, rezeptKlasse = 11, namen = { "Inscription" } },
  BERGBAU           = { name = "Bergbau",           skill = 186, namen = { "Mining", "Verhüttung", "Smelting" } },
  KRAEUTERKUNDE     = { name = "Kräuterkunde",      skill = 182, namen = { "Herbalism" } },
  KUERSCHNEREI      = { name = "Kürschnerei",       skill = 393, namen = { "Skinning" } },
  KOCHKUNST         = { name = "Kochkunst",         skill = 185, rezeptKlasse = 5,  ignoriert = true, namen = { "Kochen", "Cooking" } },
  ERSTEHILFE        = { name = "Erste Hilfe",       skill = 129, rezeptKlasse = 7,  ignoriert = true, namen = { "First Aid" } },
  ANGELN            = { name = "Angeln",            skill = 356, rezeptKlasse = 9,  ignoriert = true, namen = { "Fishing" } },
}

local berufNachName, berufNachSkill, berufNachRezeptKlasse = {}, {}, {}
for key, b in pairs(W.BERUFE) do
  berufNachName[b.name:lower()] = key
  for _, n in ipairs(b.namen or {}) do berufNachName[n:lower()] = key end
  berufNachSkill[b.skill] = key
  if b.rezeptKlasse then berufNachRezeptKlasse[b.rezeptKlasse] = key end
end

-- Liefert den Berufsschlüssel zu Name (deutsch/englisch) oder Skill-Linie
function W.BerufSchluessel(nameOderSkill)
  if type(nameOderSkill) == "number" then return berufNachSkill[nameOderSkill] end
  if type(nameOderSkill) == "string" then return berufNachName[nameOderSkill:lower()] end
end

function W.BerufIgnoriert(key)
  return key == nil or (W.BERUFE[key] and W.BERUFE[key].ignoriert) == true
end

W.FARBEN = {              -- Schwierigkeitsfarbe → Anzeige
  orange = "|cffff8040orange|r", gelb = "|cffffff00gelb|r",
  ["grün"] = "|cff40c040grün|r", grau = "|cff808080grau|r",
}

-- ---------------------------------------------------------------------
-- Charaktere aller Spieler
-- ---------------------------------------------------------------------
-- Eigene Daten: LeuchtturmDB.spieler (live). Andere: LeuchtturmFremd, den
-- Abgleich.lua aus LeuchtturmIndex aufbaut. Gibt es einen Charakter in
-- beiden Quellen, gewinnt der neuere Stand.
function W.AlleCharaktere()
  local nachKey, liste = {}, {}
  local function Nimm(spielerTabelle, quelle)
    for spieler, sp in pairs(spielerTabelle or {}) do
      for key, c in pairs(sp.charaktere or {}) do
        local id = spieler .. "\001" .. key
        local alt = nachKey[id]
        if not alt or (c.aktualisiert or 0) > (alt.c.aktualisiert or 0) then
          nachKey[id] = { spieler = spieler, key = key, c = c, quelle = quelle }
        end
      end
    end
  end
  Nimm(LeuchtturmDB and LeuchtturmDB.spieler, "eigen")
  for _, daten in pairs(ns.fremd or {}) do Nimm(daten.spieler, "fremd") end
  for _, e in pairs(nachKey) do liste[#liste + 1] = e end
  table.sort(liste, function(a, b)
    if a.spieler ~= b.spieler then return a.spieler < b.spieler end
    return a.key < b.key
  end)
  return liste
end

-- Ist das der gerade eingeloggte Charakter?
function W.IstAktuell(eintrag)
  return ns.charKey ~= nil and eintrag.key == ns.charKey and eintrag.quelle == "eigen"
end

local KLASSEN_DE = {
  WARRIOR = { "Krieger", "Kriegerin" },  PALADIN = { "Paladin", "Paladin" },
  HUNTER  = { "Jäger", "Jägerin" },      ROGUE   = { "Schurke", "Schurkin" },
  PRIEST  = { "Priester", "Priesterin" },SHAMAN  = { "Schamane", "Schamanin" },
  MAGE    = { "Magier", "Magierin" },    WARLOCK = { "Hexenmeister", "Hexenmeisterin" },
  DRUID   = { "Druide", "Druidin" },
}

function W.KlassenName(token, geschlecht)
  local weiblich = geschlecht == 3
  local quelle = weiblich and LOCALIZED_CLASS_NAMES_FEMALE or LOCALIZED_CLASS_NAMES_MALE
  if quelle and quelle[token] then return quelle[token] end
  local de = KLASSEN_DE[token]
  if de then return weiblich and de[2] or de[1] end
  return tostring(token)
end

local function Genitiv(name)
  if name:match("[sßxz]$") then return name .. "'" end
  return name .. "s"
end

-- "Julias Priesterin (Lyra)"
function W.Bezeichnung(eintrag)
  local c = eintrag.c
  return ("%s %s (%s)"):format(Genitiv(eintrag.spieler), W.KlassenName(c.klasse, c.geschlecht), c.name or eintrag.key)
end

function W.Alter(zeitpunkt)
  if not zeitpunkt or zeitpunkt == 0 then return "unbekannt" end
  local d = time() - zeitpunkt
  if d < 120 then return "gerade eben" end
  if d < 3600 then return ("vor %d Min."):format(d / 60) end
  if d < 86400 then return ("vor %d Std."):format(d / 3600) end
  return ("vor %d Tag(en)"):format(d / 86400)
end

-- ---------------------------------------------------------------------
-- Gegenstände
-- ---------------------------------------------------------------------
-- Ruft f geschützt auf; nil bei Fehler oder wenn ein Secret Value dabei ist
local function Pruefe(ok, ...)
  if not ok then return nil end
  for i = 1, select("#", ...) do
    if ns.IstGeheim((select(i, ...))) then return nil end
  end
  return ...
end
local function Sicher(f, ...)
  if not f then return nil end
  return Pruefe(pcall(f, ...))
end
W.Sicher = Sicher

function W.ItemID(linkOderID)
  if type(linkOderID) == "number" then return linkOderID end
  if type(linkOderID) == "string" then return tonumber(linkOderID:match("item:(%-?%d+)")) end
end

local function ItemGrunddaten(x)
  local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  return Sicher(f, x)
end

-- Tooltip-Zeilen eines Gegenstands (linke Spalte), für Rüstung,
-- Klassen-Beschränkung und Berufsanforderung
local scanTip
function W.TooltipZeilen(link)
  local zeilen = {}
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local daten = Sicher(C_TooltipInfo.GetHyperlink, link)
    if daten and daten.lines then
      for _, z in ipairs(daten.lines) do
        if type(z.leftText) == "string" then zeilen[#zeilen + 1] = z.leftText end
      end
      return zeilen
    end
  end
  if not CreateFrame then return zeilen end
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "LeuchtturmScanTooltip", nil, "GameTooltipTemplate")
  end
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanTip:ClearLines()
  pcall(scanTip.SetHyperlink, scanTip, link)
  for i = 1, scanTip:NumLines() do
    local fs = _G["LeuchtturmScanTooltipTextLeft" .. i]
    local t = fs and fs:GetText()
    if type(t) == "string" then zeilen[#zeilen + 1] = t end
  end
  scanTip:Hide()
  return zeilen
end

local klassenNachName
local function KlassenNachName()
  if klassenNachName then return klassenNachName end
  klassenNachName = {}
  for token, de in pairs(KLASSEN_DE) do
    klassenNachName[de[1]] = token; klassenNachName[de[2]] = token
  end
  for _, t in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for token, n in pairs(t) do klassenNachName[n] = token end
  end
  return klassenNachName
end

local SLOTS = {
  INVTYPE_HEAD = { 1 },  INVTYPE_NECK = { 2 },  INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },  INVTYPE_FEET = { 8 },  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
  INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
  INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
W.SLOTS = SLOTS

-- Slots mit sinnvollem Rüstungswert; alle anderen vergleichen die Mindeststufe
local RUESTUNGS_SLOT = {
  INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
  INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true, INVTYPE_WRIST = true,
  INVTYPE_HAND = true, INVTYPE_SHIELD = true,
}

-- Rüstungstypen (Item-Klasse 4): 0 Sonstiges, 1 Stoff, 2 Leder, 3 Kette, 4 Platte, 6 Schild
-- Wert = ab welcher Stufe die Klasse den Typ tragen kann
local RUESTUNG = {
  WARRIOR = { [0] = 1, 1, 1, 1, 40, [6] = 1 },
  PALADIN = { [0] = 1, 1, 1, 1, 40, [6] = 1 },
  HUNTER  = { [0] = 1, 1, 1, 40 },
  SHAMAN  = { [0] = 1, 1, 1, 40, [6] = 1 },
  ROGUE   = { [0] = 1, 1, 1 },
  DRUID   = { [0] = 1, 1, 1 },
  PRIEST  = { [0] = 1, 1 },
  MAGE    = { [0] = 1, 1 },
  WARLOCK = { [0] = 1, 1 },
}
-- Waffen (Item-Klasse 2), erlernbare Waffenfertigkeiten je Klasse
local function Menge(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WAFFEN = {
  WARRIOR = Menge(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
  PALADIN = Menge(0, 1, 4, 5, 6, 7, 8),
  HUNTER  = Menge(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
  ROGUE   = Menge(2, 3, 4, 7, 13, 15, 16, 18),
  PRIEST  = Menge(4, 10, 15, 19),
  SHAMAN  = Menge(0, 1, 4, 5, 10, 13, 15),
  MAGE    = Menge(7, 10, 15, 19),
  WARLOCK = Menge(7, 10, 15, 19),
  DRUID   = Menge(4, 5, 10, 13, 15),
}

-- Wertet einen Gegenstand aus. Liefert nil, solange der Client ihn noch
-- nicht kennt (dann wird er angefordert; beim nächsten Mal klappt es).
-- Ergebnis: { id, name, link, klasse, unterklasse, slot, stufeMin, ruestung,
--             klassen (Menge oder nil), rezept = { beruf, skill, name } }
local cache = {}
function W.ItemInfo(linkOderID)
  if linkOderID == nil then return nil end
  local id = W.ItemID(linkOderID)
  local schluessel = linkOderID
  if cache[schluessel] then return cache[schluessel] end

  local name, link, _, _, stufeMin, _, _, _, slot, _, _, klasse, unterklasse = ItemGrunddaten(linkOderID)
  if not name then
    if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return nil
  end

  local info = {
    id = id or W.ItemID(link), name = name, link = link, klasse = klasse, unterklasse = unterklasse,
    slot = (slot ~= "" and slot) or nil, stufeMin = stufeMin or 0, ruestung = 0,
  }

  local zeilen = W.TooltipZeilen(link)
  local stats = Sicher((C_Item and C_Item.GetItemStats) or GetItemStats, link)
  if stats and stats.RESISTANCE0_NAME then info.ruestung = stats.RESISTANCE0_NAME end
  for _, z in ipairs(zeilen) do
    local r = z:match("^(%d+) Rüstung") or z:match("^(%d+) Armor")
    if r and info.ruestung == 0 then info.ruestung = tonumber(r) end
    local kl = z:match("^Klassen: (.+)$") or z:match("^Classes: (.+)$")
    if kl then
      info.klassen = {}
      for n in kl:gmatch("[^,]+") do
        local token = KlassenNachName()[n:gsub("^%s+", ""):gsub("%s+$", "")]
        if token then info.klassen[token] = true end
      end
    end
    local beruf, skill = z:match("^Benötigt (.-) %((%d+)%)")
    if not beruf then beruf, skill = z:match("^Requires (.-) %((%d+)%)") end
    if beruf and W.BerufSchluessel(beruf) and not info.rezeptAnf then
      info.rezeptAnf = { beruf = W.BerufSchluessel(beruf), skill = tonumber(skill) }
    end
  end

  if klasse == 9 then -- Rezept
    local beruf = (info.rezeptAnf and info.rezeptAnf.beruf) or berufNachRezeptKlasse[unterklasse]
    info.rezept = {
      beruf = beruf,
      skill = info.rezeptAnf and info.rezeptAnf.skill or nil,
      name  = name:match("^[^:]+:%s*(.+)$") or name,  -- "Muster: Kupferweste" → "Kupferweste"
    }
  end

  cache[schluessel] = info
  return info
end

-- Kurzform zum Speichern in der Datenbasis (damit andere Spieler die Werte
-- auch ohne Item-Cache auswerten können)
function W.Kurzinfo(info)
  if not info then return nil end
  return { slot = info.slot, stufeMin = info.stufeMin, ruestung = info.ruestung,
           klasse = info.klasse, unterklasse = info.unterklasse, klassen = info.klassen }
end

-- Darf der Charakter c den Gegenstand anlegen (Slot, Typ, Klasse, Stufe)?
function W.KannTragen(info, c)
  if not (info and info.slot and SLOTS[info.slot]) then return false end
  if info.klassen and not info.klassen[c.klasse] then return false end
  if (c.stufe or 1) < (info.stufeMin or 0) then return false end
  if info.klasse == 4 then
    local ab = RUESTUNG[c.klasse] and RUESTUNG[c.klasse][info.unterklasse or -1]
    if not ab or (c.stufe or 1) < ab then return false end
  elseif info.klasse == 2 then
    if not (WAFFEN[c.klasse] and WAFFEN[c.klasse][info.unterklasse or -1]) then return false end
  end
  if info.slot == "INVTYPE_SHIELD" and not (RUESTUNG[c.klasse] and RUESTUNG[c.klasse][6]) then return false end
  return true
end

-- Könnte c das brauchen? Liefert true und den getragenen Gegenstand des
-- Vergleichs-Slots ({ link, ruestung, stufeMin } oder nil = Slot leer).
-- Regel: Rüstungs-Slots ≥ 95 % des getragenen Rüstungswerts (nach oben
-- offen), sonst Mindeststufe ≥ Mindeststufe des getragenen Gegenstands.
-- Bei zwei Slots (Ringe, Schmuck, Einhand) zählt der schwächere.
W.SCHWELLE = 0.95
function W.KoennteBrauchen(info, c)
  if not W.KannTragen(info, c) then return false end
  local slots = SLOTS[info.slot]
  local ruestungsSlot = RUESTUNGS_SLOT[info.slot] == true
  local schwaechster, schwaecherWert
  for _, s in ipairs(slots) do
    local g = c.ausruestung and c.ausruestung[s]
    if not g then return true, nil end               -- freier Slot
    local wert = ruestungsSlot and (g.ruestung or 0) or (g.stufeMin or 0)
    if not schwaecherWert or wert < schwaecherWert then schwaechster, schwaecherWert = g, wert end
  end
  if ruestungsSlot then
    if (schwaecherWert or 0) <= 0 then return true, schwaechster end
    if (info.ruestung or 0) >= W.SCHWELLE * schwaecherWert then return true, schwaechster end
  else
    if (info.stufeMin or 0) >= (schwaecherWert or 0) then return true, schwaechster end
  end
  return false
end

-- Name eines getragenen Gegenstands aus seinem Link
function W.LinkName(link)
  if type(link) ~= "string" then return "?" end
  return link:match("%[(.-)%]") or link
end
