# ============================================================
#  DUMPER v2 - klika "Edit assignee" i pokazuje pola edytora
#  Odpal na OTWARTYM tickecie. Nic nie zapisuje.
# ============================================================
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes
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
function SafeXY($r){ try{ if([double]::IsInfinity($r.X) -or [double]::IsNaN($r.X)){ return 'x=? y=?' }; return ('x='+[int]$r.X+' y='+[int]$r.Y) }catch{ return 'x=? y=?' } }

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 400

# 1) klik "Edit assignee" (albo edytuj/edit)
$edit=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ if($e.Current.ControlType.ProgrammaticName -notmatch 'Button|Hyperlink'){ continue }; $nm=(ToAscii $e.Current.Name).ToLower(); if($nm -match 'edit assignee|edytuj|^edit'){ $edit=$e; break } }
if($edit){ Write-Host ("Klikam: '"+$edit.Current.Name+"'") -ForegroundColor Green; $r=$edit.Current.BoundingRectangle; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds 1800 }
else{ Write-Host "Nie znalazlem 'Edit assignee'." -ForegroundColor Red }

# 2) dump pol po otwarciu edytora
Write-Host ""; Write-Host "=== POLA EDIT/COMBOBOX PO EDIT ===" -ForegroundColor Cyan
$i=0
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -match 'Edit|ComboBox'){
    Write-Host ("["+$ct+"] name='"+$e.Current.Name+"' val='"+(Get-Val $e)+"' "+(SafeXY $e.Current.BoundingRectangle))
    $i++; if($i -ge 80){ break }
  }
}
Write-Host ""; Write-Host "=== TEKSTY/POLA z 'group' lub 'assignee' ===" -ForegroundColor Cyan
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $nm=(ToAscii $e.Current.Name).ToLower()
  if($nm -match 'support group|assignee|grupa|przypisan'){ Write-Host ("["+$e.Current.ControlType.ProgrammaticName+"] name='"+$e.Current.Name+"' val='"+(Get-Val $e)+"'") -ForegroundColor Yellow }
}
