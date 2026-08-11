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
import os
import json

# =============================================================
#  KONFIGURACJA - to sie edytuje, gdy dochodzi nowy system
# =============================================================

# Zespol do rotacji (BEZ Ciebie/Kamila - Ty nie wchodzisz do kolejki).
# Wpisz loginy/imiona jak beda. Kolejnosc = kolejnosc przydzielania.
ZESPOL = [
    # "osoba1",
    # "osoba2",
    # "osoba3",
]

# Plik, w ktorym bot pamieta, kto byl ostatni (zeby "po kolei" dzialalo
# miedzy uruchomieniami). Lezy obok skryptu.
PLIK_STANU = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rotacja_stan.json")

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

# Etykiety, po ktorych moze byc podany system (probowane po kolei).
# Jak znajdziesz kolejny format w ticketach - dopisz tutaj wzorzec.
ETYKIETY_SYSTEMU = [
    r"#Application\s*Name\s*:+\s*([^\r\n]+)",  # #Application Name::P50 - Europe...
    r"\bSystem\s*:+\s*([^\r\n]+)",             # System:P50  /  System: P50
]


def wyluskaj_system(opis: str):
    """Zwraca SID systemu z opisu albo None.

    Probuje po kolei znanych etykiet (patrz ETYKIETY_SYSTEMU), np:
        #Application Name::P50 - Europe Regional ERP System
        System:P50
    Z wartosci bierze sam kod (P50), pomijajac ' - opis'.
    """
    for wzor in ETYKIETY_SYSTEMU:
        m = re.search(wzor, opis, re.IGNORECASE)
        if not m:
            continue
        wartosc = m.group(1).strip()
        m2 = re.match(r"[A-Za-z0-9]+", wartosc)
        if m2:
            return m2.group(0)
    return None


def wyluskaj_role(opis: str) -> list:
    """Zwraca liste rol SAP z opisu ticketu.

    Role w Mahle maja postac np.: ZMM1164TA-MM_ANZEIGE, ZPP1164TP-DISPO_COCKP_OP_USER
    Wzorzec: Z + litery/cyfry + '-' + litery/cyfry/podkreslenia.
    Jak u Was role bywaja bez 'Z' na poczatku - popraw WZORZEC_ROLI.
    """
    WZORZEC_ROLI = r"\bZ[A-Z0-9]+-[A-Z0-9_]+\b"
    znalezione = re.findall(WZORZEC_ROLI, opis, re.IGNORECASE)
    # unikalne, zachowujac kolejnosc, wielkimi literami
    wynik = []
    for r in znalezione:
        rr = r.upper()
        if rr not in wynik:
            wynik.append(rr)
    return wynik


def wyluskaj_usera(opis: str) -> dict:
    """Zwraca dane usera z opisu: pelne imie i (jesli jest) ID typu E0148940 / M0177262."""
    imie = None
    m = re.search(r"#User\s*Full\s*Name\s*:+\s*([^\r\n]+)", opis, re.IGNORECASE)
    if m:
        imie = m.group(1).strip()

    user_id = None
    m2 = re.search(r"\b[EM]\d{7}\b", opis)  # E + 7 cyfr lub M + 7 cyfr
    if m2:
        user_id = m2.group(0)

    return {"imie": imie, "user_id": user_id}


def czy_nasz(system: str) -> bool:
    """True, jesli system jest na liscie ALBO pasuje do wzorca."""
    s = system.strip().upper()
    if s in NASZE_SYSTEMY:
        return True
    for wzor in WZORCE:
        if re.match(wzor, s):
            return True
    return False


def systemy_w_tekscie(tekst: str) -> list:
    """Szuka NASZYCH systemow w dowolnym tekscie (np. w tytule/Podsumowaniu).

    Bierze tylko 3-znakowe "slowa" (SID-y jak P4M, Q4M, BWP) i sprawdza,
    czy sa nasze. Granice slowa chronia przed falszywym trafieniem w srodku wyrazu.
    Zwraca liste unikalnych naszych SID-ow w kolejnosci wystapienia.
    """
    kandydaci = re.findall(r"\b[A-Za-z0-9]{3}\b", tekst)
    wynik = []
    for k in kandydaci:
        ku = k.upper()
        if czy_nasz(ku) and ku not in wynik:
            wynik.append(ku)
    return wynik


def nastepna_osoba() -> str:
    """Zwraca kolejna osobe z rotacji i zapisuje stan do pliku.

    Dziala po kolei miedzy uruchomieniami - pamieta ostatni indeks.
    Jak lista ZESPOL jest pusta, zwraca placeholder.
    """
    if not ZESPOL:
        return "(uzupelnij liste ZESPOL)"

    # wczytaj ostatni indeks
    idx = 0
    if os.path.exists(PLIK_STANU):
        try:
            with open(PLIK_STANU, "r", encoding="utf-8") as f:
                idx = json.load(f).get("nastepny", 0)
        except (json.JSONDecodeError, OSError):
            idx = 0

    osoba = ZESPOL[idx % len(ZESPOL)]

    # zapisz nastepny indeks
    try:
        with open(PLIK_STANU, "w", encoding="utf-8") as f:
            json.dump({"nastepny": (idx + 1) % len(ZESPOL)}, f)
    except OSError:
        pass

    return osoba


def zdecyduj(opis: str, tytul: str = "") -> dict:
    """Zwraca decyzje routingu dla ticketu.

    Priorytet 1: pole '#Application Name' z opisu.
    Priorytet 2: jesli w opisie nie ma pola - szukaj naszego systemu w tytule.
    """
    system = wyluskaj_system(opis)
    zrodlo = "opis (#Application Name)"

    # fallback: sprobuj z tytulu/Podsumowania
    if system is None and tytul:
        znalezione = systemy_w_tekscie(tytul)
        if znalezione:
            system = znalezione[0]
            zrodlo = "tytul (Podsumowanie)"

    if system is None:
        return {
            "system": None,
            "decyzja": "DO_SPRAWDZENIA",
            "przypisany": None,
            "powod": "Brak '#Application Name' w opisie i brak naszego systemu w tytule",
        }

    if czy_nasz(system):
        osoba = nastepna_osoba()
        return {
            "system": system,
            "decyzja": "NASZE",
            "przypisany": osoba,
            "powod": f"System nasz (zrodlo: {zrodlo}) -> przypisano do: {osoba}",
        }

    return {
        "system": system,
        "decyzja": "GSD",
        "przypisany": None,
        "powod": f"System spoza naszej listy (zrodlo: {zrodlo}) -> Global Service Desk",
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
        print(f"   system    : {wynik['system']}")
        print(f"   decyzja   : {wynik['decyzja']}")
        print(f"   przypisany: {wynik['przypisany']}")
        print(f"   powod     : {wynik['powod']}")
        print("-" * 60)

    # --- Demo rotacji (na przykladowej liscie, zeby pokazac 'po kolei') ---
    print("\nDEMO ROTACJI (przykladowa lista 3 osob):")
    ZESPOL[:] = ["anna", "bartek", "cezary"]
    if os.path.exists(PLIK_STANU):
        os.remove(PLIK_STANU)  # zeruj stan na potrzeby demo
    for n in range(1, 8):
        print(f"   ticket {n} -> {nastepna_osoba()}")
    os.remove(PLIK_STANU)  # sprzatanie po demie
