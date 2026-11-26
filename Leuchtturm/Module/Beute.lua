--[[ Leuchtturm – Modul: Hinweise beim Looten (Schritt 2 und 3)

  Beim Öffnen eines Beutefensters und beim Erhalt eines Gegenstands
  (Plündern, Aufnehmen, Quest, Handel …) prüft Leuchtturm alle
  Charaktere aller Spieler:

  Rezept  – wer hat den Beruf und kennt das Rezept noch nicht?
            Zu niedriger Skill steht nur als Zusatzinfo dabei.
  Zutat   – wer braucht das Material noch zum Leveln? (mindestens ein
            bekanntes Rezept mit dieser Zutat ist für ihn noch nicht grau)
  Handwerk – wer könnte sich daraus über einen Handwerker ein Upgrade
            herstellen lassen, und wer kann es herstellen? (Schritt 3)

  Angeln, Erste Hilfe und Kochen werden komplett ignoriert. Stoff zählt
  dadurch automatisch nur für Schneider.
  Ausgabe im Chatfenster. Derselbe Gegenstand wird höchstens alle
  60 Sekunden gemeldet.
]]

local ADDON, ns = ...
local W = ns.W

local B = {}
ns.Beute = B

-- Rezept: Liste { eintrag, zusatz }
function B.RezeptKandidaten(info)
  local r = info and info.rezept
  if not (r and r.beruf) or W.BerufIgnoriert(r.beruf) then return {} end
  local liste = {}
  for _, e in ipairs(W.AlleCharaktere()) do
    local b = e.c.berufe and e.c.berufe[r.beruf]
    if b and not (b.rezepte and b.rezepte[r.name]) then
      local zusatz
      if not b.rezepteStand then
        zusatz = "Rezepte noch nicht erfasst – Berufsfenster einmal öffnen"
      elseif r.skill and (b.stufe or 0) < r.skill then
        zusatz = ("Skill %d/%d, noch zu niedrig"):format(b.stufe or 0, r.skill)
      end
      liste[#liste + 1] = { eintrag = e, zusatz = zusatz }
    end
  end
  return liste
end

-- Zutat zum Leveln: Liste { eintrag, beruf, anzahl (nicht graue Rezepte) }
function B.ZutatKandidaten(itemID)
  local liste = {}
  if not itemID then return liste end
  for _, e in ipairs(W.AlleCharaktere()) do
    for bkey, b in pairs(e.c.berufe or {}) do
      if not W.BerufIgnoriert(bkey) then
        local anzahl = 0
        for _, rz in pairs(b.rezepte or {}) do
          if rz.zutaten and rz.zutaten[itemID] and rz.farbe ~= "grau" then anzahl = anzahl + 1 end
        end
        if anzahl > 0 then liste[#liste + 1] = { eintrag = e, beruf = b.name, anzahl = anzahl } end
      end
    end
  end
  return liste
end

-- Schritt 3: Upgrades aus dieser Zutat.
-- Liste { ergebnisName, fuer = {eintrag…}, hersteller = {eintrag…} }, je Gegenstand eine Zeile
function B.HandwerkKandidaten(itemID)
  local liste = {}
  if not itemID then return liste end
  local alle = W.AlleCharaktere()
  -- alle herstellbaren Gegenstände mit dieser Zutat sammeln
  local produkte = {}   -- ergebnisID → { info, name, hersteller = {} }
  for _, k in ipairs(alle) do
    for bkey, b in pairs(k.c.berufe or {}) do
      if not W.BerufIgnoriert(bkey) then
        for rname, rz in pairs(b.rezepte or {}) do
          if rz.zutaten and rz.zutaten[itemID] and rz.ergebnis then
            local info = rz.ergebnisInfo or W.Kurzinfo(W.ItemInfo(rz.ergebnisLink or rz.ergebnis))
            if info and info.slot then
              local p = produkte[rz.ergebnis]
              if not p then
                local n = W.LinkName(rz.ergebnisLink)
                p = { info = info, name = (n ~= "?" and n) or rname, hersteller = {} }
                produkte[rz.ergebnis] = p
              end
              p.hersteller[#p.hersteller + 1] = k
            end
          end
        end
      end
    end
  end
  for _, p in pairs(produkte) do
    local fuer = {}
    for _, e in ipairs(alle) do
      if W.KoennteBrauchen(p.info, e.c) then fuer[#fuer + 1] = e end
    end
    if #fuer > 0 then liste[#liste + 1] = { ergebnisName = p.name, fuer = fuer, hersteller = p.hersteller } end
  end
  table.sort(liste, function(a, b) return a.ergebnisName < b.ergebnisName end)
  return liste
end

-- Alle Hinweiszeilen zu einem Gegenstand (auch vom Tooltip genutzt)
function B.Hinweise(linkOderID)
  local info = W.ItemInfo(linkOderID)
  if not info then return nil end           -- noch nicht im Cache
  local zeilen = {}
  if info.rezept then
    local k = B.RezeptKandidaten(info)
    if #k > 0 then
      local teile = {}
      for _, x in ipairs(k) do
        teile[#teile + 1] = W.Bezeichnung(x.eintrag) .. (x.zusatz and (" |cff999999(" .. x.zusatz .. ")|r") or "")
      end
      zeilen[#zeilen + 1] = "Rezept fehlt bei: " .. table.concat(teile, ", ")
    end
  else
    local z = B.ZutatKandidaten(info.id)
    if #z > 0 then
      local teile = {}
      for _, x in ipairs(z) do
        teile[#teile + 1] = ("%s – %s, %d Rezept(e) nicht grau"):format(W.Bezeichnung(x.eintrag), x.beruf, x.anzahl)
      end
      zeilen[#zeilen + 1] = "Zum Leveln gebraucht von: " .. table.concat(teile, "; ")
    end
    for _, h in ipairs(B.HandwerkKandidaten(info.id)) do
      local fs, hs = {}, {}
      for _, e in ipairs(h.fuer) do fs[#fs + 1] = W.Bezeichnung(e) end
      for _, k in ipairs(h.hersteller) do hs[#hs + 1] = W.Bezeichnung(k) end
      zeilen[#zeilen + 1] = ("Upgrade %s für %s – herstellbar von %s"):format(
        h.ergebnisName, table.concat(fs, ", "), table.concat(hs, ", "))
    end
  end
  return zeilen
end

ns:RegistriereModul({
  name  = "beute",
  titel = "Beute-Hinweise",
  standard = { aktiv = true, sperreSekunden = 60 },

  init = function(ctx, einst)
    local zuletzt = {}
    local function Melde(link, versuch)
      local id = W.ItemID(link)
      if not id then return end
      local jetzt = GetTime()
      if zuletzt[id] and jetzt - zuletzt[id] < einst.sperreSekunden then return end
      local ok, zeilen = pcall(B.Hinweise, link)
      if not ok then return end
      if zeilen == nil then                  -- Gegenstand noch nicht geladen: kurz warten
        if (versuch or 0) < 3 and C_Timer then C_Timer.After(1, function() Melde(link, (versuch or 0) + 1) end) end
        return
      end
      zuletzt[id] = jetzt
      if #zeilen == 0 then return end
      ns.Ausgabe(link)
      for _, z in ipairs(zeilen) do DEFAULT_CHAT_FRAME:AddMessage("   " .. z) end
    end
    B.Melde = Melde

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("LOOT_OPENED")
    ev:RegisterEvent("CHAT_MSG_LOOT")
    ev:SetScript("OnEvent", function(_, ereignis, nachricht, _, _, _, _, _, _, _, _, _, _, guid)
      if ereignis == "LOOT_OPENED" then
        for i = 1, (W.Sicher(GetNumLootItems) or 0) do
          local link = W.Sicher(GetLootSlotLink, i)
          if link then Melde(link) end
        end
      else
        if ns.IstGeheim(nachricht) or type(nachricht) ~= "string" then return end
        -- nur eigene Beute ("Ihr erhaltet …"), nicht die der Gruppe
        local eigen = (guid ~= nil and not ns.IstGeheim(guid) and UnitGUID and guid == UnitGUID("player"))
                      or nachricht:find("^Ihr ") or nachricht:find("^You ")
        if not eigen then return end
        local link = nachricht:match("|c%x+|Hitem:.-|h.-|h|r") or nachricht:match("|Hitem:.-|h.-|h")
        if link then Melde(link) end
      end
    end)

    ns:RegistriereBefehl("hinweis", "Hinweise zu einem Gegenstand anzeigen (Link per Shift-Klick einfügen)", function(rest)
      local link = rest:match("|Hitem:.-|h.-|h") and rest or nil
      if not link then ns.Ausgabe("Bitte einen Gegenstand per Shift-Klick einfügen.") return end
      zuletzt[W.ItemID(link) or 0] = nil
      local ok, zeilen = pcall(B.Hinweise, link)
      if ok and zeilen and #zeilen == 0 then ns.Ausgabe("Keine Hinweise zu " .. link) return end
      Melde(link)
    end)
  end,
})
