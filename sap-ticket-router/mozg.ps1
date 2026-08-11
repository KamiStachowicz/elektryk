# ============================================================
#  MOZG bota - PowerShell (wersja do Power Automate Desktop)
#  Czyta tekst ze SCHOWKA (Ctrl+A -> Ctrl+C na tickecie w Edge)
#  i zwraca: system, decyzje (NASZE/GSD/DO_SPRAWDZENIA), role, usera.
#  Ta sama logika co router.py.
# ============================================================

# ---------------- KONFIGURACJA ----------------
$NaszeSystemy   = @('P4M','P50','PGR','K4M','PGT','Q4M')
$WzorzecSystemu = '^B.P$'          # zaczyna sie na B, konczy na P (np. BWP, B1P)
$Zespol         = @()              # osoby do rotacji (BEZ Ciebie) - uzupelnij np. @('login1','login2')
$PlikRotacji    = "$env:USERPROFILE\sap_router_rotacja.txt"

# Etykiety, po ktorych moze byc podany system (probowane po kolei)
$Etykiety = @(
    '#Application\s*Name\s*:+\s*([A-Za-z0-9]+)',
    '\bSystem\s*:+\s*([A-Za-z0-9]+)'
)
# ----------------------------------------------

function Czy-Nasz($s) {
    if ($NaszeSystemy -contains $s) { return $true }
    if ($s -match $WzorzecSystemu)  { return $true }
    return $false
}

# --- 1. Pobierz tekst ze schowka ---
$txt = Get-Clipboard -Raw
if (-not $txt) { $txt = "" }

# --- 2. Wyluskaj system (najpierw etykiety) ---
$system = $null
foreach ($e in $Etykiety) {
    if ($txt -match $e) { $system = $Matches[1].ToUpper(); break }
}

# --- 3. Fallback: szukaj naszego systemu w calym tekscie (obejmuje tytul) ---
if (-not $system) {
    foreach ($m in [regex]::Matches($txt, '\b[A-Za-z0-9]{3}\b')) {
        $k = $m.Value.ToUpper()
        if (Czy-Nasz $k) { $system = $k; break }
    }
}

# --- 4. Decyzja ---
if (-not $system) {
    $decyzja = 'DO_SPRAWDZENIA'
} elseif (Czy-Nasz $system) {
    $decyzja = 'NASZE'
} else {
    $decyzja = 'GSD'
}

# --- 5. Role SAP (np. ZMM1164TA-MM_ANZEIGE) ---
$role = @()
foreach ($m in [regex]::Matches($txt, '\bZ[A-Z0-9]+-[A-Z0-9_]+\b', 'IgnoreCase')) {
    $r = $m.Value.ToUpper()
    if ($role -notcontains $r) { $role += $r }
}

# --- 6. User (imie + ewentualne ID typu E0148940 / M0177262) ---
$userName = ''
if ($txt -match '#User\s*Full\s*Name\s*:+\s*([^\r\n]+)') { $userName = $Matches[1].Trim() }
$userId = ''
if ($txt -match '\b[EM]\d{7}\b') { $userId = $Matches[0] }

# --- 7. Rotacja osoby (tylko gdy NASZE) ---
$osoba = ''
if ($decyzja -eq 'NASZE') {
    if ($Zespol.Count -gt 0) {
        $idx = 0
        if (Test-Path $PlikRotacji) {
            try { $idx = [int](Get-Content $PlikRotacji -Raw) } catch { $idx = 0 }
        }
        $osoba = $Zespol[$idx % $Zespol.Count]
        Set-Content -Path $PlikRotacji -Value (($idx + 1) % $Zespol.Count)
    } else {
        $osoba = '(uzupelnij Zespol)'
    }
}

# --- 8. Wynik (PAD odczyta to jako tekst) ---
Write-Output "SYSTEM=$system"
Write-Output "DECYZJA=$decyzja"
Write-Output ("ROLE=" + ($role -join ';'))
Write-Output "USER_NAME=$userName"
Write-Output "USER_ID=$userId"
Write-Output "OSOBA=$osoba"
