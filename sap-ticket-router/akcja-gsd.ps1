# ============================================================
#  AKCJA: ustaw "Assignee support group" = GLOBAL-SERVICEDESK
#  NIE ZAPISUJE - zatrzymuje sie, Ty klikasz Save.
#  Zaloz, ze masz OTWARTY ticket w Edge (widok szczegolow).
# ============================================================
$GRUPA = "GLOBAL-SERVICEDESK"

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
function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
# znajdz element, ktorego nazwa (bez ogonkow, malymi) zawiera WSZYSTKIE podane fragmenty
function Find-El($win,[string[]]$musi){
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
    $nm=(ToAscii $e.Current.Name).ToLower(); if(-not $nm){ continue }
    $ok=$true; foreach($m in $musi){ if($nm -notmatch $m){ $ok=$false; break } }
    if($ok){ return $e }
  }
  return $null
}
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }

$win=Get-EdgeWindow
if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400

# 1) Klik EDIT (Edit / Edytuj)
$edit = Find-El $win @('edytuj'); if(-not $edit){ $edit = Find-El $win @('^edit') }; if(-not $edit){ $edit = Find-El $win @('edit') }
if($edit){ Write-Host ("Klikam EDIT: '"+$edit.Current.Name+"'") -ForegroundColor Green; Klik-El $edit | Out-Null; Start-Sleep -Milliseconds 1500 }
else{ Write-Host "Nie znalazlem przycisku Edit - wpisz recznie po Edit i odpal ponownie od pola." -ForegroundColor DarkYellow }

# 2) Znajdz pole 'Assignee support group' (EN) / 'Grupa przypisanych' (PL)
$pole = Find-El $win @('assignee','group')
if(-not $pole){ $pole = Find-El $win @('grupa','przypisan') }

if($pole){
  Write-Host ("Znalazlem pole: '"+$pole.Current.Name+"' - wpisuje "+$GRUPA) -ForegroundColor Green
  Klik-El $pole | Out-Null; Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150
  [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 150
  [System.Windows.Forms.SendKeys]::SendWait($GRUPA)
  Start-Sleep -Milliseconds 300
  [console]::Beep(800,200)
  Write-Host "GOTOWE - pole wypelnione. SPRAWDZ i ZAPISZ RECZNIE (nic nie zapisalem)." -ForegroundColor Cyan
}else{
  Write-Host "Nie znalazlem pola 'Assignee support group'. Wypisuje kandydatow (pola/combo):" -ForegroundColor Red
  $i=0
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
    $ct=$e.Current.ControlType.ProgrammaticName
    if($ct -match 'Edit|ComboBox'){ $nm=$e.Current.Name; Write-Host ("  ["+$ct+"] "+$nm); $i++; if($i -ge 40){break} }
  }
}
