# ============================================================
#  AKCJA: podmien "Assignee support group" na GLOBAL-SERVICEDESK
#  Sekwencja pod autouzupelniane combo:
#   1) klik EDIT
#   2) znajdz pole po obecnej wartosci
#   3) wyczysc (X obok albo Ctrl+A+Del)
#   4) klik obok (odklej focus) -> klik w pole
#   5) wpisz GSD -> wybierz z podpowiedzi (strzalka w dol + Enter)
#  NIE ZAPISUJE - Ty klikasz Save.
# ============================================================
$OBECNA = "TOOLS-ACCESS-MANAGEMENT"
$GRUPA  = "GLOBAL-SERVICEDESK"

Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win {
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public static void Click(int x,int y){ SetCursorPos(x,y); mouse_event(0x0002,0,0,0,0); mouse_event(0x0004,0,0,0,0); }
}
"@
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }
function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Find-El($win,[string[]]$musi){ foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if(-not $nm){continue}; $ok=$true; foreach($m in $musi){ if($nm -notmatch $m){ $ok=$false; break } }; if($ok){ return $e } }; return $null }
function Klik-XY($x,$y){ [Win]::Click([int]$x,[int]$y) }
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }
# maly przycisk (X) tuz obok pola, w tym samym wierszu
function Find-ClearX($win,$field){
  $fr=$field.Current.BoundingRectangle
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
    if($e.Current.ControlType.ProgrammaticName -notmatch 'Button'){ continue }
    $br=$e.Current.BoundingRectangle
    if($br.Width -le 0 -or $br.Width -gt 45){ continue }
    if([Math]::Abs(($br.Y+$br.Height/2)-($fr.Y+$fr.Height/2)) -lt 22 -and $br.X -ge ($fr.X-5) -and $br.X -le ($fr.X+$fr.Width+70)){ return $e }
  }
  return $null
}

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 400

# 1) EDIT
$edit=Find-El $win @('edytuj'); if(-not $edit){ $edit=Find-El $win @('^edit') }; if(-not $edit){ $edit=Find-El $win @('edit') }
if($edit){ Write-Host ("Klikam EDIT: '"+$edit.Current.Name+"'") -ForegroundColor Green; Klik-El $edit|Out-Null; Start-Sleep -Milliseconds 1600 } else { Write-Host "Brak Edit (moze juz edycja)." -ForegroundColor DarkYellow }

# 2) POLE
$szukaj=$OBECNA.ToLower(); $target=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); $val=(ToAscii (Get-Val $e)).ToLower(); if( ($nm -match $szukaj) -or ($val -match $szukaj) ){ $ct=$e.Current.ControlType.ProgrammaticName; if(-not $target){ $target=$e }; if($ct -match 'Edit|ComboBox'){ $target=$e; break } } }

if($target){
  $fr=$target.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2)
  Write-Host ("Pole: ["+$target.Current.ControlType.ProgrammaticName+"] val='"+(Get-Val $target)+"'") -ForegroundColor Green

  # 3) focus + wyczysc
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 350
  $x=Find-ClearX $win $target
  if($x){ Write-Host "Czyszcze przez X" -ForegroundColor DarkGray; Klik-El $x|Out-Null; Start-Sleep -Milliseconds 350 }
  else{ [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 250 }

  # 4) klik obok (odklej) -> klik w pole
  Klik-XY ($fr.X+10) ($fr.Y-28); Start-Sleep -Milliseconds 350
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 400

  # 5) wpisz + wybierz z podpowiedzi
  [System.Windows.Forms.SendKeys]::SendWait($GRUPA); Start-Sleep -Milliseconds 1000
  [System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 300

  [console]::Beep(800,200)
  Write-Host "GOTOWE - SPRAWDZ (czy wybralo GLOBAL-SERVICEDESK) i ZAPISZ RECZNIE." -ForegroundColor Cyan
}else{
  Write-Host "Nie znalazlem pola z '$OBECNA'. Pola z wartosciami:" -ForegroundColor Red
  $i=0; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $ct=$e.Current.ControlType.ProgrammaticName; $val=Get-Val $e; if($ct -match 'Edit|ComboBox' -or $val){ Write-Host ("  ["+$ct+"] name='"+$e.Current.Name+"' val='"+$val+"'"); $i++; if($i -ge 60){break} } }
}
