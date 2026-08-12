# ============================================================
#  TEST akcji GRUPA (SZYBKI - FindFirst zamiast skanu calego drzewa)
#  klik "Edit assignee" -> pole "Support group" -> wpisz GLOBAL-SERVICEDESK
#  NIE ZAPISUJE. Odpal na otwartym SmartIT tickecie.
# ============================================================
$GRUPA="GLOBAL-SERVICEDESK"
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
$AEP=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
$PC=[System.Windows.Automation.PropertyCondition]; $ANDC=[System.Windows.Automation.AndCondition]; $CT=[System.Windows.Automation.ControlType]
function EscSK($s){ $r=''; foreach($c in $s.ToCharArray()){ if('+^%~(){}[]'.Contains([string]$c)){ $r+='{'+$c+'}' } else { $r+=$c } }; return $r }
function Get-Edge{ foreach($w in $AEP::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
# szybkie: FindFirst po ControlType + Name
function Find1($root,$ctype,$name){ $c=New-Object $ANDC((New-Object $PC($AEP::ControlTypeProperty,$ctype)),(New-Object $PC($AEP::NameProperty,$name))); return $root.FindFirst($TS::Descendants,$c) }
function KEl($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){return}; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)) }
function Widok($el){ Start-Sleep -Milliseconds 300; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; for($k=0;$k -lt 10;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){Start-Sleep 300;continue}; $cy=$r.Y+$r.Height/2; if($cy -gt 110 -and $cy -lt ($sh-170)){break}; $wy=[int]($sh/2); if($cy -ge ($sh-170)){ [Win]::Wheel([int]($r.X+10),$wy,-160) } else { [Win]::Wheel([int]($r.X+10),$wy,160) }; Start-Sleep -Milliseconds 450 } }

$win=Get-Edge; if(-not $win){ Write-Host "Brak Edge" -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep 400

$edit=Find1 $win $CT::Button "Edit assignee"
if(-not $edit){ $edit=Find1 $win $CT::Hyperlink "Edit assignee" }
if($edit){ Write-Host "Klikam Edit assignee" -ForegroundColor Green; KEl $edit; Start-Sleep 1800 } else { Write-Host "Brak 'Edit assignee'" -ForegroundColor Yellow }

$t=Find1 $win $CT::ComboBox "Support group"
if(-not $t){ $t=Find1 $win $CT::Edit "Support group" }
if(-not $t){ Write-Host "Nie znalazlem 'Support group'" -ForegroundColor Red; return }
Write-Host "Znalazlem Support group - przewijam" -ForegroundColor Green
Widok $t; $fr=$t.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2)
[Win]::Click($cx,$cy); Start-Sleep 400
[System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep 250
[System.Windows.Forms.SendKeys]::SendWait((EscSK $GRUPA)); Start-Sleep 1300
[System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep 300; [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep 300
[console]::Beep(800,200); Write-Host "GOTOWE - sprawdz pole Support group (NIE zapisano)" -ForegroundColor Cyan
