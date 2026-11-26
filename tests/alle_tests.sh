#!/bin/sh
# Leuchtturm: kompletter Durchlauf in der Mock-Umgebung (Lua 5.1 + Python 3).
# Zwei getrennte "PCs" (Daniel, Julia), Syncthing wird durch Kopieren nachgestellt.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d)
for wer in daniel julia; do
  mkdir -p "$T/$wer/Interface/AddOns" "$T/$wer/WTF/Account"
  cp -r Leuchtturm "$T/$wer/Interface/AddOns/"
done
sync() { # $1 = wer, $2 = Spieler
  # das Skript wartet, bis die Variablen-Datei mind. 1 s alt ist – hier vordatieren
  find "$T/$1/WTF" -name Leuchtturm.lua -exec touch -d '5 seconds ago' {} +
  python3 Werkzeug/leuchtturm_sync.py --einmal --wow_ordner "$T/$1" --spieler "$2"
}
syncthing() { # $1 von, $2 nach
  cp "$T/$1/Interface/AddOns/Leuchtturm_Sync/"*.lua "$T/$2/Interface/AddOns/Leuchtturm_Sync/"
}
echo "== Julia spielt, loggt aus"; lua5.1 tests/szenario.lua julia1 "$T/julia"
sync julia Julia
mkdir -p "$T/daniel/Interface/AddOns/Leuchtturm_Sync"; syncthing julia daniel
echo "== Daniel: Abgleich, dann Login"; sync daniel Daniel
lua5.1 tests/szenario.lua daniel "$T/daniel"
sync daniel Daniel; syncthing daniel julia
echo "== Julia: Abgleich, dann Login"; sync julia Julia
lua5.1 tests/szenario.lua julia2 "$T/julia"
sync julia Julia >/dev/null
echo "== Unveränderter zweiter Abgleich schreibt nichts:"
if sync julia Julia | grep -q "kopiert\|Index neu"; then echo "FEHLER: zweiter Abgleich hat geschrieben"; exit 1; fi
ls "$T/julia/Interface/AddOns/Leuchtturm_Sync/"
rm -rf "$T"
echo "ALLE TESTS BESTANDEN"
