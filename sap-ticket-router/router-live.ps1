# ============================================================
#  SAP TICKET ROUTER - asystent decyzji (czysty PowerShell)
#  Dziala LOKALNIE. Nic nie wysyla na zewnatrz. Nic nie klika.
#
#  Jak uzywac:
#    1. Odpal ten skrypt (w PowerShell ISE: F5, albo w konsoli).
#    2. Otworz ticket w SmartIT -> Ctrl+A -> Ctrl+C.
#    3. Skrypt od razu wypisze: system, decyzje, role, usera.
#    4. Ty wykonujesz akcje recznie. Stop: Ctrl+C w oknie skryptu.
# ============================================================

# ---------------- KONFIGURACJA ----------------
$NaszeSystemy   = @('P4M','P50','PGR','K4M','PGT','Q4M')
$WzorzecSystemu = '^B.P$'                 # zaczyna sie na B, konczy na P (BWP, B1P)
$Zespol         = @()                     # osoby do rotacji (BEZ Ciebie), np. @('login1','login2')
$PlikRotacji    = "$env:USERPROFILE\sap_router_rotacja.txt"
$PlikLogu       = "$env:USERPROFILE\Documents\sap_router_log.csv"
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

function Nastepna-Osoba {
    if ($Zespol.Count -eq 0) { return '(uzupelnij Zespol)' }
    $idx = 0
    if (Test-Path $PlikRotacji) { try { $idx = [int](Get-Content $PlikRotacji -Raw) } catch { $idx = 0 } }
    $osoba = $Zespol[$idx % $Zespol.Count]
    Set-Content -Path $PlikRotacji -Value (($idx + 1) % $Zespol.Count)
    return $osoba
}

function Przetworz($txt) {
    # system: etykiety
    $system = $null
    foreach ($e in $Etykiety) { if ($txt -match $e) { $system = $Matches[1].ToUpper(); break } }
    # fallback: nasz system gdziekolwiek w tekscie (obejmuje tytul)
    if (-not $system) {
        foreach ($m in [regex]::Matches($txt, '\b[A-Za-z0-9]{3}\b')) {
            $k = $m.Value.ToUpper(); if (Czy-Nasz $k) { $system = $k; break }
        }
    }
    # decyzja
    if (-not $system)          { $decyzja = 'DO_SPRAWDZENIA' }
    elseif (Czy-Nasz $system)  { $decyzja = 'NASZE' }
    else                       { $decyzja = 'GSD' }
    # role
    $role = @()
    foreach ($m in [regex]::Matches($txt, '\bZ[A-Z0-9]+-[A-Z0-9_]+\b', 'IgnoreCase')) {
        $r = $m.Value.ToUpper(); if ($role -notcontains $r) { $role += $r }
    }
    # user
    $userName = ''
    if ($txt -match '#User\s*Full\s*Name\s*:+\s*([^\r\n]+)') { $userName = $Matches[1].Trim() }
    $userId = ''
    if ($txt -match '\b[EM]\d{7}\b') { $userId = $Matches[0] }

    return [pscustomobject]@{
        System = $system; Decyzja = $decyzja; Role = $role
        UserName = $userName; UserId = $userId
    }
}

# --- Start ---
Clear-Host
Write-Host "SAP Ticket Router - asystent decyzji (lokalny)" -ForegroundColor Cyan
Write-Host "Skopiuj ticket (Ctrl+A, Ctrl+C). Stop: Ctrl+C tutaj." -ForegroundColor DarkGray
Write-Host ("Log: " + $PlikLogu) -ForegroundColor DarkGray
Write-Host ""

$ostatni = ""
while ($true) {
    Start-Sleep -Milliseconds 700
    $txt = Get-Clipboard -Raw
    if (-not $txt -or $txt -eq $ostatni) { continue }
    $ostatni = $txt

    $w = Przetworz $txt
    # pokaz tylko, jak to wyglada na ticket (jest system albo sa role)
    if (-not $w.System -and $w.Role.Count -eq 0) { continue }

    $kolor = switch ($w.Decyzja) { 'NASZE' {'Green'} 'GSD' {'Yellow'} default {'Red'} }
    $osoba = if ($w.Decyzja -eq 'NASZE') { Nastepna-Osoba } else { '' }

    Write-Host "================ TICKET ================" -ForegroundColor White
    Write-Host ("SYSTEM : " + $w.System)
    if ($w.Decyzja -eq 'NASZE') {
        Write-Host ("DECYZJA: NASZE  -> przypisz do: " + $osoba) -ForegroundColor $kolor
    } elseif ($w.Decyzja -eq 'GSD') {
        Write-Host "DECYZJA: GSD  -> Global Service Desk" -ForegroundColor $kolor
    } else {
        Write-Host "DECYZJA: DO_SPRAWDZENIA (brak systemu) - sprawdz recznie" -ForegroundColor $kolor
    }
    Write-Host ("USER   : " + $w.UserName + $(if ($w.UserId) { " (ID: $($w.UserId))" } else { " (ID: -)" }))
    if ($w.Role.Count -gt 0) {
        Write-Host "ROLE   :"
        foreach ($r in $w.Role) { Write-Host ("   - " + $r) }
    }
    Write-Host "=======================================" -ForegroundColor White
    Write-Host ""

    # log do CSV
    $wiersz = [pscustomobject]@{
        Czas   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        System = $w.System; Decyzja = $w.Decyzja; Osoba = $osoba
        User   = $w.UserName; UserId = $w.UserId; Role = ($w.Role -join ';')
    }
    $wiersz | Export-Csv -Path $PlikLogu -Append -NoTypeInformation -Encoding UTF8
}
