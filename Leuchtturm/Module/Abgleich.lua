--[[ Leuchtturm – Modul: Datenabgleich (Schritt 5, Addon-Seite)

  Transport ist Syncthing, nicht das Addon: Ein Addon darf weder Dateien
  lesen noch Netzwerkverbindungen aufbauen und schreibt nur seine eigenen
  gespeicherten Variablen. Ablauf:

   1. Beim Logout / Charakterwechsel / /reload schreibt das Spiel
      LeuchtturmDB in WTF\Account\<KONTO>\SavedVariables\Leuchtturm.lua.
   2. Das Hilfsskript (Werkzeug\leuchtturm_sync.py) kopiert diese Datei
      als Sync\<Spieler>.lua in den Syncthing-Ordner (jeder nur seine eigene)
      und erzeugt aus allen Spielerdateien dort die Index.lua.
   3. Das Spiel lädt Index.lua (steht in der .toc) beim Login oder /reload.
      Dieses Modul liest daraus die Daten aller anderen Spieler – neue
      Spieler tauchen dadurch automatisch auf.

  Die Spielerdateien werden in einer leeren Umgebung ausgeführt (setfenv),
  eine kaputte Datei kann also nichts anderes stören.
]]

local ADDON, ns = ...
local W = ns.W

ns.fremd = {}         -- Spieler → { spieler = {…}, geaendert = Zeitpunkt der Datei }

local function LadeIndex()
  local index = LeuchtturmIndex
  ns.fremd = {}
  local fehler = {}
  if type(index) ~= "table" then return fehler end
  for _, d in ipairs(index.dateien or {}) do
    if type(d.inhalt) == "string" and d.spieler and d.spieler ~= ns.ich then
      local f, err = loadstring(d.inhalt, "Leuchtturm-" .. d.spieler)
      if f then
        local umgebung = {}
        setfenv(f, umgebung)
        local ok, err2 = pcall(f)
        local db = umgebung.LeuchtturmDB
        if ok and type(db) == "table" and type(db.spieler) == "table" then
          ns.fremd[d.spieler] = { spieler = db.spieler, geaendert = d.geaendert }
        else
          fehler[#fehler + 1] = d.spieler .. ": " .. tostring(err2 or "keine Leuchtturm-Daten")
        end
      else
        fehler[#fehler + 1] = d.spieler .. ": " .. tostring(err)
      end
      d.inhalt = nil      -- Speicher freigeben, wird nicht mehr gebraucht
    end
  end
  return fehler
end

-- Neuester Stand je Spieler (über alle seine Charaktere)
local function StandJeSpieler()
  local stand = {}
  for _, e in ipairs(W.AlleCharaktere()) do
    local s = stand[e.spieler] or { chars = 0, berufe = 0, rezepte = 0, neuester = 0, quelle = e.quelle }
    s.chars = s.chars + 1
    s.neuester = math.max(s.neuester, e.c.aktualisiert or 0)
    for _, b in pairs(e.c.berufe or {}) do
      s.berufe = s.berufe + 1
      for _ in pairs(b.rezepte or {}) do s.rezepte = s.rezepte + 1 end
    end
    stand[e.spieler] = s
  end
  return stand
end
ns.StandJeSpieler = StandJeSpieler

ns:RegistriereModul({
  name  = "abgleich",
  titel = "Datenabgleich",
  standard = { aktiv = true, meldungBeimLogin = true },

  init = function(ctx, einst)
    local fehler = LadeIndex()
    for _, f in ipairs(fehler) do ns.Ausgabe("|cffff5555Spielerdatei nicht lesbar:|r " .. f) end

    local function Uebersicht(ausfuehrlich)
      local index = LeuchtturmIndex or {}
      if (index.erzeugt or 0) == 0 then
        ns.Ausgabe("Daten der anderen: noch keine – Hilfsskript ist noch nicht gelaufen.")
      elseif ausfuehrlich then
        ns.Ausgabe("Index erzeugt " .. W.Alter(index.erzeugt) .. ".")
      end
      local stand = StandJeSpieler()
      local namen = {}
      for n in pairs(stand) do namen[#namen + 1] = n end
      table.sort(namen)
      for _, n in ipairs(namen) do
        local s = stand[n]
        local wer = (n == ns.ich) and " (du)" or ""
        if ausfuehrlich then
          ns.Ausgabe(("%s%s: %d Charakter(e), %d Berufe, %d Rezepte – Stand %s"):format(
            n, wer, s.chars, s.berufe, s.rezepte, W.Alter(s.neuester)))
        elseif n ~= ns.ich then
          ns.Ausgabe(("Daten von %s: Stand %s (%d Charakter(e))"):format(n, W.Alter(s.neuester), s.chars))
        end
      end
      if ausfuehrlich then
        for _, e in ipairs(W.AlleCharaktere()) do
          local b = {}
          for _, x in pairs(e.c.berufe or {}) do
            local r = 0
            for _ in pairs(x.rezepte or {}) do r = r + 1 end
            b[#b + 1] = ("%s %s/%s (%d Rezepte)"):format(x.name, tostring(x.stufe or "?"), tostring(x.max or "?"), r)
          end
          table.sort(b)
          ns.Ausgabe(("  %s, Stufe %s: %s – %s"):format(W.Bezeichnung(e), tostring(e.c.stufe or "?"),
            #b > 0 and table.concat(b, ", ") or "keine Berufe", W.Alter(e.c.aktualisiert)))
        end
        ns.Ausgabe("Neu laden mit /ltm neu (Spiel liest fremde Daten nur beim Login oder Reload).")
      end
    end

    if einst.meldungBeimLogin and C_Timer then
      C_Timer.After(6, function() Uebersicht(false) end)
    end

    ns:RegistriereBefehl("daten", "Stand der Daten aller Spieler und Charaktere anzeigen", function()
      if ns.DatenAktualisieren then ns.DatenAktualisieren() end
      Uebersicht(true)
    end)
    ns:RegistriereBefehl("neu", "neu laden, um frische Daten der anderen einzulesen (= /reload)", function()
      if InCombatLockdown() then ns.Ausgabe("Nicht im Kampf.") return end
      ReloadUI()
    end)
  end,
})
