# ============================================================
#  SAP TICKET ROUTER - auto pętla (READ-ONLY, lokalnie)
#  Rozroznia wiersze po tresci (ID/klient/data) - klika tylko
#  jeszcze nie zrobione, przewija liste w dol po kolejne.
#  NICZEGO NIE ZMIENIA w ticketach.
# ============================================================

# ---------------- KONFIGURACJA ----------------
$NaszeSystemy   = @('P4M','P50','PGR','K4M','PGT','Q4M')
$WzorzecSystemu = '^B.P$'
$Zespol         = @()
$PlikRotacji    = "$env:USERPROFILE\sap_router_rotacja.txt"
$PlikLogu       = "$env:USERPROFILE\Documents\sap_router_log.csv"
$MaxTicketow    = 300
$CzasLadowania  = 2500
$CzasListy      = 1800
$Etykiety = @('#Application\s*Name\s*:+\s*([A-Za-z0-9]+)','\bSystem\s*:+\s*([A-Za-z0-9]+)')
# ----------------------------------------------

Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win {
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public static void Click(int x,int y){ SetCursorPos(x,y); mouse_event(0x0002,0,0,0,0); mouse_event(0x0004,0,0,0,0); }
 public static void Wheel(int x,int y,int delta){ SetCursorPos(x,y); mouse_event(0x0800,0,0,(uint)delta,0); }
}
"@
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
$WALK=[System.Windows.Automation.TreeWalker]::ControlViewWalker

function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function Czy-Nasz($s){ if($NaszeSystemy -contains $s){return $true}; if($s -match $WzorzecSystemu){return $true}; return $false }
function Nastepna-Osoba{ if($Zespol.Count -eq 0){return '(uzupelnij Zespol)'}; $idx=0; if(Test-Path $PlikRotacji){try{$idx=[int](Get-Content $PlikRotacji -Raw)}catch{$idx=0}}; $o=$Zespol[$idx%$Zespol.Count]; Set-Content -Path $PlikRotacji -Value (($idx+1)%$Zespol.Count); return $o }

function Przetworz($txt){
 $system=$null; foreach($e in $Etykiety){ if($txt -match $e){ $system=$Matches[1].ToUpper(); break } }
 if(-not $system){ foreach($m in [regex]::Matches($txt,'\b[A-Za-z0-9]{3}\b')){ $k=$m.Value.ToUpper(); if(Czy-Nasz $k){ $system=$k; break } } }
 if(-not $system){ $decyzja='DO_SPRAWDZENIA' } elseif(Czy-Nasz $system){ $decyzja='NASZE' } else { $decyzja='GSD' }
 $role=@(); foreach($m in [regex]::Matches($txt,'\bZ[A-Z0-9]+-[A-Z0-9_]+\b','IgnoreCase')){ $r=$m.Value.ToUpper(); if($role -notcontains $r){$role+=$r} }
 $userName=''; if($txt -match '#User\s*Full\s*Name\s*:+\s*([^\r\n]+)'){ $userName=$Matches[1].Trim() }
 $userId=''; if($txt -match '\b[EM]\d{7}\b'){ $userId=$Matches[0] }
 return [pscustomobject]@{ System=$system; Decyzja=$decyzja; Role=$role; UserName=$userName; UserId=$userId } }

function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Get-ViewDetails($win){ $l=@(); foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if( ($nm -match 'wyswietl' -and $nm -match 'szczeg') -or ($nm -match 'view' -and $nm -match 'detail') ){ $l+=$e } }; return $l }

# klucz wiersza: idzie w gore do wiersza i skleja jego teksty (ID/klient/data)
function Get-RowKey($btn){
  $node=$btn
  for($k=0;$k -lt 8;$k++){
    $p=$WALK.GetParent($node); if(-not $p){ break }; $node=$p
    $rr=$node.Current.BoundingRectangle
    if($rr.Width -ge 400 -and $rr.Height -le 140){ break }   # to jest wiersz
  }
  $t=''
  foreach($d in $node.FindAll($TS::Descendants,$TRUE1)){ $nm=$d.Current.Name; if($nm){ $t+=$nm+'|' } }
  return ($t -replace '\s+',' ').Trim()
}

function Kopiuj-Strone($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 300; [System.Windows.Forms.SendKeys]::SendWait('{TAB}'); Start-Sleep -Milliseconds 250; [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('^c'); Start-Sleep -Milliseconds 400; return (Get-Clipboard -Raw) }
function Wstecz($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('%{LEFT}') }
function Do-Widoku($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{} }
function Przewin-Dol($vd){ if($vd.Count -gt 0){ $r=$vd[$vd.Count-1].Current.BoundingRectangle; [Win]::Wheel([int]($r.X+$r.Width/2),[int]($r.Y),-700) } }

# --- Start ---
Clear-Host
Write-Host "SAP Ticket Router - AUTO (READ-ONLY)" -ForegroundColor Cyan
$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem okna Edge." -ForegroundColor Red; return }
$vd=Get-ViewDetails $win; Write-Host ("Widocznych ticketow na starcie: "+$vd.Count) -ForegroundColor Green
if($vd.Count -eq 0){ Write-Host "Brak 'View Details'." -ForegroundColor Red; return }
for($c=6;$c -ge 1;$c--){ Write-Host ("Start za "+$c+"s - zostaw myszke w spokoju...") -ForegroundColor Yellow; Start-Sleep -Seconds 1 }

$licz=@{ NASZE=0; GSD=0; DO_SPRAWDZENIA=0 }; $doReki=@(); $seen=@{}; $stall=0; $nr=0; $wyniki=@()

while($stall -lt 4 -and $seen.Count -lt $MaxTicketow){
  $win=Get-EdgeWindow; $vd=Get-ViewDetails $win
  if($vd.Count -eq 0){ Start-Sleep -Milliseconds 1200; $stall++; continue }

  # znajdz pierwszy wiersz jeszcze nie zrobiony
  $target=$null; $tkey=$null
  foreach($btn in $vd){ $key=Get-RowKey $btn; if($key -and -not $seen.ContainsKey($key)){ $target=$btn; $tkey=$key; break } }

  if(-not $target){ Write-Host "Wszystkie widoczne zrobione - przewijam w dol..." -ForegroundColor DarkGray; Przewin-Dol $vd; Start-Sleep -Milliseconds 900; $stall++; continue }

  $seen[$tkey]=1; $stall=0; $nr++
  Do-Widoku $target; Start-Sleep -Milliseconds 300
  $r=$target.Current.BoundingRectangle; if($r.Width -le 0){ continue }
  $x=[int]($r.X+$r.Width/2); $y=[int]($r.Y+$r.Height/2)
  Write-Host ("--- Ticket #"+$nr+" -> klikam") -ForegroundColor White
  [Win]::Click($x,$y); Start-Sleep -Milliseconds $CzasLadowania

  $win=Get-EdgeWindow; $txt=Kopiuj-Strone $win; $w=Przetworz $txt
  $kol=switch($w.Decyzja){ 'NASZE'{'Green'} 'GSD'{'Yellow'} default{'Red'} }; $osoba=if($w.Decyzja -eq 'NASZE'){ Nastepna-Osoba } else { '' }
  Write-Host ("   SYSTEM="+$w.System+"  DECYZJA="+$w.Decyzja+$(if($osoba){"  -> "+$osoba}else{''})) -ForegroundColor $kol
  if($w.Role.Count -gt 0){ Write-Host ("   ROLE: "+($w.Role -join ', ')) }
  $licz[$w.Decyzja]++; if($w.Decyzja -eq 'DO_SPRAWDZENIA'){ $doReki += ("#"+$nr+" user="+$w.UserName) }
  $wyniki += [pscustomobject]@{ Czas=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); System=$w.System; Decyzja=$w.Decyzja; Osoba=$osoba; User=$w.UserName; UserId=$w.UserId; Role=($w.Role -join ';') }

  Wstecz $win; Start-Sleep -Milliseconds $CzasListy
}

Write-Host ""; Write-Host "=========== PODSUMOWANIE ===========" -ForegroundColor Cyan
Write-Host ("Przetworzone : "+($licz.NASZE+$licz.GSD+$licz.DO_SPRAWDZENIA))
Write-Host ("NASZE        : "+$licz.NASZE) -ForegroundColor Green
Write-Host ("GSD          : "+$licz.GSD) -ForegroundColor Yellow
Write-Host ("DO_SPRAWDZENIA: "+$licz.DO_SPRAWDZENIA) -ForegroundColor Red
if($doReki.Count -gt 0){ Write-Host "Do recznego sprawdzenia:"; $doReki | ForEach-Object { Write-Host ("  - "+$_) } }
if($wyniki.Count -gt 0){ $wyniki | Export-Csv -Path $PlikLogu -NoTypeInformation -Encoding UTF8 }
Write-Host ("Log: "+$PlikLogu) -ForegroundColor DarkGray; Write-Host "====================================" -ForegroundColor Cyan
