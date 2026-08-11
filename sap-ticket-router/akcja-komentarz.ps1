# ============================================================
#  TESTER pola komentarza. Znajduje pole "notatka/komentarz",
#  wpisuje testowa wiadomosc i ZATRZYMUJE sie (NIE wysyla).
#  Zaloz OTWARTY ticket w Edge.
#  Jak nie znajdzie - wypisze pola tekstowe (wklej mi je).
# ============================================================
$WIADOMOSC = "Hi, please provide the SAP system (e.g. P50) and the user ID (e.g. M0123456). Thanks."

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
function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Zapewnij-Widok($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{}; Start-Sleep -Milliseconds 500; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; for($k=0;$k -lt 8;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ Start-Sleep -Milliseconds 300; continue }; $cy=$r.Y+$r.Height/2; if($cy -gt 110 -and $cy -lt ($sh-160)){ break }; $wy=[int]($sh/2); if($cy -ge ($sh-160)){ [Win]::Wheel([int]($r.X+10),$wy,-160) } else { [Win]::Wheel([int]($r.X+10),$wy,160) }; Start-Sleep -Milliseconds 450 } }

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 400

# szukaj pola komentarza po nazwie/placeholderze
$slowa='notatk|komentarz|coment|comment|\bnote\b|odpowied|reply|add a note|dodaj notatke|wpisz|wiadomo|activity|aktywno'
$target=$null
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -notmatch 'Edit|Document|Text'){ continue }
  $nm=(ToAscii $e.Current.Name).ToLower()
  if($nm -match $slowa){ $target=$e; break }
}

if($target){
  Write-Host ("Znalazlem pole komentarza: ["+$target.Current.ControlType.ProgrammaticName+"] name='"+$target.Current.Name+"'") -ForegroundColor Green
  Zapewnij-Widok $target
  $r=$target.Current.BoundingRectangle
  [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds 500
  [System.Windows.Forms.SendKeys]::SendWait($WIADOMOSC); Start-Sleep -Milliseconds 300
  [console]::Beep(800,200)
  Write-Host "GOTOWE - wpisalem testowy komentarz. SPRAWDZ i wyslij RECZNIE (nic nie wyslalem)." -ForegroundColor Cyan
}else{
  Write-Host "Nie znalazlem pola komentarza. Pola tekstowe na stronie:" -ForegroundColor Red
  $i=0
  foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
    $ct=$e.Current.ControlType.ProgrammaticName
    if($ct -match 'Edit|Document|Text'){ $nm=$e.Current.Name; if($nm){ Write-Host ("  ["+$ct+"] name='"+$nm+"'"); $i++; if($i -ge 60){break} } }
  }
}
