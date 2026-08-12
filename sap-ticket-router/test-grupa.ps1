# ============================================================
#  TEST akcji GRUPA (z zegarami) - diagnoza szybkosci UIA
#  klik "Edit assignee" -> Ctrl+End (dol strony) -> pole "Support group" -> wpisz
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
}
"@
$AEP=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
$PC=[System.Windows.Automation.PropertyCondition]; $ANDC=[System.Windows.Automation.AndCondition]; $CT=[System.Windows.Automation.ControlType]
function EscSK($s){ $r=''; foreach($c in $s.ToCharArray()){ if('+^%~(){}[]'.Contains([string]$c)){ $r+='{'+$c+'}' } else { $r+=$c } }; return $r }
function Get-Edge{ foreach($w in $AEP::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Find1($root,$ctype,$name){ $c=New-Object $ANDC((New-Object $PC($AEP::ControlTypeProperty,$ctype)),(New-Object $PC($AEP::NameProperty,$name))); return $root.FindFirst($TS::Descendants,$c) }
$win=Get-Edge; if(-not $win){ Write-Host "Brak Edge" -ForegroundColor Red; return }
[Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep 400
$sw=[Diagnostics.Stopwatch]::StartNew()
Write-Host "1. szukam 'Edit assignee'..." -ForegroundColor DarkGray
$edit=Find1 $win $CT::Button "Edit assignee"
Write-Host ("   znaleziony="+($edit -ne $null)+"  czas="+[math]::Round($sw.Elapsed.TotalSeconds,1)+"s") -ForegroundColor Green
if($edit){ $r=$edit.Current.BoundingRectangle; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); Start-Sleep 1800 }
Write-Host "2. Ctrl+End (na dol strony)..." -ForegroundColor DarkGray
[System.Windows.Forms.SendKeys]::SendWait('^{END}'); Start-Sleep 1000
$sw.Restart()
Write-Host "3. szukam 'Support group'..." -ForegroundColor DarkGray
$t=Find1 $win $CT::ComboBox "Support group"
Write-Host ("   znaleziony="+($t -ne $null)+"  czas="+[math]::Round($sw.Elapsed.TotalSeconds,1)+"s") -ForegroundColor Green
if(-not $t){ Write-Host "Brak pola" -ForegroundColor Red; return }
$fr=$t.Current.BoundingRectangle; [Win]::Click([int]($fr.X+$fr.Width/2),[int]($fr.Y+$fr.Height/2)); Start-Sleep 400
[System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep 250
[System.Windows.Forms.SendKeys]::SendWait((EscSK $GRUPA)); Start-Sleep 1300
[System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep 300; [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
[console]::Beep(800,200); Write-Host "GOTOWE (NIE zapisano)" -ForegroundColor Cyan
