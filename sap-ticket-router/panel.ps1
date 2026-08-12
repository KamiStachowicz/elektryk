# ============================================================
#  PANEL KAFELKOW - okienko z przyciskami do szybkich akcji
#  Klikasz kafelek -> akcja na AKTUALNIE otwartym tickecie w Edge.
#  Dodawaj wlasne kafelki w $Kafelki ponizej.
# ============================================================

# ---- KAFELKI (edytuj / dodawaj) ----
#  Text   - napis na przycisku
#  Comment- tresc komentarza (puste = bez komentarza)
#  Public - $true=publiczny (widzi zglaszajacy), $false=wewnetrzny
#  Grupa  - Assignee support group (puste = nie zmieniaj)
#  Osoba  - Request assignee / Person (puste = nie zmieniaj)
$Kafelki = @(
  @{ Text='Not our scope -> GSD'; Comment='Not our scope.'; Public=$false; Grupa='GLOBAL-SERVICEDESK'; Osoba='' }
  @{ Text='Przypisz do GSD (bez komentarza)'; Comment=''; Public=$false; Grupa='GLOBAL-SERVICEDESK'; Osoba='' }
  @{ Text='Ask: podaj system i usera'; Comment='Hi, please provide the SAP system (e.g. P50) and the user ID (e.g. M0123456). Thanks.'; Public=$true; Grupa=''; Osoba='' }
)
# ------------------------------------

Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
if(-not ('Win' -as [type])){ Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win {
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,int e);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 public static void Click(int x,int y){ SetCursorPos(x,y); mouse_event(0x0002,0,0,0,0); mouse_event(0x0004,0,0,0,0); }
 public static void Wheel(int x,int y,int delta){ SetCursorPos(x,y); mouse_event(0x0800,0,0,(uint)delta,0); }
}
"@ }
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
$CTL=[System.Windows.Automation.ControlType]
function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function EscSK($s){ $r=''; foreach($c in $s.ToCharArray()){ if('+^%~(){}[]'.Contains([string]$c)){ $r+='{'+$c+'}' } else { $r+=$c } }; return $r }
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }
function Get-Edge{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Front($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 350 }
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }
function Klik-XY($x,$y){ [Win]::Click([int]$x,[int]$y) }
function Find1($root,$ctype,$substr){ $cond=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$ctype); foreach($e in $root.FindAll($TS::Descendants,$cond)){ $nm=(ToAscii $e.Current.Name); if($nm -match $substr){ return $e } }; return $null }
function Znajdz-PoleEx($win,$includes,$excludes){ for($i=0;$i -lt 5;$i++){ $cb=@($win.FindAll($TS::Descendants,(New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$CTL::ComboBox)))); $ed=@($win.FindAll($TS::Descendants,(New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$CTL::Edit)))); $all=$cb+$ed; foreach($inc in $includes){ foreach($e in $all){ $nm=(ToAscii $e.Current.Name).ToLower(); if($nm -match $inc){ $bad=$false; foreach($x in $excludes){ if($x -and ($nm -match $x)){ $bad=$true; break } }; if(-not $bad){ return $e } } } }; Start-Sleep -Milliseconds 700 }; return $null }
function Zapewnij-Widok($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{}; Start-Sleep -Milliseconds 500; $sw=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; $wx=[int]($sw/2); $wy=[int]($sh/2); for($k=0;$k -lt 14;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ Start-Sleep -Milliseconds 300; continue }; $cy=$r.Y+$r.Height/2; if($cy -gt 120 -and $cy -lt ($sh-200)){ break }; if($cy -ge ($sh-200)){ [Win]::Wheel($wx,$wy,-400) } else { [Win]::Wheel($wx,$wy,400) }; Start-Sleep -Milliseconds 400 } }
function Klik-EditAssignee($win){ $e=Find1 $win $CTL::Button 'edit assignee'; if(-not $e){ $e=Find1 $win $CTL::Hyperlink 'edit assignee' }; if(-not $e){ $e=Find1 $win $CTL::Button 'edit' }; if($e){ Front $win; Klik-El $e|Out-Null; Start-Sleep -Milliseconds 2000; return $true }; return $false }
function Wpisz-Combo($win,$target,$wartosc){ Front $win; Zapewnij-Widok $target; $fr=$target.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2); $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; if($cy -lt 60 -or $cy -gt ($sh-90)){ return $false }; Front $win; Klik-XY $cx $cy; Start-Sleep 400; [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep 200; [System.Windows.Forms.SendKeys]::SendWait((EscSK $wartosc)); Start-Sleep 1300; [System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep 300; [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep 300; return $true }
function Set-Grupa($win,$grupa){ Klik-EditAssignee $win|Out-Null; $t=Znajdz-PoleEx $win @('assignee support group','support group') @('manager'); if(-not $t){ return $false }; return (Wpisz-Combo $win $t $grupa) }
function Set-Osoba($win,$osoba){ Klik-EditAssignee $win|Out-Null; $t=Znajdz-PoleEx $win @('request assignee','\bperson\b','assignee') @('group','grupa','manager'); if(-not $t){ return $false }; return (Wpisz-Combo $win $t $osoba) }
function Set-Komentarz($win,$msg,$public){
  Front $win; $t=Find1 $win $CTL::Edit 'new note'; if(-not $t){ return $false }
  Zapewnij-Widok $t; $r=$t.Current.BoundingRectangle; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; $cy=[int]($r.Y+$r.Height/2)
  if($cy -lt 60 -or $cy -gt ($sh-90)){ return $false }
  Front $win; Klik-XY ([int]($r.X+$r.Width/2)) $cy; Start-Sleep 400
  [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep 100; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep 100
  [System.Windows.Forms.SendKeys]::SendWait((EscSK $msg)); Start-Sleep 300
  $cb=Find1 $win $CTL::CheckBox 'public'
  if($cb){ try{ $tp=$cb.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern); $on=($tp.Current.ToggleState.ToString() -eq 'On'); if($public -ne $on){ Klik-El $cb|Out-Null } }catch{} }
  return $true
}
function Zapisz-Ticket($win){ foreach($n in @('^Save$','^Zapisz$','Save changes')){ $b=Find1 $win $CTL::Button $n; if($b){ Front $win; Klik-El $b|Out-Null; return $true } }; return $false }
function Obsluz-Ostrzezenie($win){ Start-Sleep 500; foreach($n in @('^Yes$','^Tak$','^Continue$','^OK$')){ $b=Find1 $win $CTL::Button $n; if($b){ Front $win; Klik-El $b|Out-Null; Start-Sleep 700; return $true } }; return $false }

function Wykonaj($k){
  $win=Get-Edge; if(-not $win){ [System.Windows.Forms.MessageBox]::Show('Nie znalazlem okna Edge.'); return }
  if($k.Comment){ Set-Komentarz $win $k.Comment $k.Public | Out-Null }
  if($k.Grupa){ Set-Grupa $win $k.Grupa | Out-Null }
  if($k.Osoba){ Set-Osoba $win $k.Osoba | Out-Null }
  Zapisz-Ticket $win | Out-Null; Start-Sleep 700; Obsluz-Ostrzezenie $win | Out-Null
  [console]::Beep(800,200)
}

# --- GUI ---
$form=New-Object System.Windows.Forms.Form
$form.Text='Ticket Panel'; $form.Width=300; $form.Height=(90+$Kafelki.Count*54); $form.TopMost=$true; $form.StartPosition='Manual'; $form.Location=New-Object System.Drawing.Point(20,20); $form.FormBorderStyle='FixedToolWindow'
$y=12
foreach($k in $Kafelki){
  $b=New-Object System.Windows.Forms.Button
  $b.Text=$k.Text; $b.Width=264; $b.Height=44; $b.Left=12; $b.Top=$y; $b.Tag=$k
  $b.Add_Click({ $this.Enabled=$false; try{ Wykonaj $this.Tag }finally{ $this.Enabled=$true } })
  $form.Controls.Add($b); $y+=52
}
$lbl=New-Object System.Windows.Forms.Label; $lbl.Text='Otworz ticket w Edge, potem kliknij kafelek'; $lbl.Left=12; $lbl.Top=$y; $lbl.Width=264; $lbl.Height=30; $form.Controls.Add($lbl)
[void]$form.ShowDialog()
