#!/usr/bin/env python3
"""Leuchtturm – Hilfsskript für den Datenabgleich per Syncthing (Schritt 5).

Was es tut:
  1. Kopiert die eigene Variablen-Datei des Addons
       <WoW>\\WTF\\Account\\<KONTO>\\SavedVariables\\Leuchtturm.lua
     in den Syncthing-Ordner als  <Spieler>.lua  (jeder schreibt nur seine
     eigene Datei, dadurch gibt es keine Konflikte).
  2. Erzeugt aus allen Spielerdateien im Syncthing-Ordner die Indexdatei
       <WoW>\\Interface\\AddOns\\Leuchtturm\\Index.lua
     Das Addon lädt sie beim Login bzw. /reload und liest darüber die
     Daten aller Spieler – neue Spieler tauchen automatisch auf.

Das Spiel schreibt seine Variablen beim Logout, beim Charakterwechsel und
bei /reload. Im Dauerbetrieb (Standard) prüft das Skript alle paar Sekunden,
ob sich die eigene Datei oder eine Datei im Syncthing-Ordner geändert hat.

Aufruf:
  python leuchtturm_sync.py            Dauerbetrieb (Fenster offen lassen)
  python leuchtturm_sync.py --einmal   einmal abgleichen und beenden
Einstellungen stehen in leuchtturm_sync.ini neben diesem Skript.

Kein Netzwerk, keine Fremdbibliotheken – nur Python 3.8+ und Syncthing.
"""

from __future__ import annotations

import argparse
import configparser
import os
import re
import sys
import time
from pathlib import Path

SKRIPT_ORDNER = Path(__file__).resolve().parent
INI_DATEI = SKRIPT_ORDNER / "leuchtturm_sync.ini"

ADDON = "Leuchtturm"
SV_DATEI = "Leuchtturm.lua"
INDEX_DATEI = "Index.lua"
STANDARD_SYNC = "Leuchtturm_Sync"   # Ordner neben dem Addon in Interface\AddOns


def melde(text: str) -> None:
    print(time.strftime("%H:%M:%S"), text, flush=True)


# ----------------------------------------------------------------------
# Einstellungen
# ----------------------------------------------------------------------

class Einstellungen:
    def __init__(self, wow: Path, konto: str, spieler: str, sync: Path, intervall: float):
        self.wow = wow
        self.konto = konto
        self.spieler = spieler
        self.sync = sync
        self.intervall = intervall

    @property
    def addon(self) -> Path:
        return self.wow / "Interface" / "AddOns" / ADDON

    @property
    def index(self) -> Path:
        return self.addon / INDEX_DATEI

    def sv_datei(self) -> Path | None:
        konten = self.wow / "WTF" / "Account"
        if self.konto:
            p = konten / self.konto / "SavedVariables" / SV_DATEI
            return p
        if not konten.is_dir():
            return None
        treffer = sorted(konten.glob("*/SavedVariables/" + SV_DATEI))
        if len(treffer) == 1:
            return treffer[0]
        if len(treffer) > 1:
            namen = ", ".join(t.parent.parent.name for t in treffer)
            raise SystemExit(f"Mehrere Konten gefunden ({namen}). Bitte 'konto' in {INI_DATEI.name} eintragen.")
        return None


def lade_einstellungen(argumente: argparse.Namespace) -> Einstellungen:
    ini = configparser.ConfigParser()
    if INI_DATEI.exists():
        ini.read(INI_DATEI, encoding="utf-8")
    abschnitt = ini["leuchtturm"] if ini.has_section("leuchtturm") else {}

    def wert(name: str, standard: str = "") -> str:
        aus_arg = getattr(argumente, name, None)
        if aus_arg:
            return str(aus_arg)
        return str(abschnitt.get(name, standard) or standard).strip()

    wow = wert("wow_ordner")
    if not wow:
        raise SystemExit(f"Bitte 'wow_ordner' in {INI_DATEI} eintragen (z. B. C:\\Program Files (x86)\\World of Warcraft\\_forever_).")
    wow_pfad = Path(wow)
    if not (wow_pfad / "Interface" / "AddOns").is_dir():
        raise SystemExit(f"Im WoW-Ordner fehlt Interface\\AddOns: {wow_pfad}")
    sync = wert("sync_ordner") or str(wow_pfad / "Interface" / "AddOns" / STANDARD_SYNC)
    return Einstellungen(
        wow=wow_pfad,
        konto=wert("konto"),
        spieler=wert("spieler"),
        sync=Path(sync),
        intervall=float(wert("intervall", "5") or 5),
    )


# ----------------------------------------------------------------------
# Hilfen
# ----------------------------------------------------------------------

UNGUELTIG = re.compile(r"[^\w\-äöüÄÖÜß]")


def dateiname_fuer(spieler: str) -> str:
    sauber = UNGUELTIG.sub("_", spieler.strip())
    if not sauber:
        raise SystemExit("Spielername ist leer.")
    return sauber + ".lua"


def spieler_aus_sv(inhalt: bytes) -> str | None:
    """Liest LeuchtturmDB.ich bzw. den einzigen Spieler aus der Variablen-Datei."""
    text = inhalt.decode("utf-8", errors="replace")
    m = re.search(r'\["ich"\]\s*=\s*"([^"]+)"', text)
    if m:
        return m.group(1)
    # Struktur: ["spieler"] = { ["Daniel"] = { ["charaktere"] = ...
    namen = re.findall(r'\[\s*"([^"]+)"\s*\]\s*=\s*\{\s*\[\s*"charaktere"\s*\]', text)
    namen = sorted(set(namen) - {"Unbekannt"})
    if len(namen) == 1:
        return namen[0]
    return None


def schreibe_atomar(ziel: Path, inhalt: bytes) -> bool:
    """Schreibt nur bei Änderung, über eine temporäre Datei. True = geschrieben."""
    if ziel.exists() and ziel.read_bytes() == inhalt:
        return False
    ziel.parent.mkdir(parents=True, exist_ok=True)
    tmp = ziel.with_name("." + ziel.name + ".tmp")
    tmp.write_bytes(inhalt)
    os.replace(tmp, ziel)
    return True


def ist_spielerdatei(p: Path) -> bool:
    n = p.name
    return (p.is_file() and n.endswith(".lua") and not n.startswith((".", "~"))
            and ".sync-conflict" not in n and "~syncthing~" not in n)


def lua_text(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lange_klammer(inhalt: bytes) -> tuple[bytes, bytes]:
    n = 1
    while b"]" + b"=" * n + b"]" in inhalt:
        n += 1
    return b"[" + b"=" * n + b"[", b"]" + b"=" * n + b"]"


# ----------------------------------------------------------------------
# Die zwei Aufgaben
# ----------------------------------------------------------------------

def kopiere_eigene(e: Einstellungen) -> bool:
    sv = e.sv_datei()
    if not sv or not sv.exists():
        return False
    # nicht mitten in einen Schreibvorgang des Spiels hineinlesen
    if time.time() - sv.stat().st_mtime < 1.0:
        return False
    inhalt = sv.read_bytes()
    if b"LeuchtturmDB" not in inhalt:
        melde(f"Warnung: {sv} enthält keine Leuchtturm-Daten – übersprungen.")
        return False
    spieler = e.spieler or spieler_aus_sv(inhalt)
    if not spieler:
        raise SystemExit(f"Spielername unbekannt. Bitte 'spieler' in {INI_DATEI.name} eintragen.")
    e.spieler = spieler
    ziel = e.sync / dateiname_fuer(spieler)
    if schreibe_atomar(ziel, inhalt):
        melde(f"Eigene Daten kopiert → {ziel}")
        return True
    return False


def erzeuge_index(e: Einstellungen) -> bool:
    dateien = sorted(p for p in e.sync.glob("*.lua") if ist_spielerdatei(p)) if e.sync.is_dir() else []
    teile = [
        b"-- Leuchtturm - Index der Spielerdateien\n",
        b"-- Erzeugt von Werkzeug/leuchtturm_sync.py. Nicht von Hand bearbeiten.\n",
        f"-- Quelle: {e.sync}\n".encode("utf-8"),
        b"LeuchtturmIndex = {\n",
        # erzeugt = neueste Spielerdatei, damit der Index nur bei echten Änderungen neu geschrieben wird
        f"  erzeugt = {int(max([p.stat().st_mtime for p in dateien] or [time.time()]))},\n".encode(),
        b"  dateien = {\n",
    ]
    for p in dateien:
        inhalt = p.read_bytes()
        auf, zu = lange_klammer(inhalt)
        spieler = p.stem
        teile += [
            f"    {{ spieler = {lua_text(spieler)}, datei = {lua_text(p.name)}, "
            f"geaendert = {int(p.stat().st_mtime)},\n      inhalt = ".encode("utf-8"),
            auf, b"\n", inhalt, b"\n", zu, b" },\n",
        ]
    teile += [b"  },\n}\n"]
    if not e.addon.is_dir():
        melde(f"Addon-Ordner fehlt: {e.addon}")
        return False
    if schreibe_atomar(e.index, b"".join(teile)):
        namen = ", ".join(p.stem for p in dateien) or "keine"
        melde(f"Index neu erzeugt ({len(dateien)} Spielerdatei(en): {namen}). Im Spiel: /ltm neu")
        return True
    return False


def abgleich(e: Einstellungen) -> None:
    e.sync.mkdir(parents=True, exist_ok=True)
    kopiere_eigene(e)
    erzeuge_index(e)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Leuchtturm-Datenabgleich per Syncthing")
    parser.add_argument("--einmal", action="store_true", help="einmal abgleichen und beenden")
    parser.add_argument("--wow_ordner", help="WoW-Ordner, z. B. ...\\World of Warcraft\\_forever_")
    parser.add_argument("--konto", help="Kontoordner unter WTF\\Account (leer = automatisch)")
    parser.add_argument("--spieler", help="eigener Spielername (z. B. Daniel)")
    parser.add_argument("--sync_ordner", help="Syncthing-Ordner (Standard: Interface\\AddOns\\Leuchtturm_Sync)")
    argumente = parser.parse_args(argv)

    e = lade_einstellungen(argumente)
    melde(f"Leuchtturm-Abgleich: WoW = {e.wow}, Syncthing-Ordner = {e.sync}")
    abgleich(e)
    if argumente.einmal:
        return 0
    melde(f"Läuft – prüft alle {e.intervall:g} s. Beenden mit Strg+C.")
    try:
        while True:
            time.sleep(e.intervall)
            try:
                abgleich(e)
            except OSError as fehler:  # z. B. Datei gerade gesperrt
                melde(f"Kurzer Fehler, nächster Versuch gleich: {fehler}")
    except KeyboardInterrupt:
        melde("Beendet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
