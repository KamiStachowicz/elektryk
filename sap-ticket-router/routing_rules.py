"""
Silnik routingu: typ zadania (z tresci) + system -> zespol.
Reguly sprawdzane po kolei; pierwsza pasujaca wygrywa.
Zrobione z tabeli "kto co robi". ZWERYFIKUJ reguly oznaczone # ?
"""
import re

# znane systemy (SID) - do wykrycia z tresci
ZNANE_SYSTEMY = [
    "BKP", "BEP", "BWP", "BGP", "B4P", "P50", "P4M", "K4M", "Q4M", "IAP",
    "PFI", "SM1", "PHE", "PHR", "HRP", "SF", "ESS",
    "PPH", "DPH", "QPH", "KPH", "SAC", "MAQ-IS", "MAQ", "PGR", "PGT",
]

# Regula: (nazwa, task_regex|None, systemy[]|None, bez_systemow[]|None, zespol)
#  - task_regex None  -> pasuje niezaleznie od tresci
#  - systemy   None  -> pasuje dla kazdego systemu
#  - systemy   [..]  -> musi wystapic KTORYS z tych systemow
#  - bez_systemow[..]-> zaden z tych systemow nie moze wystapic
REGULY = [
    # --- zadania niezalezne od systemu (najbardziej jednoznaczne) ---
    ("RF profile",     r"rf profile|zebra",                                   None, None, "SHOPFLOOR-WAREHOUSE+INTRALOG"),
    ("Folder",         r"folder access|delete folder|folder",                 None, None, "TOOLS-ORCHESTRATION"),
    ("Fiori",          r"fiori",                                              None, None, "APPL-INTEGRATION-SAP-CROSS-APPL"),
    ("GRC problem",    r"\bgrc\b|cannot find roles|can.?t find roles|nie widac rol", None, None, "APPL-INTEGRATION-SAP-CROSS-APPL"),
    ("Omada",          r"omada",                                              None, None, "IDENTITY-TOOLS"),
    ("Shopfloor",      r"shopfloor",                                          None, None, "GLOBAL-SERVICEDESK"),
    ("AD group",       r"ad group|add user to ad|dest-lg-ro",                 None, None, "GLOBAL-SERVICEDESK"),
    ("Lock/Unlock",    r"locking|unlock|password reset|extend validity|lock account", None, None, "GLOBAL-SERVICEDESK"),
    ("Approver (!P50)",r"approver",                                           None, ["P50"], "APPL-INTEGRATION-SAP-CROSS-APPL"),  # ? approver P50 -> gdzie?

    # --- account creation zaleznie od systemu ---
    ("AcctCreate -> GSD", r"account creation|create account|new account|new user|zalozenie konta|utworzenie konta|konto",
        ["PHE","ESS","BWP","BGP","B4P","P50","P4M","K4M","Q4M","IAP"], None, "GLOBAL-SERVICEDESK"),
    ("AcctCreate -> IDT", r"account creation|create account|zalozenie konta|konto",
        ["SM1","PFI"], None, "IDENTITY-TOOLS"),

    # --- role / usuwanie / P50 issues ---
    ("Removing roles P50", r"removing roles|remove role|usuniecie roli|usun",  ["P50"], None, "GLOBAL-SERVICEDESK"),
    ("Role assign SM1",    r"role assignment|assign.*role|assign.*transaction|transactions to roles", ["SM1"], None, "APPL-INTEGRATION-SAP-CROSS-APPL"),
    ("P50 issues",         r"issue|error|not working|problem|cannot|blad|nie dziala", ["P50"], None, "APPL-INTEGRATION-SAP-CROSS-APPL"),

    # --- fallbacki po samym systemie (gdy typ zadania niejasny) ---
    ("BKP",          None, ["BKP"], None, "BACKEND-SAP-BASIS"),
    ("BEP",          None, ["BEP"], None, "ENGINEERING-WEB-APPL"),
    ("Reporting",    None, ["BWP","BGP","B4P","SAC","MAQ-IS","MAQ"], None, "ENTERPRISE-REPORTING"),
    ("HCM",          None, ["PHE","PHR","HRP","SF","ESS"], None, "WORKFORCE-HCM-OPERATIONS"),
    ("SupplyChain",  None, ["PPH","DPH","QPH","KPH"], None, "SUPPLY-CHAIN-OPERATIONS"),
    ("Identity",     None, ["SM1","PFI"], None, "IDENTITY-TOOLS"),
    ("P50 fallback", None, ["P50"], None, "APPL-INTEGRATION-SAP-CROSS-APPL"),  # ? gdy nic wyzej nie zlapie
]


def wykryj_systemy(txt):
    up = txt.upper()
    found = set()
    for s in ZNANE_SYSTEMY:
        if re.search(r"\b" + re.escape(s) + r"\b", up):
            found.add(s)
    return found


def zespol_dla(txt):
    """Zwraca (zespol, nazwa_reguly, systemy) albo (None, None, systemy) gdy brak."""
    low = txt.lower()
    systemy = wykryj_systemy(txt)
    for nazwa, task, sysy, bez, team in REGULY:
        if task is not None and not re.search(task, low, re.IGNORECASE):
            continue
        if sysy is not None and not (systemy & set(sysy)):
            continue
        if bez is not None and (systemy & set(bez)):
            continue
        return team, nazwa, systemy
    return None, None, systemy


if __name__ == "__main__":
    testy = [
        ("Account creation P50", "Prosze o zalozenie konta w P50 dla usera"),
        ("P50 issue", "P50 error - transaction not working"),
        ("Shopfloor", "Shopfloor device account creation"),
        ("RF profile", "ZEBRA device not working, add user to RF profile"),
        ("Folder", "Folder access bulk request"),
        ("BWP acct", "Account creation BWP"),
        ("BWP auth", "BWP authorization for reporting"),
        ("Fiori", "Fiori tile missing P50"),
        ("Approver P50", "Change approver for P50"),
        ("Approver BWP", "Assign approver for BWP"),
        ("HRP", "HRP access issue"),
        ("PPH", "PPH role"),
        ("BKP", "BKP something"),
        ("Nieznane", "Losowy tekst bez systemu"),
    ]
    for nazwa, t in testy:
        team, regula, sysy = zespol_dla(t)
        print(f"{nazwa:16} -> {team or 'DO_SPRAWDZENIA':32} [regula: {regula}] sys={sorted(sysy)}")
