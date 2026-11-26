--[[ ===================================================================
  Leuchtturm – Config
  =====================================================================
  Nach jeder Änderung im Spiel /reload eingeben.

  1) CHARAKTERE
     Schlüssel: "Charaktername" oder "Charaktername-Realm"
     (Realm wie im Spiel, ohne Leerzeichen; "Name-Realm" hat Vorrang).

     spieler: wem der Charakter gehört ("Daniel", "Julia", später z. B.
              "Björn" – beliebig viele). Darunter legt die Datenbasis ihn ab,
              und so heißt die Spielerdatei im Syncthing-Ordner.
              Fehlt ein Charakter hier, einmal /ltm ich <Name> eingeben.
     klasse : wird automatisch erkannt, hier nur zur Kontrolle.
              WARRIOR, PALADIN, HUNTER, ROGUE, PRIEST, SHAMAN, MAGE,
              WARLOCK, DRUID
     rolle  : "Tank", "Heiler" oder "DD" – Buffs können darauf reagieren
              (ohne Angabe gilt "DD")
     spec   : frei wählbarer Text (z. B. "Schutz", "Heilig", "Furor")
     module : optional – Einstellungen nur für diesen Charakter

  2) LEISTE JE KLASSE (weiter unten)
     art        : "buff" (Standard), "waffe" (Waffenverzauberung),
                  "pet" (Begleiter), "zaehler" (Gegenstand in Taschen),
                  "munition" (angelegte Munition)
     titel      : Anzeigename
     zauber     : Zaubername wie im Zauberbuch (deutscher Client!) oder
                  eine Liste – dann zählt jeder davon, gewirkt wird der
                  erste, den der Charakter kennt (also Wichtigstes zuerst)
     zaehltAuch : Buffs, die ebenfalls zählen, aber nicht gewirkt werden
                  (z. B. die Gruppenversion von jemand anderem)
     dauer      : Sekunden; nur Startwert, das Addon lernt die echte
                  Dauer selbst. 0 = dauerhaft (Auren, Aspekte)
     warnenAb   : ab so vielen Restsekunden warnen
     wann       : "kampf" = nur im Kampf warnen, "immer" = auch außerhalb
     rollen     : optional, z. B. { "Tank" } – nur bei dieser Rolle
     specs      : optional, z. B. { "Schutz" } – nur bei dieser Spec
     abStufe    : optional – erst ab dieser Charakterstufe anzeigen
     rechts     : optional – Zauber auf Rechtsklick (z. B. Tier wiederbeleben)
     item       : nur "zaehler": Gegenstands-ID (Seelensplitter = 6265)
     minimum    : nur "zaehler"/"munition": darunter wird gewarnt
     hand       : nur "waffe": "haupt" (Standard) oder "neben"

  Zauber, die ein Charakter (noch) nicht kennt, werden einfach nicht
  angezeigt. /ltm leiste zeigt, was gefunden wurde – so fallen auch
  Tippfehler in Zaubernamen auf.
=================================================================== ]]

Leuchtturm_Config = {

  charaktere = {
    -- Namen ersetzen bzw. Zeilen ergänzen:
    ["Guile"]          = { spieler = "Daniel", klasse = "WARRIOR", rolle = "DD" },
    ["Paladinname"]    = { spieler = "Daniel", klasse = "PALADIN", rolle = "Tank",   spec = "Schutz" },
    ["Druidenname"]    = { spieler = "Julia",  klasse = "DRUID",   rolle = "Tank",   spec = "Wilder Kampf" },
    ["Priestername"]   = { spieler = "Julia",  klasse = "PRIEST",  rolle = "Heiler", spec = "Heilig" },
    ["Jaegername"]     = { spieler = "Daniel", klasse = "HUNTER",  rolle = "DD" },
    ["Magiername"]     = { spieler = "Julia",  klasse = "MAGE",    rolle = "DD" },
    ["Gomez"]          = { spieler = "Daniel", klasse = "WARLOCK", rolle = "DD" },
    ["Schamanenname"]  = { spieler = "Julia",  klasse = "SHAMAN",  rolle = "DD" },
    -- weitere Spieler einfach dazuschreiben, z. B.:
    -- ["Bjoernsname"] = { spieler = "Björn", klasse = "ROGUE", rolle = "DD" },
  },

  module = {

    -- Hinweissystem (v0.4). aktiv = false schaltet ein Modul ab.
    daten    = { aktiv = true },                         -- Datenbasis (Pflicht für die anderen)
    beute    = { aktiv = true, sperreSekunden = 60 },    -- Hinweise beim Looten
    tooltip  = { aktiv = true, vergleiche = 2,           -- "Könnte brauchen" + Vergleichs-Tooltips
                 altWarnungStunden = 24 },               -- ab diesem Alter steht der Datenstand dabei
    abgleich = { aktiv = true, meldungBeimLogin = true },-- Daten der anderen über Index.lua

    leiste = {
      aktiv          = true,
      groesse        = 56,     -- Kantenlänge der Buttons in Pixeln
      abstand        = 8,      -- Abstand zwischen den Buttons
      ton            = true,   -- Warnton
      bildschirmText = true,   -- große Raid-Warnung in der Bildschirmmitte
      alphaAktiv     = 0.35,   -- Deckkraft, solange ein Buff sicher läuft (0 = unsichtbar)
      alphaRuhe      = 0.6,    -- Deckkraft, wenn er fehlt, aber gerade nicht gewarnt wird

      klassen = {

        WARRIOR = {
          { titel = "Schlachtruf", zauber = "Schlachtruf", dauer = 120, warnenAb = 15, wann = "kampf" },
        },

        PALADIN = {
          { titel = "Zorn der Gerechtigkeit", zauber = "Zorn der Gerechtigkeit",
            dauer = 1800, warnenAb = 60, wann = "immer", rollen = { "Tank" } },
          { titel = "Segen (Tank)",
            zauber = { "Segen der Könige", "Segen des Refugiums", "Segen der Macht" },
            zaehltAuch = { "Großer Segen der Könige", "Großer Segen des Refugiums", "Großer Segen der Macht" },
            dauer = 300, warnenAb = 30, wann = "immer", rollen = { "Tank" } },
          { titel = "Segen",
            zauber = { "Segen der Könige", "Segen der Macht", "Segen der Weisheit" },
            zaehltAuch = { "Großer Segen der Könige", "Großer Segen der Macht", "Großer Segen der Weisheit" },
            dauer = 300, warnenAb = 30, wann = "immer", rollen = { "DD", "Heiler" } },
          { titel = "Aura",
            zauber = { "Aura der Hingabe", "Vergeltungsaura", "Konzentrationsaura" },
            dauer = 0, wann = "immer" },
        },

        DRUID = {
          { titel = "Mal der Wildnis", zauber = "Mal der Wildnis", zaehltAuch = { "Gabe der Wildnis" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
          { titel = "Dornen", zauber = "Dornen", dauer = 600, warnenAb = 30, wann = "immer" },
          { titel = "Omen der Klarsicht", zauber = "Omen der Klarsicht", dauer = 600, warnenAb = 30, wann = "immer" },
        },

        PRIEST = {
          { titel = "Seelenstärke", zauber = "Machtwort: Seelenstärke", zaehltAuch = { "Gebet der Seelenstärke" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
          { titel = "Inneres Feuer", zauber = "Inneres Feuer", dauer = 600, warnenAb = 30, wann = "immer" },
          { titel = "Göttlicher Willen", zauber = "Göttlicher Willen", zaehltAuch = { "Gebet des Willens" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
        },

        HUNTER = {
          { titel = "Aspekt", zauber = { "Aspekt des Falken", "Aspekt des Affen" },
            zaehltAuch = { "Aspekt des Geparden", "Aspekt des Rudels", "Aspekt der Wildnis", "Aspekt der Bestie" },
            dauer = 0, wann = "immer" },
          { titel = "Aura des Volltreffers", zauber = "Aura des Volltreffers", dauer = 1800, warnenAb = 60, wann = "immer" },
          { art = "pet", titel = "Begleiter", zauber = "Tier rufen", rechts = "Tier wiederbeleben" },
          { art = "munition", titel = "Munition", minimum = 200 },
        },

        MAGE = {
          { titel = "Arkane Intelligenz", zauber = "Arkane Intelligenz", zaehltAuch = { "Arkane Brillanz" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
          { titel = "Rüstung", zauber = { "Eisrüstung", "Frostrüstung", "Magische Rüstung" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
        },

        WARLOCK = {
          { titel = "Rüstung", zauber = { "Dämonenrüstung", "Dämonenhaut" },
            dauer = 1800, warnenAb = 60, wann = "immer" },
          -- Reihenfolge = Wunschdämon zuerst (gewirkt wird der erste bekannte)
          { art = "pet", titel = "Dämon",
            zauber = { "Leerwandler beschwören", "Wichtel beschwören", "Sukkubus beschwören", "Teufelsjäger beschwören" } },
          { art = "zaehler", titel = "Seelensplitter", item = 6265, minimum = 3, abStufe = 10 },
        },

        SHAMAN = {
          { titel = "Blitzschlagschild", zauber = "Blitzschlagschild", dauer = 600, warnenAb = 30, wann = "immer" },
          -- Verstärker: Windzorn zuerst; Elementar: Flammenzunge nach vorne ziehen
          { art = "waffe", titel = "Waffe",
            zauber = { "Waffe des Windzorns", "Waffe der Flammenzunge", "Waffe des Felsbeißers" },
            zaehltAuch = { "Waffe des Frostbrands" }, dauer = 300, warnenAb = 30 },
        },

      },
    },

  },
}
