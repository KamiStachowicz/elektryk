# ============================================================
#  SAP TICKET ROUTER - auto pętla (READ-ONLY, lokalnie)
#  Przechodzi CALA liste ticketow, czyta i zapisuje decyzje do CSV.
#  NICZEGO NIE ZMIENIA w ticketach (nie przypisuje, nie zamyka).
#
#  Przed startem:
#   - otworz w Edge LISTE ticketow (widoczne "View Details")
#   - nie ruszaj myszki/klawiatury podczas dzialania
#   - ekran odblokowany
#  Stop: Ctrl+C w oknie skryptu.
# ============================================================

# ---------------- KONFIGURACJA ----------------
$NaszeSystemy   = @('P4M','P50','PGR','K4M','PGT','Q4M')
$WzorzecSystemu = '^B.P$'
$Zespol         = @()                     # osoby do rotacji (BEZ Ciebie)
$PlikRotacji    = "$env:USERPROFILE\sap_router_rotacja.txt"
$PlikLogu       = "$env:USERPROFILE\Documents\sap_router_log.csv"
$MaxTicketow    = 999                      # praktycznie: wszystkie
$CzasLadowania  = 2500                     # ms - az ticket sie otworzy
$CzasListy      = 1800                     # ms - az lista wroci
$Etykiety = @('#Application\s*Name\s*:+\s*([A-Za-z0-9]+)','\bSystem\s*:+\s*([A-Za-z0-9]+)')
# ----------------------------------------------

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win {
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public static void Click(int x,int y){ SetCursorPos(x,y); mouse_event(0x0002,0,0,0,0); mouse_event(0x0004,0,0,0,0); }
}
"@
$AE=[System.Windows.Automation.AutomationElement]
$TS=[System.Windows.Automation.TreeScope]
$TRUE1=[System.Windows.Automation.Condition]::TrueCondition

function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function Czy-Nasz($s){ if($NaszeSystemy -contains $s){return $true}; if($s -match $WzorzecSystemu){return $true}; return $false }
function Nastepna-Osoba{ if($Zespol.Count -eq 0){return '(uzupelnij Zespol)'}; $idx=0; if(Test-Path $PlikRotacji){try{$idx=[int](Get-Content $PlikRotacji -Raw)}catch{$idx=0}}; $o=$Zespol[$idx%$Zespol.Count]; Set-Content -Path $PlikRotacji -Value (($idx+1)%$Zespol.Count); return $o }

function Przetworz($txt){
  $system=$null
  foreach($e in $Etykiety){ if($txt -match $e){ $system=$Matches[1].ToUpper(); break } }
  if(-not $system){ foreach($m in [regex]::Matches($txt,'\b[A-Za-z0-9]{3}\b')){ $k=$m.Value.ToUpper(); if(Czy-Nasz $k){ $system=$k; break } } }
  if(-not $system){ $decyzja='DO_SPRAWDZENIA' } elseif(Czy-Nasz $system){ $decyzja='NASZE' } else { $decyzja='GSD' }
  $role=@(); foreach($m in [regex]::Matches($txt,'\bZ[A-Z0-9]+-[A-Z0-9_]+\b','IgnoreCase')){ $r=$m.Value.ToUpper(); if($role -notcontains $r){$role+=$r} }
  $userName=''; if($txt -match '#User\s*Full\s*Name\s*:+\s*([^\r\n]+)'){ $userName=$Matches[1].Trim() }
  $userId=''; if($txt -match '\b[EM]\d{7}\b'){ $userId=$Matches[0] }
  return [pscustomobject]@{ System=$system; Decyzja=$decyzja; Role=$role; UserName=$userName; UserId=$userId }
}

function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Get-ViewDetails($win){ $l=@(); foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if( ($nm -match 'wyswietl' -and $nm -match 'szczeg') -or ($nm -match 'view' -and $nm -match 'detail') ){ $l+=$e } }; return $l }
function Kopiuj-Strone($win){
  [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 300
  [System.Windows.Forms.SendKeys]::SendWait('{TAB}')       # focus na tresc, nie pasek
  Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait('^c'); Start-Sleep -Milliseconds 400
  return (Get-Clipboard -Raw)
}
function Wstecz($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('%{LEFT}') }
function Do-Widoku($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{} }

# --- Start ---
Clear-Host
Write-Host "SAP Ticket Router - AUTO (READ-ONLY)" -ForegroundColor Cyan
Write-Host ("Log: "+$PlikLogu) -ForegroundColor DarkGray
$win=Get-EdgeWindow
if(-not $win){ Write-Host "Nie znalazlem okna Edge." -ForegroundColor Red; return }
$vd=Get-ViewDetails $win
Write-Host ("Ticketow na liscie: "+$vd.Count) -ForegroundColor Green
if($vd.Count -eq 0){ Write-Host "Brak 'View Details'." -ForegroundColor Red; return }
$ile=[Math]::Min($vd.Count,$MaxTicketow)
Write-Host ("Przetworze: "+$ile) -ForegroundColor Yellow
Write-Host "Start za 5s - NIE RUSZAJ myszki..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$licz=@{ NASZE=0; GSD=0; DO_SPRAWDZENIA=0 }
$doReki=@()
$seen=@{}      # dedup: tresc juz przetworzonych ticketow

for($i=0; $i -lt $ile; $i++){
  $win=Get-EdgeWindow
  $vd=Get-ViewDetails $win
  # jesli lista jeszcze nie wrocila - poczekaj i sprobuj raz jeszcze
  if($vd.Count -eq 0){ Start-Sleep -Milliseconds 1200; $win=Get-EdgeWindow; $vd=Get-ViewDetails $win }
  if($i -ge $vd.Count){ Write-Host "Koniec listy."; break }

  $btn=$vd[$i]
  Do-Widoku $btn                       # przewin do widoku jesli ponizej ekranu
  Start-Sleep -Milliseconds 300
  $r=$btn.Current.BoundingRectangle
  if($r.Width -le 0){ Write-Host ("Ticket #"+($i+1)+": poza ekranem - pomijam"); continue }
  $x=[int]($r.X+$r.Width/2); $y=[int]($r.Y+$r.Height/2)

  Write-Host ("--- Ticket #"+($i+1)+"/"+$ile+" -> klikam") -ForegroundColor White
  [Win]::Click($x,$y)
  Start-Sleep -Milliseconds $CzasLadowania

  $win=Get-EdgeWindow
  $txt=Kopiuj-Strone $win
  $klucz=($txt -replace '\s+',' ').Trim()
  if($klucz -and $seen.ContainsKey($klucz)){
    Write-Host ("   (duplikat - juz przetworzony, pomijam)") -ForegroundColor DarkGray
    Wstecz $win; Start-Sleep -Milliseconds $CzasListy; continue
  }
  if($klucz){ $seen[$klucz]=1 }
  $w=Przetworz $txt
  $kol=switch($w.Decyzja){ 'NASZE'{'Green'} 'GSD'{'Yellow'} default{'Red'} }
  $osoba=if($w.Decyzja -eq 'NASZE'){ Nastepna-Osoba } else { '' }
  Write-Host ("   SYSTEM="+$w.System+"  DECYZJA="+$w.Decyzja+$(if($osoba){"  -> "+$osoba}else{''})) -ForegroundColor $kol
  if($w.Role.Count -gt 0){ Write-Host ("   ROLE: "+($w.Role -join ', ')) }

  $licz[$w.Decyzja]++
  if($w.Decyzja -eq 'DO_SPRAWDZENIA'){ $doReki += ("#"+($i+1)+" user="+$w.UserName) }

  [pscustomobject]@{ Czas=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); System=$w.System; Decyzja=$w.Decyzja; Osoba=$osoba; User=$w.UserName; UserId=$w.UserId; Role=($w.Role -join ';') } | Export-Csv -Path $PlikLogu -Append -NoTypeInformation -Encoding UTF8

  Wstecz $win
  Start-Sleep -Milliseconds $CzasListy
}

# --- Podsumowanie ---
Write-Host ""
Write-Host "=========== PODSUMOWANIE ===========" -ForegroundColor Cyan
Write-Host ("Przetworzone : "+($licz.NASZE + $licz.GSD + $licz.DO_SPRAWDZENIA))
Write-Host ("NASZE        : "+$licz.NASZE) -ForegroundColor Green
Write-Host ("GSD          : "+$licz.GSD) -ForegroundColor Yellow
Write-Host ("DO_SPRAWDZENIA: "+$licz.DO_SPRAWDZENIA) -ForegroundColor Red
if($doReki.Count -gt 0){ Write-Host "Do recznego sprawdzenia:"; $doReki | ForEach-Object { Write-Host ("  - "+$_) } }
Write-Host ("Log: "+$PlikLogu) -ForegroundColor DarkGray
Write-Host "====================================" -ForegroundColor Cyan
