# ============================================================
#  AKCJA: podmien "Assignee support group" na GLOBAL-SERVICEDESK
#  1) klika EDIT  2) znajduje pole po obecnej wartosci  3) wpisuje GSD
#  NIE ZAPISUJE - zatrzymuje sie, Ty klikasz Save.
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
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 400

# 1) KLIK EDIT (jesli jest; jak juz w trybie edycji - moze nie byc, wtedy idziemy dalej)
$edit=Find-El $win @('edytuj'); if(-not $edit){ $edit=Find-El $win @('^edit') }; if(-not $edit){ $edit=Find-El $win @('edit') }
if($edit){ Write-Host ("Klikam EDIT: '"+$edit.Current.Name+"'") -ForegroundColor Green; Klik-El $edit|Out-Null; Start-Sleep -Milliseconds 1600 }
else{ Write-Host "Brak przycisku Edit (moze juz w trybie edycji) - probuje wpisac." -ForegroundColor DarkYellow }

# 2) ZNAJDZ pole po obecnej wartosci
$szukaj=$OBECNA.ToLower(); $target=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
 $nm=(ToAscii $e.Current.Name).ToLower(); $val=(ToAscii (Get-Val $e)).ToLower()
 if( ($nm -match $szukaj) -or ($val -match $szukaj) ){ $ct=$e.Current.ControlType.ProgrammaticName; if(-not $target){ $target=$e }; if($ct -match 'Edit|ComboBox'){ $target=$e; break } } }

# 3) WPISZ
if($target){
 Write-Host ("Pole grupy: ["+$target.Current.ControlType.ProgrammaticName+"] name='"+$target.Current.Name+"' val='"+(Get-Val $target)+"'") -ForegroundColor Green
 Klik-El $target|Out-Null; Start-Sleep -Milliseconds 500
 $zrobione=$false
 try{ $vp=$target.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); $vp.SetValue($GRUPA); $zrobione=$true; Write-Host "SetValue OK." -ForegroundColor Green }catch{}
 if(-not $zrobione){ [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait($GRUPA); Write-Host "Wpisane klawiatura." -ForegroundColor Green }
 Start-Sleep -Milliseconds 300; [console]::Beep(800,200); Write-Host "GOTOWE - SPRAWDZ i ZAPISZ RECZNIE." -ForegroundColor Cyan
}else{
 Write-Host "Nie znalazlem pola z '$OBECNA'. Pola z wartosciami:" -ForegroundColor Red
 $i=0; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $ct=$e.Current.ControlType.ProgrammaticName; $val=Get-Val $e; if($ct -match 'Edit|ComboBox' -or $val){ Write-Host ("  ["+$ct+"] name='"+$e.Current.Name+"' val='"+$val+"'"); $i++; if($i -ge 60){break} } }
}
