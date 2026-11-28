-- Nachgebaute WoW-Umgebung (Lua 5.1) für Leuchtturm-Tests außerhalb des Spiels.
-- Bildet nur die Funktionen nach, die das Addon benutzt.

local M = { ausgabe = {}, ereignisse = {}, timer = {}, zeit = 1000, items = {}, postcalls = {} }
MOCK = M

-- ---------------------------------------------------------------- Grundlagen
function GetTime() return M.zeit end
local echteZeit = 1764150000
function time() return echteZeit end
function M.Zeitsprung(sek) M.zeit = M.zeit + sek; echteZeit = echteZeit + sek end
issecretvalue = function() return false end
InCombatLockdown = function() return M.kampf == true end
C_Timer = { After = function(sek, f) M.timer[#M.timer + 1] = f end }
function M.Timer()
  for _ = 1, 5 do
    local t = M.timer; M.timer = {}
    for _, f in ipairs(t) do f() end
    if #M.timer == 0 then break end
  end
end
PlaySound = function() end
SOUNDKIT = { RAID_WARNING = 1 }
ChatTypeInfo = { RAID_WARNING = {} }
RaidNotice_AddMessage = function() end
RaidWarningFrame = {}
ReloadUI = function() M.reload = true end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Krieger", PALADIN = "Paladin", PRIEST = "Priester" }
LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Kriegerin", PALADIN = "Paladin", PRIEST = "Priesterin" }

DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) M.ausgabe[#M.ausgabe + 1] = t end }

-- ---------------------------------------------------------------- Frames
local Frame = {}
Frame.__index = function(t, k) return Frame[k] or function() end end
local function Neu(name)
  local f = setmetatable({ scripts = {}, shown = false, lines = {}, name = name }, Frame)
  if name then _G[name] = f end
  M.alleFrames = M.alleFrames or {}; table.insert(M.alleFrames, f)
  return f
end
function Frame:RegisterEvent(e)
  M.ereignisse[e] = M.ereignisse[e] or {}
  table.insert(M.ereignisse[e], self)
end
Frame.RegisterUnitEvent = Frame.RegisterEvent
function Frame:UnregisterEvent(e)
  for i, f in ipairs(M.ereignisse[e] or {}) do if f == self then table.remove(M.ereignisse[e], i) break end end
end
function Frame:SetScript(n, f) self.scripts[n] = f end
function Frame:HookScript(n, f)
  local alt = self.scripts[n]
  self.scripts[n] = function(...) if alt then alt(...) end f(...) end
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown end
function Frame:CreateTexture() return Neu() end
function Frame:CreateFontString() return Neu() end
function Frame:CreateAnimationGroup() return Neu() end
function Frame:CreateAnimation() return Neu() end
function Frame:GetFrameLevel() return 1 end
function Frame:GetRight() return 600 end
function Frame:IsPlaying() return false end
function Frame:ClearLines() self.lines = {}; self.item = nil end
function Frame:AddLine(t) self.lines[#self.lines + 1] = t end
function Frame:NumLines() return #self.lines end
function Frame:GetItem() if self.item then return M.items[self.itemID].name, self.item end end
function Frame:SetHyperlink(link)
  self:ClearLines()
  local id = tonumber(link:match("item:(%d+)"))
  local it = M.items[id]
  if not it then error("unbekannter Gegenstand " .. tostring(link)) end
  self.item, self.itemID = link, id
  self:AddLine(it.name)
  for _, z in ipairs(M.Zeilen(it)) do self:AddLine(z) end
  for _, pc in ipairs(M.postcalls) do pc(self) end
end
function Frame:SetScale(x) self.scale = x end
function Frame:GetScale() return self.scale or 1 end
-- vereinfachte Geometrie: nur Punkte relativ zu UIParent-BOTTOMLEFT bzw. -CENTER (1000 x 600)
function Frame:ClearAllPoints() self.punkt = nil end
function Frame:SetPoint(p, rel, rp, x, y)
  if type(rel) ~= "table" then return end
  if rel == UIParent then self.punkt = { p, rp, x or 0, y or 0 } end
end
function Frame:GetCenter()
  local pt = self.punkt
  if not pt then return nil end
  local s = self:GetScale()
  if pt[2] == "BOTTOMLEFT" then return pt[3], pt[4] end
  return 500 / s + pt[3], 300 / s + pt[4]        -- "CENTER"
end
function Frame:StartMoving() self.bewegt = true end
function Frame:StopMovingOrSizing() self.bewegt = false end
function M.Ziehe(frame, dx, dy)   -- Ziehen in Bildschirm-Einheiten (UIParent)
  local x, y = frame:GetCenter(); local s = frame:GetScale()
  frame.punkt = { "CENTER", "BOTTOMLEFT", x + dx / s, y + dy / s }
end
function CreateFrame(_, name) return Neu(name) end
UIParent, WorldFrame = Neu("UIParent"), Neu("WorldFrame")
GameTooltip, ItemRefTooltip = Neu("GameTooltip"), Neu("ItemRefTooltip")

TooltipDataProcessor = { AddTooltipPostCall = function(_, f) M.postcalls[#M.postcalls + 1] = f end }

function M.Feuer(e, ...)
  for _, f in ipairs(M.ereignisse[e] or {}) do
    if f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end
  end
end
function M.Tick(sek)
  M.Zeitsprung(sek or 0.2)
  for _, list in pairs({}) do end
end

-- ---------------------------------------------------------------- Gegenstände
-- it = { name, stufeMin, slot, klasse, unterklasse, ruestung, zeilen }
function M.Item(id, it) it.id = id; M.items[id] = it; return M.Link(id) end
function M.Link(id) return ("|cffffffff|Hitem:%d::::::::|h[%s]|h|r"):format(id, M.items[id].name) end
function M.Zeilen(it)
  local z = {}
  if (it.ruestung or 0) > 0 then z[#z + 1] = it.ruestung .. " Rüstung" end
  for _, x in ipairs(it.zeilen or {}) do z[#z + 1] = x end
  return z
end
local function Finde(x)
  if type(x) == "number" then return M.items[x] end
  local id = tonumber(tostring(x):match("item:(%d+)"))
  if id then return M.items[id] end
  for _, it in pairs(M.items) do if it.name == x then return it end end
end
function GetItemInfo(x)
  local it = Finde(x)
  if not it then return nil end
  return it.name, M.Link(it.id), 1, 10, it.stufeMin or 0, "", "", 1, it.slot or "", 0, 0, it.klasse or 15, it.unterklasse or 0
end
function GetItemStats(link)
  local it = Finde(link)
  if it and (it.ruestung or 0) > 0 then return { RESISTANCE0_NAME = it.ruestung } end
  return {}
end
C_TooltipInfo = { GetHyperlink = function(link)
  local it = Finde(link)
  local lines = { { leftText = it.name } }
  for _, z in ipairs(M.Zeilen(it)) do lines[#lines + 1] = { leftText = z } end
  return { lines = lines }
end }

-- ---------------------------------------------------------------- Spieler
M.spieler = { name = "Kriegername", realm = "Forever", klasse = "WARRIOR", stufe = 20, sex = 2 }
M.ausruestung = {}
function UnitName() return M.spieler.name end
function GetNormalizedRealmName() if M.realmLeer then return nil end return M.spieler.realm end
function GetRealmName() return M.spieler.realmAnzeige or M.spieler.realm end
function UnitClass() return M.spieler.klasse, M.spieler.klasse end
function UnitLevel() return M.spieler.stufe end
function UnitSex() return M.spieler.sex end
function UnitGUID() return "Player-1" end
function UnitExists() return false end
function UnitIsDeadOrGhost() return false end
function UnitOnTaxi() return false end
function GetInventorySlotInfo() return nil end
function GetInventoryItemLink(_, slot) local id = M.ausruestung[slot]; return id and M.Link(id) end
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }
C_Spell = {
  GetSpellInfo = function(n) if n == "Schlachtruf" then return { name = n, iconID = 1, spellID = 6673 } end end,
  GetSpellName = function(id) if id == 6673 then return "Schlachtruf" end end,
  GetSpellTexture = function() return 1 end,
}

-- Berufe (Mainline-API)
M.berufe = {}   -- { {name, stufe, max, skill} }
function GetProfessions()
  if M.logout then return nil end
  local b = M.berufe
  return b[1] and 1 or nil, b[2] and 2 or nil, nil, nil, b[5] and 5 or nil
end
function GetProfessionInfo(i)
  local b = M.berufe[i]
  return b.name, 0, b.stufe, b.max, 0, 0, b.skill
end
M.fenster = nil  -- { professionID, professionName, skillLevel, maxSkillLevel, rezepte = { {name, farbe(0-3), ergebnis, zutaten={[id]=n}} } }
C_TradeSkillUI = {
  IsTradeSkillLinked = function() return false end,
  IsTradeSkillGuild = function() return false end,
  IsNPCCrafting = function() return false end,
  GetBaseProfessionInfo = function() return M.fenster end,
  GetAllRecipeIDs = function() local t = {} for i in ipairs(M.fenster.rezepte) do t[i] = i end return t end,
  GetRecipeInfo = function(id) local r = M.fenster.rezepte[id]
    return { name = r.name, learned = true, relativeDifficulty = r.farbe } end,
  GetRecipeSchematic = function(id) local r = M.fenster.rezepte[id]
    local slots = {}
    for zid, n in pairs(r.zutaten) do slots[#slots + 1] = { reagents = { { itemID = zid } }, quantityRequired = n, required = true } end
    return { outputItemID = r.ergebnis, reagentSlotSchematics = slots } end,
}

-- Klassische Berufs-API (Fenster über M.altFenster = { name, stufe, max, rezepte = {…} })
function GetTradeSkillLine() local f = M.altFenster if f then return f.name, f.stufe, f.max end return "UNKNOWN", 0, 0 end
function GetNumTradeSkills() return M.altFenster and (#M.altFenster.rezepte + 1) or 0 end
local FARBE_TEXT = { [0] = "optimal", "medium", "easy", "trivial" }
function GetTradeSkillInfo(i)
  if i == 1 then return "Rüstung", "header" end
  local r = M.altFenster.rezepte[i - 1]
  return r.name, FARBE_TEXT[r.farbe]
end
function GetTradeSkillItemLink(i) return M.Link(M.altFenster.rezepte[i - 1].ergebnis) end
local function Zutatenliste(i)
  local t = {}
  for id, n in pairs(M.altFenster.rezepte[i - 1].zutaten) do t[#t + 1] = { id, n } end
  return t
end
function GetTradeSkillNumReagents(i) return #Zutatenliste(i) end
function GetTradeSkillReagentItemLink(i, r) return M.Link(Zutatenliste(i)[r][1]) end
function GetTradeSkillReagentInfo(i, r) local z = Zutatenliste(i)[r]; return M.items[z[1]].name, 0, z[2], 0 end
ExpandTradeSkillSubClass = function() end

-- Beute
M.beute = {}
function GetNumLootItems() return #M.beute end
function GetLootSlotLink(i) return M.Link(M.beute[i]) end

-- ---------------------------------------------------------------- Laden
function M.LadeAddon(ordner)
  local ns = {}
  local toc = io.open(ordner .. "/Leuchtturm.toc"):read("*a")
  for zeile in toc:gmatch("[^\r\n]+") do
    if not zeile:match("^##") and zeile:match("%.lua$") then
      local pfad = ordner .. "/" .. zeile:gsub("\\", "/")
      local f = assert(loadfile(pfad))
      f("Leuchtturm", ns)
    end
  end
  M.ns = ns
  return ns
end

-- SavedVariables-Datei wie das Spiel schreiben
local function Ser(v, einr)
  if type(v) == "string" then return ("%q"):format(v) end
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local t = { "{\n" }
  for _, k in ipairs(keys) do
    local ks = type(k) == "string" and ("[%q]"):format(k) or ("[" .. tostring(k) .. "]")
    t[#t + 1] = einr .. "\t" .. ks .. " = " .. Ser(v[k], einr .. "\t") .. ",\n"
  end
  t[#t + 1] = einr .. "}"
  return table.concat(t)
end
function M.SchreibeSV(pfad)
  local f = assert(io.open(pfad, "w"))
  f:write("\nLeuchtturmDB = " .. Ser(LeuchtturmDB, "") .. "\n")
  f:close()
end

return M
