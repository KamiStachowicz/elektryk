# ============================================================
#  TESTER pola "Assignee" (OSOBA, nie grupa).
#  Klika Edit, znajduje pole osoby, wpisuje $OSOBA, ZATRZYMUJE sie.
#  NIE ZAPISUJE. Ustaw $OSOBA na swoj login przed testem.
# ============================================================
$OSOBA = "M0235728"   # <-- wpisz swoj login do testu

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
function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }
function EscSK($s){ $r=''; foreach($c in $s.ToCharArray()){ if('+^%~(){}[]'.Contains([string]$c)){ $r+='{'+$c+'}' } else { $r+=$c } }; return $r }
function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Find-El($win,[string[]]$musi){ foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if(-not $nm){continue}; $ok=$true; foreach($m in $musi){ if($nm -notmatch $m){ $ok=$false; break } }; if($ok){ return $e } }; return $null }
function Klik-XY($x,$y){ [Win]::Click([int]$x,[int]$y) }
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }
function Find-ClearX($win,$field){ $fr=$field.Current.BoundingRectangle; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ if($e.Current.ControlType.ProgrammaticName -notmatch 'Button'){ continue }; $br=$e.Current.BoundingRectangle; if($br.Width -le 0 -or $br.Width -gt 45){ continue }; if([Math]::Abs(($br.Y+$br.Height/2)-($fr.Y+$fr.Height/2)) -lt 22 -and $br.X -ge ($fr.X-5) -and $br.X -le ($fr.X+$fr.Width+70)){ return $e } }; return $null }
function Zapewnij-Widok($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{}; Start-Sleep -Milliseconds 500; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; for($k=0;$k -lt 8;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ Start-Sleep -Milliseconds 300; continue }; $cy=$r.Y+$r.Height/2; if($cy -gt 110 -and $cy -lt ($sh-160)){ break }; $wy=[int]($sh/2); if($cy -ge ($sh-160)){ [Win]::Wheel([int]($r.X+10),$wy,-160) } else { [Win]::Wheel([int]($r.X+10),$wy,160) }; Start-Sleep -Milliseconds 450 } }

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 400

# EDIT
$edit=Find-El $win @('edytuj'); if(-not $edit){ $edit=Find-El $win @('^edit') }; if(-not $edit){ $edit=Find-El $win @('edit') }
if($edit){ Write-Host ("Klikam EDIT: '"+$edit.Current.Name+"'") -ForegroundColor Green; Klik-El $edit|Out-Null; Start-Sleep -Milliseconds 1600 } else { Write-Host "Brak Edit (moze juz edycja)." -ForegroundColor DarkYellow }

# POLE OSOBY: nazwa zawiera assignee/przypisano ALE NIE group/grupa
$target=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName; if($ct -notmatch 'Edit|ComboBox'){ continue }
  $nm=(ToAscii $e.Current.Name).ToLower()
  if( ($nm -match 'assignee|przypisan|assigned to|osoba') -and ($nm -notmatch 'group|grupa') ){ $target=$e; break }
}

if($target){
  Write-Host ("Pole osoby: ["+$target.Current.ControlType.ProgrammaticName+"] name='"+$target.Current.Name+"'") -ForegroundColor Green
  Zapewnij-Widok $target
  $fr=$target.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2)
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 350
  $x=Find-ClearX $win $target
  if($x){ Klik-El $x|Out-Null; Start-Sleep -Milliseconds 350 } else { [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 250 }
  Klik-XY ($fr.X+10) ($fr.Y-28); Start-Sleep -Milliseconds 350
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait((EscSK $OSOBA)); Start-Sleep -Milliseconds 1000
  [System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 300
  [console]::Beep(800,200); Write-Host "GOTOWE - SPRAWDZ i ZAPISZ RECZNIE." -ForegroundColor Cyan
}else{
  Write-Host "Nie znalazlem pola osoby. Pola (Edit/ComboBox) z nazwami:" -ForegroundColor Red
  $i=0; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $ct=$e.Current.ControlType.ProgrammaticName; if($ct -match 'Edit|ComboBox'){ Write-Host ("  ["+$ct+"] name='"+$e.Current.Name+"' val='"+(Get-Val $e)+"'"); $i++; if($i -ge 60){break} } }
}
