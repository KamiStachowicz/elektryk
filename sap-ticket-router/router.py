# -*- coding: utf-8 -*-
"""
Mozg bota do routingu ticketow (BMC Helix / SmartIT).

Co robi:
  1. Bierze OPIS ticketu (tekst).
  2. Wyluskuje nazwe systemu z linii "#Application name: ...".
  3. Sprawdza, czy to NASZ system (lista + wzorzec).
  4. Zwraca decyzje:
        - NASZE          -> przypisac do zespolu
        - GSD            -> przekazac na Global Service Desk
        - DO_SPRAWDZENIA -> nie znaleziono pola / niejasne, sprawdzic recznie

WAZNE: to jest sam "mozg" - dziala w 100% lokalnie, offline.
Nie laczy sie jeszcze z BMC. Najpierw sprawdzamy, czy dobrze klasyfikuje.
"""

import re

# =============================================================
#  KONFIGURACJA - to sie edytuje, gdy dochodzi nowy system
# =============================================================

# Systemy dopasowywane DOKLADNIE (1:1)
NASZE_SYSTEMY = {
    "P4M",
    "P50",
    "PGR",
    "K4M",
    "PGT",
    "Q4M",
}

# Reguly WZORCOWE (regex, na SID-ach 3-znakowych, po zamianie na wielkie litery).
# ^B.P$  =  zaczyna sie na B, konczy na P, jeden znak w srodku (np. BWP, B1P).
# Jak SID-y bywaja dluzsze, zmien na r"^B.*P$".
WZORCE = [
    r"^B.P$",
]

# =============================================================
#  LOGIKA
# =============================================================

def wyluskaj_system(opis: str):
    """Zwraca nazwe systemu z linii '#Application name:' albo None."""
    m = re.search(r"#Application\s*name:\s*([^\r\n]+)", opis, re.IGNORECASE)
    if not m:
        return None
    # bierzemy pierwszy "token" - system to zwykle jeden wyraz (SID)
    wartosc = m.group(1).strip()
    token = wartosc.split()[0] if wartosc else ""
    return token or None


def czy_nasz(system: str) -> bool:
    """True, jesli system jest na liscie ALBO pasuje do wzorca."""
    s = system.strip().upper()
    if s in NASZE_SYSTEMY:
        return True
    for wzor in WZORCE:
        if re.match(wzor, s):
            return True
    return False


def zdecyduj(opis: str) -> dict:
    """Zwraca decyzje routingu dla danego opisu ticketu."""
    system = wyluskaj_system(opis)

    if system is None:
        return {
            "system": None,
            "decyzja": "DO_SPRAWDZENIA",
            "powod": "Brak pola '#Application name:' w opisie",
        }

    if czy_nasz(system):
        return {
            "system": system,
            "decyzja": "NASZE",
            "powod": "System na naszej liscie / pasuje do wzorca -> przypisac do zespolu",
        }

    return {
        "system": system,
        "decyzja": "GSD",
        "powod": "System spoza naszej listy -> Global Service Desk",
    }


# =============================================================
#  DEMO / TEST - odpal:  python3 router.py
# =============================================================

if __name__ == "__main__":
    przyklady = [
        ("Nasz - z listy",        "Prosze o dostep.\n#Application name: P4M\nUser: xxxxx"),
        ("Nasz - wzorzec BxP",    "#Application name: BWP\nRola: Z_ROLE"),
        ("Nasz - wzorzec, male l.","opis... #application name: b1p ..."),
        ("Obcy -> GSD",           "#Application name: XYZ\nJakis inny system"),
        ("Obcy PGX -> GSD",       "#Application name: PGX"),
        ("Brak pola",             "Prosze o nadanie uprawnien dla uzytkownika."),
    ]

    print("=" * 60)
    for etykieta, opis in przyklady:
        wynik = zdecyduj(opis)
        print(f"[{etykieta}]")
        print(f"   system : {wynik['system']}")
        print(f"   decyzja: {wynik['decyzja']}")
        print(f"   powod  : {wynik['powod']}")
        print("-" * 60)
