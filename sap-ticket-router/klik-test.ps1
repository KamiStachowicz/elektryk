# Test klikania "Wyswietl szczegoly" - bez polskich znakow w kodzie.
# Normalizuje nazwy elementow (usuwa ogonki) i szuka po 'wyswietl' + 'szczeg'.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
  public static void Click(int x,int y){ SetCursorPos(x,y); mouse_event(0x0002,0,0,0,0); mouse_event(0x0004,0,0,0,0); }
}
"@
function ToAscii($s){
  if(-not $s){return ''}
  $n=$s.Normalize([Text.NormalizationForm]::FormD)
  -join($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
}
$AE=[System.Windows.Automation.AutomationElement]
$TS=[System.Windows.Automation.TreeScope]
$root=$AE::RootElement
$true1=[System.Windows.Automation.Condition]::TrueCondition

# ogranicz do okna Edge (szybciej)
$win=$null
foreach($w in $root.FindAll($TS::Children,$true1)){ if($w.Current.Name -match 'Edge'){ $win=$w; break } }
if(-not $win){ $win=$root; Write-Host "Nie znalazlem okna Edge - szukam wszedzie" -ForegroundColor DarkYellow }

$all=$win.FindAll($TS::Descendants,$true1)
Write-Host ("Przeszukuje elementow: "+$all.Count) -ForegroundColor DarkGray

$cel=$null
foreach($e in $all){
  $nm=ToAscii $e.Current.Name
  if($nm -match 'wyswietl' -and $nm -match 'szczeg'){ $cel=$e; break }
}

if($cel){
  $r=$cel.Current.BoundingRectangle
  $x=[int]($r.X+$r.Width/2); $y=[int]($r.Y+$r.Height/2)
  Write-Host ("ZNALAZLEM: '"+$cel.Current.Name+"' -> klikam w ("+$x+","+$y+")") -ForegroundColor Green
  [M]::Click($x,$y)
}else{
  Write-Host "Nadal nie znalazlem. Oto przykladowe nazwy elementow (do podejrzenia):" -ForegroundColor Red
  $i=0
  foreach($e in $all){ $nm=$e.Current.Name; if($nm){ Write-Host ("  - "+$nm); $i++; if($i -ge 50){break} } }
}
