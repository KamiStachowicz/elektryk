# ============================================================
#  AKCJA: podmien "Assignee support group" na GLOBAL-SERVICEDESK
#  Znajduje pole po jego OBECNEJ wartosci (TOOLS-ACCESS-MANAGEMENT).
#  NIE ZAPISUJE - zatrzymuje sie, Ty klikasz Save.
#  Zaloz, ze ticket jest w trybie EDIT (pole pokazuje grupe).
# ============================================================
$OBECNA = "TOOLS-ACCESS-MANAGEMENT"   # czego szukamy w polu
$GRUPA  = "GLOBAL-SERVICEDESK"        # co wpisujemy

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

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 300

$szukaj = $OBECNA.ToLower()
$target=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $nm=(ToAscii $e.Current.Name).ToLower(); $val=(ToAscii (Get-Val $e)).ToLower()
  if( ($nm -eq $szukaj) -or ($val -eq $szukaj) -or ($nm -match $szukaj) -or ($val -match $szukaj) ){
    $ct=$e.Current.ControlType.ProgrammaticName
    # preferuj pole edytowalne (Edit/ComboBox); zapamietaj pierwszy pasujacy
    if(-not $target){ $target=$e }
    if($ct -match 'Edit|ComboBox'){ $target=$e; break }
  }
}

if($target){
  Write-Host ("Znalazlem pole grupy: ["+$target.Current.ControlType.ProgrammaticName+"] name='"+$target.Current.Name+"' val='"+(Get-Val $target)+"'") -ForegroundColor Green
  # najpierw sprobuj ValuePattern.SetValue
  $zrobione=$false
  try{ $vp=$target.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); $vp.SetValue($GRUPA); $zrobione=$true; Write-Host "Ustawilem przez SetValue." -ForegroundColor Green }catch{}
  if(-not $zrobione){
    $r=$target.Current.BoundingRectangle
    [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds 400
    [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 150
    [System.Windows.Forms.SendKeys]::SendWait($GRUPA); Write-Host "Wpisalem przez klik+klawiatura." -ForegroundColor Green
  }
  Start-Sleep -Milliseconds 300; [console]::Beep(800,200)
  Write-Host "GOTOWE - SPRAWDZ i ZAPISZ RECZNIE (nic nie zapisalem)." -ForegroundColor Cyan
}else{
  Write-Host "Nie znalazlem pola z wartoscia '$OBECNA'. Oto pola z wartosciami:" -ForegroundColor Red
  $i=0
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
    $ct=$e.Current.ControlType.ProgrammaticName; $val=Get-Val $e; $nm=$e.Current.Name
    if($ct -match 'Edit|ComboBox' -or $val){ Write-Host ("  ["+$ct+"] name='"+$nm+"' val='"+$val+"'"); $i++; if($i -ge 60){break} }
  }
}
