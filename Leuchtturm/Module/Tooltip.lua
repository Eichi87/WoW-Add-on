--[[ Leuchtturm – Modul: Tooltips (Schritt 4)

  Jeder Gegenstands-Tooltip bekommt die Charaktere (aller Spieler), die
  den Gegenstand brauchen könnten:
   - Slot, Rüstungstyp und Klasse passen, Mindeststufe erreicht
   - Rüstungs-Slots: Rüstungswert ≥ 95 % des getragenen (nach oben offen)
   - Schmuck, Ringe, Hals, Umhang, Waffen, Distanz: Mindeststufe ≥ der
     des getragenen Gegenstands
  Bei Rezepten gilt das für den Ergebnis-Gegenstand.

  Anzeige:  Könnte brauchen: Julias Priesterin (Lyra), trägt aktuell Robe der Eule
  Daneben öffnen sich bis zu zwei Vergleichs-Tooltips mit dem getragenen
  Gegenstand (aus dem gespeicherten Item-Link, also mit allen Stats).
  Der gerade gespielte Charakter wird nicht aufgeführt – für ihn zeigt
  das Spiel den Vergleich selbst (Shift).
]]

local ADDON, ns = ...
local W = ns.W

local T = {}
ns.Tooltip = T

-- Ergebnis-Gegenstand eines Rezept-Gegenstands
function T.ErgebnisVonRezept(info)
  local r = info.rezept
  for _, e in ipairs(W.AlleCharaktere()) do
    local b = r.beruf and e.c.berufe and e.c.berufe[r.beruf]
    local rz = b and b.rezepte and b.rezepte[r.name]
    if rz and rz.ergebnis then
      local voll = W.ItemInfo(rz.ergebnisLink or rz.ergebnis)
      if voll then return voll end
      if rz.ergebnisInfo then
        local k = {}
        for a, v in pairs(rz.ergebnisInfo) do k[a] = v end
        k.name, k.link = W.LinkName(rz.ergebnisLink), rz.ergebnisLink
        return k
      end
    end
  end
  -- Niemand kennt das Rezept: Ergebnis trägt fast immer den Rezeptnamen
  return W.ItemInfo(r.name)
end

-- Liste { eintrag, getragen } für einen Gegenstand
function T.Kandidaten(info)
  local ziel = info
  if info.rezept then ziel = T.ErgebnisVonRezept(info) end
  if not (ziel and ziel.slot) then return {} end
  local liste = {}
  for _, e in ipairs(W.AlleCharaktere()) do
    if not W.IstAktuell(e) then
      local ja, getragen = W.KoennteBrauchen(ziel, e.c)
      if ja then liste[#liste + 1] = { eintrag = e, getragen = getragen } end
    end
  end
  return liste
end

ns:RegistriereModul({
  name  = "tooltip",
  titel = "Tooltip-Hinweise",
  standard = { aktiv = true, vergleiche = 2, altWarnungStunden = 24 },

  init = function(ctx, einst)
    local vergleich = {}
    for i = 1, einst.vergleiche do
      local tt = CreateFrame("GameTooltip", "LeuchtturmVergleich" .. i, UIParent, "GameTooltipTemplate")
      tt:SetFrameStrata("TOOLTIP")
      tt:SetScale(0.9)
      vergleich[i] = tt
    end
    local function VergleichAus()
      for _, tt in ipairs(vergleich) do tt:Hide() end
    end

    local function ZeigeVergleich(tooltip, liste)
      VergleichAus()
      if tooltip ~= GameTooltip then return end
      local anker = tooltip
      for _, s in ipairs({ ShoppingTooltip2, ShoppingTooltip1 }) do
        if s and s:IsShown() then anker = s break end
      end
      local n = 0
      for _, k in ipairs(liste) do
        if n >= #vergleich then break end
        if k.getragen and k.getragen.link then
          n = n + 1
          local tt = vergleich[n]
          tt:SetOwner(tooltip, "ANCHOR_NONE")
          tt:ClearAllPoints()
          local rechtsFrei = (anker:GetRight() or 0) + 300 < (UIParent:GetRight() or 1920)
          if rechtsFrei then tt:SetPoint("TOPLEFT", anker, "TOPRIGHT", 4, 0)
          else tt:SetPoint("TOPRIGHT", anker, "TOPLEFT", -4, 0) end
          if pcall(tt.SetHyperlink, tt, k.getragen.link) then
            tt:AddLine(" ")
            tt:AddLine("Getragen von " .. W.Bezeichnung(k.eintrag), 0.31, 0.76, 0.97)
            tt:Show()
            anker = tt
          else
            tt:Hide(); n = n - 1
          end
        end
      end
    end

    local function Ergaenze(tooltip, link)
      if not link or tooltip.leuchtturmFertig == link then return end
      tooltip.leuchtturmFertig = link
      local info = W.ItemInfo(link)
      if not info then return end
      local liste = T.Kandidaten(info)
      if #liste == 0 then VergleichAus() return end
      local grenze = time() - einst.altWarnungStunden * 3600
      for _, k in ipairs(liste) do
        local getragen = k.getragen and W.LinkName(k.getragen.link) or "nichts in diesem Slot"
        local alt = ""
        if (k.eintrag.c.aktualisiert or 0) < grenze then
          alt = " |cff999999(Stand " .. W.Alter(k.eintrag.c.aktualisiert) .. ")|r"
        end
        tooltip:AddLine(("Könnte brauchen: %s, trägt aktuell %s%s"):format(
          W.Bezeichnung(k.eintrag), getragen, alt), 0.31, 0.76, 0.97, true)
      end
      tooltip:Show()
      ZeigeVergleich(tooltip, liste)
    end

    local function Verarbeite(tooltip)
      if not (tooltip and tooltip.GetItem) then return end
      local ok, _, link = pcall(tooltip.GetItem, tooltip)
      if not ok or ns.IstGeheim(link) then return end
      pcall(Ergaenze, tooltip, link)
    end

    -- Moderne Tooltip-API (Mainline) oder klassischer Hook
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        tooltip.leuchtturmFertig = nil
        Verarbeite(tooltip)
      end)
    else
      for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt then
          tt:HookScript("OnTooltipSetItem", Verarbeite)
          tt:HookScript("OnTooltipCleared", function(self) self.leuchtturmFertig = nil end)
        end
      end
    end
    GameTooltip:HookScript("OnHide", VergleichAus)
  end,
})
