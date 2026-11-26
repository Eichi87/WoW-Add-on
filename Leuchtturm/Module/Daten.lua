--[[ Leuchtturm – Modul: Datenbasis (Schritt 1)

  Legt pro Charakter in der kontoweiten Variable LeuchtturmDB ab,
  getrennt nach Spieler und Charakter:

  LeuchtturmDB = {
    version = 1,
    ich     = "Daniel",            -- nur nötig, wenn ein Charakter nicht in der Config steht
    spieler = {
      ["Daniel"] = {
        charaktere = {
          ["Name-Realm"] = {
            name, realm, klasse ("PALADIN"), geschlecht (2 = m, 3 = w),
            rolle, spec, stufe,
            berufe = {
              [SCHNEIDEREI] = { name, stufe, max, rezepteStand,
                rezepte = { ["Kupferweste"] = { farbe = "orange"|"gelb"|"grün"|"grau",
                            id, ergebnis = itemID, ergebnisLink, ergebnisInfo = {…},
                            zutaten = { [itemID] = Menge } } } },
            },
            ausruestung = { [Slot] = { link, ruestung, stufeMin } },
            aktualisiert = time(),
          } } } } }

  Wann: Login, Logout, jeder Ausrüstungswechsel, Stufenaufstieg, Skill-
  Änderung. Rezepte kann das Spiel nur liefern, solange das Berufsfenster
  offen ist – deshalb werden sie beim Öffnen/Aktualisieren des Fensters
  erfasst und bis zum nächsten Öffnen behalten.
  Angeln, Erste Hilfe und Kochen werden nicht erfasst.
]]

local ADDON, ns = ...
local W = ns.W

local FARBE_ALT = { optimal = "orange", medium = "gelb", easy = "grün", trivial = "grau" }
local FARBE_NEU = { [0] = "orange", [1] = "gelb", [2] = "grün", [3] = "grau" }

local function Spaeter(sek, f)
  if C_Timer and C_Timer.After then C_Timer.After(sek, f) else f() end
end

ns:RegistriereModul({
  name  = "daten",
  titel = "Datenbasis",
  standard = { aktiv = true },

  init = function(ctx)
    local DB = LeuchtturmDB
    DB.version = 1
    DB.spieler = DB.spieler or {}

    local spieler = ctx.spieler or "Unbekannt"
    local key = ctx.realm and (ctx.name .. "-" .. ctx.realm) or ctx.name
    ns.ich, ns.charKey = spieler, key
    -- Kontoweite Datenbasis = ein Spieler: den ersten bekannten Namen merken
    if spieler ~= "Unbekannt" and not DB.ich then DB.ich = spieler end

    DB.spieler[spieler] = DB.spieler[spieler] or { charaktere = {} }
    local sp = DB.spieler[spieler]
    sp.charaktere = sp.charaktere or {}

    -- Aufräumen: alter Schlüssel ohne Realm ("Name-"), Charaktere unter
    -- "Unbekannt" gehören zum Spieler dieses Kontos, Doppelte entfernen
    local umzug = {}   -- erst sammeln, dann verschieben (Tabellen nicht beim Durchlaufen ändern)
    for andererName, anderer in pairs(DB.spieler) do
      for k, ch in pairs(anderer.charaktere or {}) do
        local alterSchluessel = (k == ctx.name .. "-") or (k == ctx.name and key ~= ctx.name)
        local fremdAbgelegt = andererName ~= spieler and spieler ~= "Unbekannt"
                              and (k == key or andererName == "Unbekannt")
        if alterSchluessel or fremdAbgelegt then
          local ziel = alterSchluessel and key or (k:match("%-$") and k:sub(1, -2) or k)
          umzug[#umzug + 1] = { von = anderer.charaktere, k = k, ziel = ziel, ch = ch }
        end
      end
    end
    for _, u in ipairs(umzug) do
      u.von[u.k] = nil
      local da = sp.charaktere[u.ziel]
      if not da or (u.ch.aktualisiert or 0) > (da.aktualisiert or 0) then sp.charaktere[u.ziel] = u.ch end
    end
    for andererName, anderer in pairs(DB.spieler) do
      if andererName ~= spieler and not next(anderer.charaktere or {}) then DB.spieler[andererName] = nil end
    end

    sp.charaktere[key] = sp.charaktere[key] or {}
    local c = sp.charaktere[key]
    c.berufe, c.ausruestung = c.berufe or {}, c.ausruestung or {}

    -- Diagnose für /ltm diagnose
    local diag = { berufe = "noch nicht gelesen", rezepte = "Berufsfenster noch nicht geöffnet" }
    ns.diagnose = diag

    local function Stempel() c.aktualisiert = time() end

    -- -----------------------------------------------------------------
    -- Grunddaten
    -- -----------------------------------------------------------------
    local function Grunddaten()
      c.name, c.realm, c.klasse = ctx.name, ctx.realm, ctx.klasse
      c.geschlecht = W.Sicher(UnitSex, "player") or c.geschlecht
      c.stufe      = W.Sicher(UnitLevel, "player") or c.stufe
      c.rolle      = ctx.rolle or "DD"
      c.spec       = ctx.spec
    end

    -- -----------------------------------------------------------------
    -- Berufe mit Skill-Stand
    -- -----------------------------------------------------------------
    local function Beruf(bkey, name, stufe, max)
      if not bkey or W.BerufIgnoriert(bkey) then return end
      local b = c.berufe[bkey] or { rezepte = {} }
      b.name, b.stufe, b.max = W.BERUFE[bkey].name or name, stufe, max
      c.berufe[bkey] = b
      return true
    end

    local function Berufe()
      local gefunden = {}
      if GetProfessions and GetProfessionInfo then
        local liste = { W.Sicher(GetProfessions) }
        for i = 1, 5 do
          local idx = liste[i]
          if idx then
            local name, _, stufe, max, _, _, skillLinie = W.Sicher(GetProfessionInfo, idx)
            local bkey = W.BerufSchluessel(skillLinie) or W.BerufSchluessel(name)
            if Beruf(bkey, name, stufe, max) then gefunden[bkey] = true end
          end
        end
      elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, (W.Sicher(GetNumSkillLines) or 0) do
          local name, header, _, stufe, _, _, max = W.Sicher(GetSkillLineInfo, i)
          if name and not header then
            local bkey = W.BerufSchluessel(name)
            if Beruf(bkey, name, stufe, max) then gefunden[bkey] = true end
          end
        end
      else
        diag.berufe = "keine Berufs-API gefunden"
        return
      end
      local n = 0
      for _ in pairs(gefunden) do n = n + 1 end
      diag.berufe = ("%d Beruf(e) gelesen über %s"):format(n, GetProfessions and "GetProfessions" or "GetSkillLineInfo")
      -- verlernte Berufe entfernen – aber nur, wenn das Spiel überhaupt Berufe
      -- geliefert hat (beim Logout liefert es teils nichts mehr)
      if n == 0 then return end
      for bkey in pairs(c.berufe) do
        if not gefunden[bkey] then c.berufe[bkey] = nil end
      end
    end

    -- -----------------------------------------------------------------
    -- Rezepte (nur bei offenem Berufsfenster)
    -- -----------------------------------------------------------------
    local function Rezept(liste, name, farbe, id, ergebnisLink, zutaten)
      if not name or not farbe then return end
      local ergebnis = W.ItemID(ergebnisLink)
      local info = ergebnisLink and W.ItemInfo(ergebnisLink)
      liste[name] = {
        farbe = farbe, id = id, ergebnis = ergebnis, ergebnisLink = ergebnisLink,
        ergebnisInfo = (info and info.slot) and W.Kurzinfo(info) or nil,
        zutaten = zutaten,
      }
    end

    local function RezepteNeu()
      local T = C_TradeSkillUI
      if W.Sicher(T.IsTradeSkillLinked) or W.Sicher(T.IsTradeSkillGuild)
         or W.Sicher(T.IsNPCCrafting) then return end
      local basis = W.Sicher(T.GetBaseProfessionInfo) or W.Sicher(T.GetChildProfessionInfo)
      if not basis then diag.neu = "GetBaseProfessionInfo lieferte nichts" return end
      local bkey = W.BerufSchluessel(basis.professionID) or W.BerufSchluessel(basis.parentProfessionID)
                   or W.BerufSchluessel(basis.parentProfessionName) or W.BerufSchluessel(basis.professionName)
      diag.neu = ("Beruf %s / %s (ID %s/%s) → %s"):format(tostring(basis.professionName),
        tostring(basis.parentProfessionName), tostring(basis.professionID), tostring(basis.parentProfessionID), tostring(bkey))
      if not bkey or W.BerufIgnoriert(bkey) then return end
      Beruf(bkey, basis.professionName, basis.skillLevel or (c.berufe[bkey] and c.berufe[bkey].stufe),
            basis.maxSkillLevel or (c.berufe[bkey] and c.berufe[bkey].max))
      local ids = W.Sicher(T.GetAllRecipeIDs)
      diag.neu = diag.neu .. (", %d Rezept-IDs"):format(ids and #ids or 0)
      if not ids or #ids == 0 then return end
      local rezepte, anzahl = {}, 0
      for _, id in ipairs(ids) do
        local r = W.Sicher(T.GetRecipeInfo, id)
        if r and r.learned and not r.isRecraft then
          local farbe = FARBE_NEU[r.relativeDifficulty] or FARBE_ALT[r.difficulty]
          local zutaten, ergebnisLink = {}, nil
          local s = W.Sicher(T.GetRecipeSchematic, id, false)
          if s then
            for _, slot in ipairs(s.reagentSlotSchematics or {}) do
              local reag = slot.reagents and slot.reagents[1]
              if reag and reag.itemID and slot.required ~= false then
                zutaten[reag.itemID] = slot.quantityRequired or 1
              end
            end
            if s.outputItemID then
              ergebnisLink = select(2, W.Sicher((C_Item and C_Item.GetItemInfo) or GetItemInfo, s.outputItemID))
                             or ("item:" .. s.outputItemID)
            end
          end
          Rezept(rezepte, r.name, farbe, id, ergebnisLink, zutaten)
          if rezepte[r.name] then anzahl = anzahl + 1 end
        end
      end
      diag.neu = diag.neu .. (", %d gelernt erfasst"):format(anzahl)
      if anzahl == 0 then return end
      c.berufe[bkey].rezepte, c.berufe[bkey].rezepteStand = rezepte, time()
      return bkey
    end

    local function RezepteAlt(art)  -- art = "trade" oder "craft" (Classic-API)
      local P = (art == "craft")
        and { linie = GetCraftDisplaySkillLine, anzahl = GetNumCrafts, info = GetCraftInfo,
              link = GetCraftItemLink, nReag = GetCraftNumReagents, reagLink = GetCraftReagentItemLink,
              reagInfo = GetCraftReagentInfo, expandieren = ExpandCraftSkillLine }
        or  { linie = GetTradeSkillLine, anzahl = GetNumTradeSkills, info = GetTradeSkillInfo,
              link = GetTradeSkillItemLink, nReag = GetTradeSkillNumReagents,
              reagLink = GetTradeSkillReagentItemLink, reagInfo = GetTradeSkillReagentInfo,
              expandieren = ExpandTradeSkillSubClass }
      if not (P.linie and P.anzahl and P.info) then return end
      local name, stufe, max = W.Sicher(P.linie)
      local bkey = W.BerufSchluessel(name)
      diag.alt = ("%s: Beruf %s (%s/%s) → %s, %d Zeilen"):format(art, tostring(name), tostring(stufe),
        tostring(max), tostring(bkey), W.Sicher(P.anzahl) or 0)
      if not bkey or W.BerufIgnoriert(bkey) then return end
      Beruf(bkey, name, stufe, max)
      if P.expandieren then pcall(P.expandieren, 0) end
      local rezepte, anzahl = {}, 0
      for i = 1, (W.Sicher(P.anzahl) or 0) do
        local rname, typ
        if art == "craft" then
          local a, _, t = W.Sicher(P.info, i); rname, typ = a, t
        else
          rname, typ = W.Sicher(P.info, i)
        end
        local farbe = FARBE_ALT[typ]
        if rname and farbe then
          local zutaten = {}
          for r = 1, (W.Sicher(P.nReag, i) or 0) do
            local zid = W.ItemID(W.Sicher(P.reagLink, i, r))
            local _, _, menge = W.Sicher(P.reagInfo, i, r)
            if zid then zutaten[zid] = menge or 1 end
          end
          local link = P.link and W.Sicher(P.link, i)
          if link and not link:find("item:") then link = nil end  -- Verzauberungen: kein Gegenstand
          Rezept(rezepte, rname, farbe, nil, link, zutaten)
          anzahl = anzahl + 1
        end
      end
      diag.alt = diag.alt .. (", %d Rezepte erfasst"):format(anzahl)
      if anzahl == 0 then return end
      c.berufe[bkey].rezepte, c.berufe[bkey].rezepteStand = rezepte, time()
      return bkey
    end

    local rezeptGeplant = false
    local function RezepteErfassen(art)
      if rezeptGeplant then return end
      rezeptGeplant = true
      Spaeter(0.5, function()
        rezeptGeplant = false
        -- erst die moderne API, liefert sie nichts, die klassische
        local ok, bkey = true, nil
        diag.neu, diag.alt = nil, nil
        if art ~= "craft" and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
          ok, bkey = pcall(RezepteNeu)
          if not ok then diag.neu = "Fehler: " .. tostring(bkey) end
        end
        if not (ok and bkey) then
          ok, bkey = pcall(RezepteAlt, art)
          if not ok then diag.alt = "Fehler: " .. tostring(bkey) end
        end
        diag.rezepte = (ok and bkey) and ("zuletzt erfasst: " .. W.BERUFE[bkey].name) or "Erfassung lieferte nichts"
        if ok and bkey then
          Stempel()
          local b = c.berufe[bkey]
          local n = 0
          for _ in pairs(b.rezepte or {}) do n = n + 1 end
          if b.gemeldet ~= n then
            b.gemeldet = n
            ns.Ausgabe(("%s: %d Rezepte gespeichert."):format(b.name, n))
          end
        end
      end)
    end

    -- -----------------------------------------------------------------
    -- Ausrüstung
    -- -----------------------------------------------------------------
    local function Ausruestung(nurWennDa)
      if nurWennDa then   -- beim Logout: nichts überschreiben, wenn das Spiel nichts mehr liefert
        local irgendwas = false
        for slot = 1, 19 do if W.Sicher(GetInventoryItemLink, "player", slot) then irgendwas = true break end end
        if not irgendwas then return end
      end
      for slot = 1, 19 do
        local link = W.Sicher(GetInventoryItemLink, "player", slot)
        if link then
          local info = W.ItemInfo(link)
          local alt = c.ausruestung[slot]
          if info then
            c.ausruestung[slot] = { link = link, ruestung = info.ruestung, stufeMin = info.stufeMin }
          elseif not (alt and alt.link == link) then
            c.ausruestung[slot] = { link = link }  -- Werte folgen beim nächsten Durchlauf
            Spaeter(2, function() local i2 = W.ItemInfo(link)
              if i2 and c.ausruestung[slot] and c.ausruestung[slot].link == link then
                c.ausruestung[slot].ruestung, c.ausruestung[slot].stufeMin = i2.ruestung, i2.stufeMin
              end end)
          end
        else
          c.ausruestung[slot] = nil
        end
      end
    end

    local function Alles()
      pcall(Grunddaten); pcall(Berufe); pcall(Ausruestung); Stempel()
    end
    ns.DatenAktualisieren = Alles

    -- -----------------------------------------------------------------
    -- Ereignisse
    -- -----------------------------------------------------------------
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGOUT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
                         "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
                         "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
                         "PLAYER_SPECIALIZATION_CHANGED" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    local ausrGeplant = false
    ev:SetScript("OnEvent", function(_, ereignis)
      if ereignis == "PLAYER_LOGOUT" then
        -- letzter Stand vor dem Speichern; Berufe nicht neu lesen (liefert beim Logout teils nichts)
        pcall(Grunddaten); pcall(Ausruestung, true); Stempel()
      elseif ereignis == "PLAYER_EQUIPMENT_CHANGED" then
        if ausrGeplant then return end
        ausrGeplant = true
        Spaeter(0.3, function() ausrGeplant = false; pcall(Ausruestung); Stempel() end)
      elseif ereignis == "PLAYER_LEVEL_UP" then
        Spaeter(0.5, function() pcall(Grunddaten); Stempel() end)
      elseif ereignis == "SKILL_LINES_CHANGED" or ereignis == "PLAYER_SPECIALIZATION_CHANGED" then
        pcall(Grunddaten); pcall(Berufe); Stempel()
      elseif ereignis == "CRAFT_SHOW" or ereignis == "CRAFT_UPDATE" then
        RezepteErfassen("craft")
      else
        RezepteErfassen("trade")
      end
    end)

    Alles()
    Spaeter(3, Alles)  -- Item-Werte, die beim Login noch nicht im Cache waren

    -- -----------------------------------------------------------------
    -- Befehle
    -- -----------------------------------------------------------------
    ns:RegistriereBefehl("ich", "Spielername für dieses WoW-Konto setzen (z. B. /ltm ich Julia)", function(rest)
      if rest == "" then ns.Ausgabe("Spieler: " .. tostring(ns.ich)) return end
      DB.ich = rest
      ns.Ausgabe(("Spieler gesetzt: %s – wirkt nach /reload (/ltm neu)."):format(rest))
    end)
    ns:RegistriereBefehl("diagnose", "Technische Infos für Claude (bei offenem Berufsfenster eingeben)", function()
      ns.Ausgabe(("Version %s | Charakter %s | Spieler %s"):format(
        tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
                 or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version"))), key, spieler))
      ns.Ausgabe("Berufe: " .. tostring(diag.berufe))
      ns.Ausgabe("Rezepte: " .. tostring(diag.rezepte))
      ns.Ausgabe("  moderne API: " .. tostring(diag.neu or (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and "nicht benutzt" or "fehlt")))
      ns.Ausgabe("  klassische API: " .. tostring(diag.alt or (GetTradeSkillLine and "nicht benutzt" or "fehlt")))
      local apis = {}
      for _, n in ipairs({ "GetProfessions", "GetSkillLineInfo", "GetTradeSkillLine", "GetNumTradeSkills",
                           "GetCraftDisplaySkillLine", "GetItemStats", "loadstring", "setfenv" }) do
        apis[#apis + 1] = n .. (_G[n] and "+" or "-")
      end
      apis[#apis + 1] = "C_TradeSkillUI" .. (C_TradeSkillUI and "+" or "-")
      apis[#apis + 1] = "TooltipDataProcessor" .. (TooltipDataProcessor and "+" or "-")
      ns.Ausgabe("APIs: " .. table.concat(apis, " "))
    end)
  end,
})
