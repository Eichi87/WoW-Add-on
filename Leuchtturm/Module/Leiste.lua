--[[ Leuchtturm – Modul: Klassen-Leiste (alle Klassen)

  Was überwacht wird, steht in Config.lua unter module.leiste.klassen.
  Jeder Eintrag wird ein Button in einer gemeinsamen Leiste:
   - blass/grau: alles in Ordnung
   - gelb pulsierend: läuft bald aus / wird knapp / Begleiter unglücklich
   - rot pulsierend: fehlt / leer
  Linksklick wirkt den Zauber (auf dich selbst), Rechtsklick ggf. einen
  zweiten (z. B. Tier wiederbeleben). Shift + Rechtsklick ziehen
  verschiebt die Leiste (nicht im Kampf).

  Arten (Feld "art" in der Config):
   buff     – Buff auf dir (Standard)
   waffe    – Waffenverzauberung (Schamane)
   pet      – Begleiter vorhanden / glücklich (Jäger, Hexenmeister)
   zaehler  – Anzahl eines Gegenstands in den Taschen (Seelensplitter)
   munition – angelegte Munition (Jäger)

  Im Kampf sperrt Forever das Auslesen von Buffs (ggf. auch
  Waffenverzauberungen). Dann rechnet Leuchtturm ab deinem eigenen Cast
  hoch und gleicht nach dem Kampf mit dem echten Stand ab.
]]

local ADDON, ns = ...

local TAKT             = 0.1   -- Anzeige
local TAKT_LANGSAM     = 1.0   -- Gegenstände, Begleiter, Waffe
local DAUERHAFT        = math.huge
local STUMM_NACH_LADEN = 3     -- Sekunden Ruhe nach Ladebildschirm

local MELDUNGEN = {
  buff     = { bald = "%s läuft aus!",       fehlt = "%s fehlt!" },
  waffe    = { bald = "%s läuft aus!",       fehlt = "%s fehlt!" },
  pet      = { bald = "%s ist unglücklich!", fehlt = "%s fehlt!" },
  zaehler  = { bald = "%s wird knapp!",      fehlt = "%s: keine mehr!" },
  munition = { bald = "%s wird knapp!",      fehlt = "%s: keine mehr!" },
}

local function AlsListe(x)
  if type(x) == "table" then return x end
  if x ~= nil then return { x } end
  return {}
end

local function Enthaelt(liste, wert)
  for _, v in ipairs(liste or {}) do
    if v == wert then return true end
  end
  return false
end

local function Zeitformat(rest)
  if rest >= 60 then return ("%dm"):format(math.ceil(rest / 60)) end
  return ("%d"):format(math.ceil(rest))
end

-- Ruft f geschützt auf; liefert nil, falls Fehler oder ein Secret dabei ist
local function Pruefe(ok, ...)
  if not ok then return nil end
  for i = 1, select("#", ...) do
    if ns.IstGeheim((select(i, ...))) then return nil end
  end
  return ...
end
local function Sicher(f, ...)
  return Pruefe(pcall(f, ...))
end

local function Gegenstandsanzahl(id)
  if C_Item and C_Item.GetItemCount then return Sicher(C_Item.GetItemCount, id) end
  if GetItemCount then return Sicher(GetItemCount, id) end
end

local function GegenstandsIcon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
end

local function MunitionsPlatz()
  if not GetInventorySlotInfo then return nil end
  local ok, platz = pcall(GetInventorySlotInfo, "AMMOSLOT")
  if ok and type(platz) == "number" then return platz end
end

ns:RegistriereModul({
  name    = "leiste",
  titel   = "Klassen-Leiste",
  klassen = nil, -- alle; was angezeigt wird, kommt aus der Config

  standard = {
    aktiv            = true,
    groesse          = 56,
    abstand          = 8,
    ton              = true,
    bildschirmText   = true,
    alphaAktiv       = 0.35,
    alphaRuhe        = 0.6,
    warnenAbSekunden = 30,
    wann             = "immer",
  },

  init = function(ctx, einst, db)
    -- Charakter-eigene Liste (module.leiste.liste) hat Vorrang vor der Klassenliste
    local quelle = einst.liste or (einst.klassen and einst.klassen[ctx.klasse])
    if not quelle or #quelle == 0 then return end

    db.dauer = db.dauer or {}

    -- -----------------------------------------------------------------
    -- Einträge aufbereiten
    -- -----------------------------------------------------------------
    local eintraege = {}
    local rolle = ctx.rolle or "DD"   -- ohne Angabe in der Config: DD
    for _, e in ipairs(quelle) do
      local rollePasst = (e.rollen == nil) or Enthaelt(e.rollen, rolle)
      local specPasst  = (e.specs  == nil) or Enthaelt(e.specs,  ctx.spec)
      if rollePasst and specPasst and not Enthaelt(einst.aus, e.titel) then
        local art    = e.art or "buff"
        local zauber = AlsListe(e.zauber)
        local zaehlt = {}
        for _, n in ipairs(zauber) do zaehlt[n] = true end
        for _, n in ipairs(AlsListe(e.zaehltAuch)) do zaehlt[n] = true end
        eintraege[#eintraege + 1] = {
          art        = art,
          titel      = e.titel or zauber[1] or art,
          zauber     = zauber,
          rechts     = AlsListe(e.rechts),
          zaehlt     = zaehlt,
          startDauer = e.dauer or (art == "waffe" and 300 or 1800),
          warnenAb   = e.warnenAb or einst.warnenAbSekunden,
          wann       = e.wann or einst.wann,
          abStufe    = e.abStufe or 0,
          item       = e.item,
          minimum    = e.minimum or 1,
          hand       = e.hand or "haupt",
          meldung    = MELDUNGEN[art] or MELDUNGEN.buff,
          ablauf     = nil,   -- buff/waffe: GetTime() des Auslaufens; DAUERHAFT; nil = fehlt
          dauer      = nil,
          wert       = nil,   -- zaehler/munition: Anzahl
          petStatus  = nil,   -- pet: "da" | "weg" | "ungluecklich"
          zustand    = nil,
          sichtbar   = false,
          bekannt    = nil,   -- Zauber auf Linksklick
        }
      end
    end
    if #eintraege == 0 then return end

    local imKampf    = InCombatLockdown()
    local testBis    = nil
    local stummBis   = GetTime() + STUMM_NACH_LADEN
    local letzterTon = 0

    local function DauerFuer(name, e)
      local d = db.dauer[name]
      if d == nil then d = e.startDauer end
      return d
    end

    -- -----------------------------------------------------------------
    -- Lesen: Buffs, Waffe, Begleiter, Gegenstände
    -- -----------------------------------------------------------------
    local function LeseAuren()
      if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        return nil
      end
      local ok, ergebnis = pcall(function()
        local t = {}
        for i = 1, 40 do
          local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
          if not aura then break end
          if ns.IstGeheim(aura.name) then return nil end
          local q = aura.sourceUnit
          t[aura.name] = {
            ende  = aura.expirationTime or 0,
            dauer = aura.duration or 0,
            mir   = (not ns.IstGeheim(q)) and q == "player",
          }
        end
        return t
      end)
      if ok then return ergebnis end
    end

    local function AktualisiereBuffs()
      local auren = LeseAuren()
      if not auren then return end           -- gesperrt: Schätzungen behalten
      for _, e in ipairs(eintraege) do
        if e.art == "buff" then
          local gefunden
          for name in pairs(e.zaehlt) do
            local a = auren[name]
            if a then
              gefunden = a
              if a.mir and Enthaelt(e.zauber, name) then db.dauer[name] = a.dauer end
              break
            end
          end
          if not gefunden then
            e.ablauf, e.dauer = nil, nil
          elseif gefunden.ende > 0 then
            e.ablauf, e.dauer = gefunden.ende, gefunden.dauer
          else
            e.ablauf, e.dauer = DAUERHAFT, 0
          end
        end
      end
    end

    local function LeseWaffe(e)
      if not GetWeaponEnchantInfo then return end
      local hatH, restH, _, _, hatN, restN = Sicher(GetWeaponEnchantInfo)
      if hatH == nil then return end         -- gesperrt
      local hat, rest
      if e.hand == "neben" then hat, rest = hatN, restN else hat, rest = hatH, restH end
      if hat and rest and rest > 0 then
        local sek = rest / 1000
        e.ablauf = GetTime() + sek
        e.dauer  = math.max(e.dauer or 0, e.startDauer, sek)
      else
        e.ablauf, e.dauer = nil, nil
      end
    end

    local function LesePet(e)
      local da = Sicher(UnitExists, "pet")
      if da == nil then return end           -- gesperrt: alten Stand behalten
      local tot = da and Sicher(UnitIsDead, "pet")
      if not da or tot then e.petStatus = "weg" return end
      local glueck = GetPetHappiness and Sicher(GetPetHappiness)
      e.petStatus = (glueck == 1) and "ungluecklich" or "da"
    end

    local munitionsPlatz = MunitionsPlatz()
    local function LeseMunition(e)
      if not munitionsPlatz then return end
      local id = Sicher(GetInventoryItemID, "player", munitionsPlatz)
      if not id then e.wert = 0 return end
      e.wert = Sicher(GetInventoryItemCount, "player", munitionsPlatz) or e.wert
    end

    local function Langsam()
      for _, e in ipairs(eintraege) do
        if e.sichtbar then
          if e.art == "waffe" then LeseWaffe(e)
          elseif e.art == "pet" then LesePet(e)
          elseif e.art == "zaehler" and e.item then e.wert = Gegenstandsanzahl(e.item) or e.wert
          elseif e.art == "munition" then LeseMunition(e)
          end
        end
      end
    end

    -- -----------------------------------------------------------------
    -- Leiste und Buttons
    -- -----------------------------------------------------------------
    local g = einst.groesse

    local anker = CreateFrame("Frame", "LeuchtturmLeiste", UIParent)
    anker:SetSize(g, g)
    anker:SetMovable(true)
    anker:SetClampedToScreen(true)
    local function SetzeStartposition()
      anker:ClearAllPoints()
      local pos = db.position
      if pos then
        anker:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
      else
        anker:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
      end
    end
    SetzeStartposition()

    for i, e in ipairs(eintraege) do
      local btn = CreateFrame("Button", "LeuchtturmKnopf" .. i, anker, "SecureActionButtonTemplate")
      btn:SetSize(g, g)
      btn:SetAttribute("unit", "player")
      btn:RegisterForClicks("AnyUp", "AnyDown")
      btn:RegisterForDrag("RightButton")
      btn:SetScript("OnDragStart", function()
        if IsShiftKeyDown() and not InCombatLockdown() then anker:StartMoving() end
      end)
      btn:SetScript("OnDragStop", function()
        anker:StopMovingOrSizing()
        local p, _, rp, x, y = anker:GetPoint(1)
        db.position = { p, rp, x, y }
      end)

      local icon = btn:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints()
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

      local rahmen = btn:CreateTexture(nil, "OVERLAY")
      rahmen:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      rahmen:SetBlendMode("ADD")
      rahmen:SetPoint("CENTER")
      rahmen:SetSize(g * 1.9, g * 1.9)
      rahmen:Hide()

      local puls = rahmen:CreateAnimationGroup()
      puls:SetLooping("BOUNCE")
      local anim = puls:CreateAnimation("Alpha")
      anim:SetFromAlpha(1.0)
      anim:SetToAlpha(0.25)
      anim:SetDuration(0.45)

      local sweep = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
      sweep:SetAllPoints()
      sweep:SetReverse(true)
      sweep:SetHideCountdownNumbers(true)

      -- Text auf eigener Ebene über dem Sweep
      local textEbene = CreateFrame("Frame", nil, btn)
      textEbene:SetAllPoints()
      textEbene:SetFrameLevel(sweep:GetFrameLevel() + 2)
      local text = textEbene:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
      text:SetPoint("CENTER")

      btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Leuchtturm: " .. e.titel)
        if e.bekannt then GameTooltip:AddLine("Linksklick: " .. e.bekannt, 1, 1, 1) end
        if e.bekanntRechts then GameTooltip:AddLine("Rechtsklick: " .. e.bekanntRechts, 1, 1, 1) end
        if e.wert then GameTooltip:AddLine(("Anzahl: %d (Minimum %d)"):format(e.wert, e.minimum), 1, 1, 1) end
        GameTooltip:AddLine("Shift + Rechtsklick ziehen: Leiste verschieben", 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end)
      btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

      e.btn, e.icon, e.rahmen, e.puls, e.sweep, e.text = btn, icon, rahmen, puls, sweep, text
    end

    local function ErsterBekannter(liste)
      for _, n in ipairs(liste) do
        local name, ic = ns.ZauberInfo(n)
        if name then return name, ic end
      end
    end

    -- Was ist sichtbar? Zauber belegen, Buttons anordnen.
    -- (Attribute, Show/Hide und Positionen sind im Kampf gesperrt.)
    local function Anordnen()
      if InCombatLockdown() then return end
      local stufe = UnitLevel and UnitLevel("player") or 60
      local x = 0
      for _, e in ipairs(eintraege) do
        local iconID
        e.bekannt, iconID = ErsterBekannter(e.zauber)
        e.bekanntRechts = ErsterBekannter(e.rechts)

        local sichtbar = stufe >= e.abStufe
        if e.art == "zaehler" then
          sichtbar = sichtbar and e.item ~= nil
          iconID = e.item and GegenstandsIcon(e.item)
        elseif e.art == "munition" then
          sichtbar = sichtbar and munitionsPlatz ~= nil
          iconID = (munitionsPlatz and GetInventoryItemTexture("player", munitionsPlatz))
                   or "Interface\\Icons\\INV_Ammo_Arrow_02"
        else
          sichtbar = sichtbar and e.bekannt ~= nil
        end
        e.sichtbar = sichtbar

        e.btn:SetAttribute("type1", e.bekannt and "spell" or nil)
        e.btn:SetAttribute("spell1", e.bekannt)
        e.btn:SetAttribute("type2", e.bekanntRechts and "spell" or nil)
        e.btn:SetAttribute("spell2", e.bekanntRechts)

        if sichtbar then
          if iconID then e.icon:SetTexture(iconID) end
          e.btn:ClearAllPoints()
          e.btn:SetPoint("LEFT", anker, "LEFT", x, 0)
          e.btn:Show()
          x = x + g + einst.abstand
        else
          e.btn:Hide()
        end
      end
      anker:SetSize(math.max(g, x - einst.abstand), g)
    end

    local function SetzeSweep(e)
      if e.ablauf and e.ablauf ~= DAUERHAFT and e.dauer and e.dauer > 0 then
        e.sweep:SetCooldown(e.ablauf - e.dauer, e.dauer)
      else
        e.sweep:Clear()
      end
    end
    local function AlleSweeps() for _, e in ipairs(eintraege) do SetzeSweep(e) end end

    -- -----------------------------------------------------------------
    -- Anzeige
    -- -----------------------------------------------------------------
    local function Warnen(nachricht)
      local jetzt = GetTime()
      if einst.ton and jetzt - letzterTon > 1 then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
        letzterTon = jetzt
      end
      if einst.bildschirmText and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, nachricht, ChatTypeInfo["RAID_WARNING"])
      end
    end

    local function SetzeZustand(e, neu, text)
      if neu == "aktiv" or neu == "ruhe" then
        e.btn:SetAlpha(neu == "aktiv" and einst.alphaAktiv or einst.alphaRuhe)
        e.icon:SetDesaturated(neu == "aktiv")
        e.rahmen:Hide(); e.puls:Stop()
        e.text:SetTextColor(1, 1, 1)
        e.text:SetText(text or "")
      else
        local r, gr, b = 1, 0.15, 0.1
        if neu == "bald" then r, gr, b = 1, 0.82, 0 end
        e.btn:SetAlpha(1)
        e.icon:SetDesaturated(false)
        e.rahmen:SetVertexColor(r, gr, b); e.rahmen:Show()
        if not e.puls:IsPlaying() then e.puls:Play() end
        e.text:SetTextColor(r, gr, b)
        e.text:SetText(text or "")
      end

      if neu ~= e.zustand then
        if neu == "bald"  then Warnen(e.meldung.bald:format(e.titel)) end
        if neu == "fehlt" then Warnen(e.meldung.fehlt:format(e.titel)) end
        e.zustand = neu
      end
    end

    -- Liefert Zustand ("aktiv" | "bald" | "fehlt") und Text
    local function Bewerte(e, jetzt)
      if e.art == "buff" or e.art == "waffe" then
        local rest = e.ablauf and (e.ablauf - jetzt) or nil
        if rest and rest <= 0 then e.ablauf, e.dauer, rest = nil, nil, nil end
        if not rest then return "fehlt", "!" end
        if rest <= e.warnenAb then return "bald", Zeitformat(rest) end
        return "aktiv", nil
      elseif e.art == "pet" then
        if e.petStatus == "weg" then return "fehlt", "!" end
        if e.petStatus == "ungluecklich" then return "bald", ":(" end
        return "aktiv", nil
      else -- zaehler, munition
        if e.wert == nil then return "aktiv", nil end
        if e.wert == 0 then return "fehlt", "0" end
        if e.wert < e.minimum then return "bald", tostring(e.wert) end
        return "aktiv", tostring(e.wert)
      end
    end

    local function KannWirken()
      if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
      if UnitOnTaxi and UnitOnTaxi("player") then return false end
      return true
    end

    local warten, wartenLangsam = 0, 0
    local uhr = CreateFrame("Frame")
    uhr:SetScript("OnUpdate", function(_, vergangen)
      warten = warten - vergangen
      wartenLangsam = wartenLangsam - vergangen
      if warten > 0 then return end
      warten = TAKT

      local jetzt = GetTime()
      if jetzt < stummBis then return end      -- Daten nach Ladebildschirm abwarten
      if testBis and jetzt > testBis then testBis = nil; AktualisiereBuffs(); Langsam(); AlleSweeps() end
      if wartenLangsam <= 0 then wartenLangsam = TAKT_LANGSAM; Langsam() end

      local wirkbar = KannWirken()
      for _, e in ipairs(eintraege) do
        if e.sichtbar then
          local zustand, text = Bewerte(e, jetzt)
          local scharf = wirkbar and (imKampf or e.wann == "immer" or testBis ~= nil)
          if zustand ~= "aktiv" and not scharf then
            -- Zähler zeigen ihre Zahl auch in Ruhe; Buffs nicht
            SetzeZustand(e, "ruhe", (e.art == "zaehler" or e.art == "munition") and text or nil)
          else
            SetzeZustand(e, zustand, text)
          end
        end
      end
    end)

    -- -----------------------------------------------------------------
    -- Ereignisse
    -- -----------------------------------------------------------------
    local ev = CreateFrame("Frame")
    ev:RegisterUnitEvent("UNIT_AURA", "player")
    ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("PLAYER_DEAD")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    ev:SetScript("OnEvent", function(_, ereignis, _, _, zauberID)
      if ereignis == "UNIT_SPELLCAST_SUCCEEDED" then
        if ns.IstGeheim(zauberID) then return end
        local name = ns.ZauberName(zauberID)
        if not name then return end
        for _, e in ipairs(eintraege) do
          if (e.art == "buff" or e.art == "waffe") and e.zaehlt[name] then
            local d = DauerFuer(name, e)
            if d == 0 then
              e.ablauf, e.dauer = DAUERHAFT, 0
            else
              e.ablauf, e.dauer = GetTime() + d, d
            end
            SetzeSweep(e)
          end
        end
      elseif ereignis == "UNIT_AURA" then
        AktualisiereBuffs(); AlleSweeps()
      elseif ereignis == "PLAYER_REGEN_DISABLED" then
        imKampf = true
      elseif ereignis == "PLAYER_REGEN_ENABLED" then
        imKampf = false
        Anordnen(); AktualisiereBuffs(); Langsam(); AlleSweeps()
      elseif ereignis == "PLAYER_DEAD" then
        for _, e in ipairs(eintraege) do
          if e.art == "buff" then e.ablauf, e.dauer = nil, nil end
        end
        AlleSweeps()
      elseif ereignis == "SPELLS_CHANGED" or ereignis == "PLAYER_LEVEL_UP"
          or ereignis == "PLAYER_EQUIPMENT_CHANGED" then
        Anordnen()
      elseif ereignis == "PLAYER_ENTERING_WORLD" then
        imKampf = InCombatLockdown()
        stummBis = GetTime() + STUMM_NACH_LADEN
        Anordnen(); AktualisiereBuffs(); Langsam(); AlleSweeps()
      end
    end)

    -- -----------------------------------------------------------------
    -- Befehle
    -- -----------------------------------------------------------------
    ns:RegistriereBefehl("leiste", "alle Einträge der Leiste und ihren Status anzeigen", function()
      local jetzt = GetTime()
      for _, e in ipairs(eintraege) do
        local status
        if not e.sichtbar then
          if e.art == "zaehler" or e.art == "munition" or (UnitLevel and UnitLevel("player") < e.abStufe) then
            status = "|cff999999ausgeblendet|r"
          else
            status = "|cff999999nicht im Zauberbuch:|r " .. table.concat(e.zauber, ", ")
          end
        elseif e.art == "zaehler" or e.art == "munition" then
          status = ("%s Stück (Minimum %d)"):format(tostring(e.wert or "?"), e.minimum)
        elseif e.art == "pet" then
          status = ({ da = "da", weg = "|cffff5555fehlt|r", ungluecklich = "|cffffcc00unglücklich|r" })[e.petStatus or ""] or "?"
        elseif e.ablauf == DAUERHAFT then
          status = "aktiv (dauerhaft)"
        elseif e.ablauf then
          status = ("aktiv, noch %s"):format(Zeitformat(e.ablauf - jetzt))
        else
          status = "|cffff5555fehlt|r"
        end
        ns.Ausgabe(("%s: %s"):format(e.titel, status))
      end
    end)
    ns:RegistriereBefehl("test", "Warnungen testen (Buffs laufen in 5 s aus)", function()
      testBis = GetTime() + 40
      stummBis = 0
      for _, e in ipairs(eintraege) do
        if e.art == "buff" or e.art == "waffe" then
          e.ablauf, e.dauer = GetTime() + 5, 5
          SetzeSweep(e)
        end
      end
    end)
    ns:RegistriereBefehl("reset", "Position der Leiste zurücksetzen", function()
      if InCombatLockdown() then ns.Ausgabe("Nicht im Kampf.") return end
      db.position = nil
      SetzeStartposition()
    end)

    Anordnen(); AktualisiereBuffs(); Langsam(); AlleSweeps()
  end,
})
