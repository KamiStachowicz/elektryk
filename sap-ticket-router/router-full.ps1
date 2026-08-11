# ============================================================
#  SAP TICKET ROUTER - PELNY (czytanie + routing do zespolu)
#  - przechodzi tickety, czyta, wykrywa system
#  - ustala ZESPOL wg mapy (system -> team); shopfloor -> GSD
#  - Edit -> pole grupy -> wpisuje ZESPOL -> STOP (Ty zapisujesz)
#  - nieznany system -> DO_SPRAWDZENIA (tylko log)
#  NIC nie zapisuje samo.
# ============================================================

# ---------------- MAPA ROUTINGU (ZWERYFIKUJ!) ----------------
# system (SID) -> zespol. Zrobione z Twojej tabeli "kto co robi".
# UWAGA: niektore zalezą od typu zadania - popraw wg potrzeb.
$RoutingTeams = @{
  'BKP' = 'BACKEND-SAP-BASIS'
  'BEP' = 'ENGINEERING-WEB-APPL'
  'BWP' = 'ENTERPRISE-REPORTING'
  'BGP' = 'ENTERPRISE-REPORTING'
  'B4P' = 'ENTERPRISE-REPORTING'
  'P50' = 'APPL-INTEGRATION-SAP-CROSS-APPL'
  'P4M' = 'GLOBAL-SERVICEDESK'
  'K4M' = 'GLOBAL-SERVICEDESK'
  'Q4M' = 'GLOBAL-SERVICEDESK'
  'IAP' = 'GLOBAL-SERVICEDESK'
  'PFI' = 'IDENTITY-TOOLS'
  'SM1' = 'IDENTITY-TOOLS'
  'PHE' = 'WORKFORCE-HCM-OPERATIONS'
  'PHR' = 'WORKFORCE-HCM-OPERATIONS'
  'HRP' = 'WORKFORCE-HCM-OPERATIONS'
  'SF'  = 'WORKFORCE-HCM-OPERATIONS'
  'ESS' = 'WORKFORCE-HCM-OPERATIONS'
  'PPH' = 'SUPPLY-CHAIN-OPERATIONS'
  'DPH' = 'SUPPLY-CHAIN-OPERATIONS'
  'QPH' = 'SUPPLY-CHAIN-OPERATIONS'
  'KPH' = 'SUPPLY-CHAIN-OPERATIONS'
  'SAC' = 'ENTERPRISE-REPORTING'
}
$GSD_TEAM = 'GLOBAL-SERVICEDESK'   # dla shopfloor
# ------------------------------------------------------------

$OBECNA         = "TOOLS-ACCESS-MANAGEMENT"   # obecna grupa (do namierzenia pola)
$PlikLogu       = "$env:USERPROFILE\Documents\sap_router_log.csv"
$MaxTicketow    = 50
$CzasLadowania  = 2500
$CzasListy      = 1800
$Etykiety = @('#Application\s*Name\s*:+\s*([A-Za-z0-9]+)','\bSystem\s*:+\s*([A-Za-z0-9]+)')

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
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }

function Przetworz($txt){
 $system=$null; foreach($e in $Etykiety){ if($txt -match $e){ $system=$Matches[1].ToUpper(); break } }
 if(-not $system){ foreach($m in [regex]::Matches($txt,'\b[A-Za-z0-9]{3}\b')){ $k=$m.Value.ToUpper(); if($RoutingTeams.ContainsKey($k)){ $system=$k; break } } }
 # ustal zespol
 $team=''
 if($txt -match 'shopfloor'){ $team=$GSD_TEAM; if(-not $system){ $system='SHOPFLOOR' } }
 elseif($system -and $RoutingTeams.ContainsKey($system)){ $team=$RoutingTeams[$system] }
 $role=@(); foreach($m in [regex]::Matches($txt,'\bZ[A-Z0-9]+-[A-Z0-9_]+\b','IgnoreCase')){ $r=$m.Value.ToUpper(); if($role -notcontains $r){$role+=$r} }
 $userName=''; if($txt -match '#User\s*Full\s*Name\s*:+\s*([^\r\n]+)'){ $userName=$Matches[1].Trim() }
 $userId=''; if($txt -match '\b[EM]\d{7}\b'){ $userId=$Matches[0] }
 return [pscustomobject]@{ System=$system; Team=$team; Role=$role; UserName=$userName; UserId=$userId } }

function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Get-ViewDetails($win){ $l=@(); foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if( ($nm -match 'wyswietl' -and $nm -match 'szczeg') -or ($nm -match 'view' -and $nm -match 'detail') ){ $l+=$e } }; return $l }
# klucz = STABILNE ID zgloszenia z wiersza (np. WO0000012345); fallback: caly tekst
function Get-RowKey($btn){ $node=$btn; for($k=0;$k -lt 8;$k++){ $p=$WALK.GetParent($node); if(-not $p){ break }; $node=$p; $rr=$node.Current.BoundingRectangle; if($rr.Width -ge 400 -and $rr.Height -le 140){ break } }; $t=''; foreach($d in $node.FindAll($TS::Descendants,$TRUE1)){ $nm=$d.Current.Name; if($nm){ $t+=$nm+' ' } }; $m=[regex]::Match($t,'\b[A-Z]{2,4}\d{6,}\b'); if($m.Success){ return $m.Value }; return ($t -replace '\s+',' ').Trim() }
function Find-El($win,[string[]]$musi){ foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if(-not $nm){continue}; $ok=$true; foreach($m in $musi){ if($nm -notmatch $m){ $ok=$false; break } }; if($ok){ return $e } }; return $null }
function Klik-XY($x,$y){ [Win]::Click([int]$x,[int]$y) }
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }
function Do-Widoku($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{} }
function Przewin-Dol($vd){ if($vd.Count -gt 0){ $r=$vd[$vd.Count-1].Current.BoundingRectangle; [Win]::Wheel([int]($r.X+$r.Width/2),[int]($r.Y),-700) } }
function Zapewnij-Widok($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{}; Start-Sleep -Milliseconds 500; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; for($k=0;$k -lt 8;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ Start-Sleep -Milliseconds 300; continue }; $cy=$r.Y+$r.Height/2; if($cy -gt 110 -and $cy -lt ($sh-160)){ break }; $wy=[int]($sh/2); if($cy -ge ($sh-160)){ [Win]::Wheel([int]($r.X+10),$wy,-160) } else { [Win]::Wheel([int]($r.X+10),$wy,160) }; Start-Sleep -Milliseconds 450 } }
function Find-ClearX($win,$field){ $fr=$field.Current.BoundingRectangle; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ if($e.Current.ControlType.ProgrammaticName -notmatch 'Button'){ continue }; $br=$e.Current.BoundingRectangle; if($br.Width -le 0 -or $br.Width -gt 45){ continue }; if([Math]::Abs(($br.Y+$br.Height/2)-($fr.Y+$fr.Height/2)) -lt 22 -and $br.X -ge ($fr.X-5) -and $br.X -le ($fr.X+$fr.Width+70)){ return $e } }; return $null }
function Kopiuj-Strone($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 300; [System.Windows.Forms.SendKeys]::SendWait('{TAB}'); Start-Sleep -Milliseconds 250; [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('^c'); Start-Sleep -Milliseconds 400; return (Get-Clipboard -Raw) }
function Wstecz($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('%{LEFT}') }

# AKCJA: Edit -> pole grupy -> wpisz $grupa (nie zapisuje). Zwraca $true.
function Akcja-Grupa($win,$grupa){
  $edit=Find-El $win @('edytuj'); if(-not $edit){ $edit=Find-El $win @('^edit') }; if(-not $edit){ $edit=Find-El $win @('edit') }
  if($edit){ Klik-El $edit|Out-Null; Start-Sleep -Milliseconds 1600 }
  $szukaj=$OBECNA.ToLower(); $target=$null
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); $val=(ToAscii (Get-Val $e)).ToLower(); if( ($nm -match $szukaj) -or ($val -match $szukaj) ){ $ct=$e.Current.ControlType.ProgrammaticName; if(-not $target){ $target=$e }; if($ct -match 'Edit|ComboBox'){ $target=$e; break } } }
  if(-not $target){ Write-Host "   [akcja] nie znalazlem pola grupy - pomijam" -ForegroundColor Red; return $false }
  Zapewnij-Widok $target
  $fr=$target.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2)
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 350
  $x=Find-ClearX $win $target
  if($x){ Klik-El $x|Out-Null; Start-Sleep -Milliseconds 350 } else { [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 250 }
  Klik-XY ($fr.X+10) ($fr.Y-28); Start-Sleep -Milliseconds 350
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait($grupa); Start-Sleep -Milliseconds 1000
  [System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 300
  [console]::Beep(800,200); return $true
}

# --- Start ---
Clear-Host
Write-Host "SAP Ticket Router - PELNY (routing do zespolow)" -ForegroundColor Cyan
$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem okna Edge." -ForegroundColor Red; return }
$vd=Get-ViewDetails $win; Write-Host ("Widocznych na starcie: "+$vd.Count) -ForegroundColor Green
if($vd.Count -eq 0){ Write-Host "Brak 'View Details'." -ForegroundColor Red; return }
for($c=6;$c -ge 1;$c--){ Write-Host ("Start za "+$c+"s - zostaw myszke...") -ForegroundColor Yellow; Start-Sleep -Seconds 1 }

$routed=0; $doReki=@(); $seen=@{}; $stall=0; $nr=0; $wyniki=@()

while($stall -lt 4 -and $seen.Count -lt $MaxTicketow){
  $win=Get-EdgeWindow; $vd=Get-ViewDetails $win
  if($vd.Count -eq 0){ Start-Sleep -Milliseconds 1200; $stall++; continue }
  $target=$null; $tkey=$null
  foreach($btn in $vd){ $key=Get-RowKey $btn; if($key -and -not $seen.ContainsKey($key)){ $target=$btn; $tkey=$key; break } }
  if(-not $target){ Write-Host "Widoczne zrobione - przewijam..." -ForegroundColor DarkGray; Przewin-Dol $vd; Start-Sleep -Milliseconds 900; $stall++; continue }
  $seen[$tkey]=1; $stall=0; $nr++
  Do-Widoku $target; Start-Sleep -Milliseconds 300
  $r=$target.Current.BoundingRectangle; if($r.Width -le 0){ continue }
  Klik-XY ([int]($r.X+$r.Width/2)) ([int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds $CzasLadowania

  $win=Get-EdgeWindow; $txt=Kopiuj-Strone $win; $w=Przetworz $txt
  if($w.Team){
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  -> "+$w.Team) -ForegroundColor Green
    if($w.Role.Count -gt 0){ Write-Host ("   ROLE: "+($w.Role -join ', ')) }
    Write-Host ("   AKCJA: przypisz do "+$w.Team+" (nie zapisuje)") -ForegroundColor Yellow
    $win=Get-EdgeWindow
    if(Akcja-Grupa $win $w.Team){ Read-Host "   >>> SPRAWDZ i ZAPISZ ticket w Edge, potem ENTER" }
    $routed++
  }else{
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  DO_SPRAWDZENIA") -ForegroundColor Red
    $doReki += ("#"+$nr+" "+$tkey+" system="+$w.System+" user="+$w.UserName)
  }
  $wyniki += [pscustomobject]@{ Czas=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Ticket=$tkey; System=$w.System; Team=$w.Team; User=$w.UserName; UserId=$w.UserId; Role=($w.Role -join ';') }

  $win=Get-EdgeWindow; Wstecz $win; Start-Sleep -Milliseconds $CzasListy
}

Write-Host ""; Write-Host "=========== PODSUMOWANIE ===========" -ForegroundColor Cyan
Write-Host ("Przetworzone : "+$nr)
Write-Host ("Zroutowane   : "+$routed) -ForegroundColor Green
Write-Host ("DO_SPRAWDZENIA: "+$doReki.Count) -ForegroundColor Red
if($doReki.Count -gt 0){ $doReki | ForEach-Object { Write-Host ("  - "+$_) } }
if($wyniki.Count -gt 0){ $wyniki | Export-Csv -Path $PlikLogu -NoTypeInformation -Encoding UTF8 }
Write-Host ("Log: "+$PlikLogu) -ForegroundColor DarkGray; Write-Host "====================================" -ForegroundColor Cyan
