# Bot routingu ticketów w Power Automate Desktop (BMC Helix SmartIT)

Instrukcja budowy bota **bez kodu**, w Power Automate Desktop (PAD).
Logika „mózgu" jest przepisana z pliku `router.py` (nasz wzorzec) na klocki PAD.

> **Zasada bezpieczeństwa:** budujemy w 2 etapach.
> - **ETAP 1 – tylko czytaj:** bot przechodzi tickety i wypisuje decyzję. NIC nie przypina.
> - **ETAP 2 – działanie:** dopiero gdy Etap 1 decyduje dobrze, dokładamy przypisywanie / przekazanie na GSD.

---

## Reguły (nasz „mózg")

- **Nasze systemy (dokładnie):** `P4M`, `P50`, `PGR`, `K4M`, `PGT`, `Q4M`
- **Nasze systemy (wzorzec):** kod zaczyna się na **B** i kończy na **P** (np. `BWP`, `B1P`)
- System czytamy z opisu ticketu, z linii: `#Application Name::P50 - Europe Regional ERP System`
  - separator to **podwójny dwukropek** `::`
  - bierzemy sam kod: `P50` (bez „ - Europe...")

Decyzja:
- kod na liście LUB pasuje do wzorca **B..P** → **NASZE** (przypisz do osoby)
- inaczej → **GSD** (Global Service Desk)
- brak pola `#Application Name` → **DO_SPRAWDZENIA** (ręcznie)

---

# ETAP 1 — wersja „tylko czytaj"

## Podprzepływ „MOZG" (decyzja z opisu)

Zrób **Podprzepływ** (Subflow) o nazwie `Mozg`. Wejście: zmienna `%Opis%` (tekst opisu ticketu).

### Krok 1 — wyłuskaj wartość Application Name
Akcja **Przytnij tekst** (Crop text):
- Tekst: `%Opis%`
- Operacja: *Pobierz tekst po* (get text after)
- Flaga: `#Application Name::`
- Wynik: `%PoFladze%`

> Jeśli w Waszych ticketach bywa pojedynczy `:` — zrób dwa warianty flagi albo użyj akcji
> **Analizuj tekst** (Parse text) z wyrażeniem regularnym: `#Application\s*Name\s*:+\s*`.

### Krok 2 — utnij do końca linii
Akcja **Podziel tekst** (Split text):
- Tekst: `%PoFladze%`
- Ogranicznik: **Nowy wiersz** (New line)
- Wynik: lista `%Linie%`
- Weź pierwszy element: `%Linie[0]%` → to np. `P50 - Europe Regional ERP System`

### Krok 3 — wyciągnij sam SID (pierwszy wyraz)
Akcja **Przytnij tekst**:
- Tekst: `%Linie[0]%`
- Operacja: *Pobierz tekst przed* (get text before)
- Flaga: ` ` (spacja)
- Wynik: `%SID%`  → `P50`
- (jeśli brak spacji, użyj całości `%Linie[0]%`)

Akcja **Przytnij/oczyść**: **Przytnij tekst** (Trim) → usuń spacje.
Akcja **Zmień wielkość liter** (Change text case) → **WIELKIE** → `%SID%` = `P50`.

### Krok 4 — sprawdź, czy to nasz system
Ustaw zmienną `%Nasz%` = `False`.

**Lista dokładnych systemów.** Akcja **Ustaw zmienną**:
- `%NaszeSystemy%` = utwórz listę: `P4M`, `P50`, `PGR`, `K4M`, `PGT`, `Q4M`
  (albo: akcja **Pętla dla każdego** po elementach; najprościej dodać je akcją *Dodaj element do listy*)

**Pętla dla każdego** (For each) `%Element%` w `%NaszeSystemy%`:
- **Jeżeli** `%Element%` = `%SID%` (bez uwzgl. wielkości liter):
  - Ustaw `%Nasz%` = `True`

**Wzorzec B..P.** Akcja **Jeżeli tekst** (If text):
- warunek: `%SID%` *zaczyna się od* `B`  **ORAZ**  `%SID%` *kończy się na* `P`
  - (dwa zagnieżdżone „Jeżeli" albo warunek złożony)
  - jeśli tak → Ustaw `%Nasz%` = `True`

### Krok 5 — ustaw decyzję
- **Jeżeli** `%SID%` jest puste → `%Decyzja%` = `DO_SPRAWDZENIA`
- w innym razie **Jeżeli** `%Nasz%` = `True` → `%Decyzja%` = `NASZE`
- inaczej → `%Decyzja%` = `GSD`

Koniec podprzepływu. Zwraca `%Decyzja%` i `%SID%`.

---

## Główny przepływ (Etap 1)

1. **Uruchom przeglądarkę** — użyj akcji *Dołącz do działającej przeglądarki* (Attach to running
   browser), żeby korzystać z sesji, w której jesteś już zalogowany (SSO/CyberArk).
2. Przejdź na **Konsolę zgłoszeń** (lista ticketów), filtr „Wszystko otwarte / Przypisane do".
3. **Pobierz listę ticketów** — akcja *Wyodrębnij dane z okna/strony* (Extract data from web page):
   złap wiersze tabeli (Podsumowanie + link „Wyświetl szczegóły"). Wynik: tabela `%Tickety%`.
4. **Pętla dla każdego** wiersza `%T%` w `%Tickety%`:
   1. Kliknij **„Wyświetl szczegóły"** dla tego wiersza (akcja *Kliknij łącze/element na stronie*).
   2. **Pobierz tekst opisu** — akcja *Pobierz szczegóły elementu na stronie* → pole „Opis”
      do zmiennej `%Opis%`.
   3. **Wywołaj podprzepływ `Mozg`** (przekaż `%Opis%`).
   4. **Zapisz wynik do pliku** (na razie zamiast działania): akcja *Zapisz tekst do pliku*
      dopisz linię: `%T Id% ; %SID% ; %Decyzja%` do `wyniki.csv`.
   5. Wróć do listy (Wstecz / ponowne wejście na konsolę).
5. Otwórz `wyniki.csv` i **sprawdź ręcznie**, czy decyzje się zgadzają.

> Na tym etapie bot NICZEGO nie zmienia w ticketach — tylko produkuje plik z decyzjami.
> To jest bezpieczny test „mózgu + oczu" na prawdziwych danych.

---

# ETAP 2 — dołóż działanie (dopiero po weryfikacji Etapu 1)

W pętli, zamiast (lub obok) zapisu do pliku:

- **Jeżeli** `%Decyzja%` = `NASZE`:
  - wyznacz osobę rotacyjnie (patrz niżej `Rotacja`)
  - w tickecie ustaw **Przypisano do** = ta osoba (nagraj klikanie pola „Przypisano do")
- **Jeżeli** `%Decyzja%` = `GSD`:
  - zmień **Grupę przypisanych** na `GLOBAL-SERVICE-...` (nagraj klikanie)
- **Jeżeli** `%Decyzja%` = `DO_SPRAWDZENIA`:
  - zostaw bez zmian (ewentualnie oznacz w pliku do ręcznego przejrzenia)

## Rotacja osób (round-robin, jak w router.py)

Osoby do rotacji (BEZ Ciebie) trzymaj w liście `%Zespol%` = `osoba1, osoba2, ...`.
Stan „kto następny" trzymamy w pliku `rotacja.txt` (żeby działało między uruchomieniami):

1. **Odczytaj z pliku** `rotacja.txt` → `%Idx%` (jeśli brak pliku, `%Idx%` = 0).
2. `%Osoba%` = `%Zespol[Idx MOD LiczbaOsob]%`
3. Zapisz do `rotacja.txt` nową wartość: `(Idx + 1) MOD LiczbaOsob`.

---

## Uruchamianie

- **Ręcznie:** odpalasz przepływ jednym kliknięciem, gdy chcesz przerobić kolejkę.
- **Cyklicznie:** w Power Automate (chmura) można ustawić harmonogram, który odpala przepływ
  desktopowy co X minut — ale to później, jak Etap 2 będzie sprawdzony.

## Uwagi

- Selektory elementów strony (przyciski, pola) **nagrywasz u siebie** — u każdego SmartIT
  wygląda tak samo, ale PAD musi je „zobaczyć" na Twoim ekranie podczas budowy.
- Zaczynaj od **1–2 ticketów** (mały filtr), nie od całej kolejki.
- Trzymaj Etap 1 (plik z decyzjami) nawet po włączeniu Etapu 2 — to Twój log i kontrola.
