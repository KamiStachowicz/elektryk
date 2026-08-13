# ============================================================
#  SAP TICKET TOOL - menu: DISPATCH (router) / GRC (w budowie)
#  Samodzielny plik - wklej do ISE i F5. Nie wola innych plikow.
# ============================================================
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; Add-Type -AssemblyName Microsoft.VisualBasic
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

# ---------------- MENU ----------------
$mode=''
$menu=New-Object System.Windows.Forms.Form
$menu.Text='SAP Ticket Tool'; $menu.Width=320; $menu.Height=320; $menu.StartPosition='CenterScreen'; $menu.TopMost=$true; $menu.FormBorderStyle='FixedDialog'; $menu.MaximizeBox=$false; $menu.MinimizeBox=$false
$bd=New-Object System.Windows.Forms.Button; $bd.Text='DISPATCH (auto)'; $bd.Left=20; $bd.Top=20; $bd.Width=270; $bd.Height=68; $bd.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold); $bd.BackColor=[System.Drawing.Color]::FromArgb(46,120,210); $bd.ForeColor='White'; $bd.Add_Click({ $script:mode='dispatch'; $menu.Close() }); $menu.Controls.Add($bd)
$bp=New-Object System.Windows.Forms.Button; $bp.Text='PANEL (kafelki - recznie)'; $bp.Left=20; $bp.Top=96; $bp.Width=270; $bp.Height=68; $bp.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold); $bp.BackColor=[System.Drawing.Color]::FromArgb(150,90,190); $bp.ForeColor='White'; $bp.Add_Click({ $script:mode='panel'; $menu.Close() }); $menu.Controls.Add($bp)
$bg=New-Object System.Windows.Forms.Button; $bg.Text='GRC'; $bg.Left=20; $bg.Top=172; $bg.Width=270; $bg.Height=68; $bg.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold); $bg.BackColor=[System.Drawing.Color]::FromArgb(60,160,90); $bg.ForeColor='White'; $bg.Add_Click({ $script:mode='grc'; $menu.Close() }); $menu.Controls.Add($bg)
[void]$menu.ShowDialog(); $menu.Dispose()
if(-not $mode){ return }

if($mode -eq 'grc'){
  [System.Windows.Forms.MessageBox]::Show("GRC - automatyzacja jeszcze w budowie.`n`nPokaz proces zakladania GRC (ekrany, pola), a zbudujemy to jak dispatch.","GRC - w budowie") | Out-Null
  return
}

# ============================================================
#  DISPATCH = router-full.ps1 ZYWCEM (skopiowane 1:1, nic nie zmieniane)
# ============================================================
# ---------------- REGULY ROUTINGU (typ zadania + system -> zespol) ----------------
# Sprawdzane PO KOLEI, pierwsza pasujaca wygrywa. ZWERYFIKUJ oznaczone # ?
$ZnaneSystemy = @('BKP','BEP','BWP','BGP','B4P','P50','P4M','K4M','Q4M','IAP','PFI','SM1','PHE','PHR','HRP','SF','ESS','PPH','DPH','QPH','KPH','SAC','MAQ-IS','MAQ','PGR','PGT')

# @{ N=nazwa; T=regex-tresci (lub $null); S=@(systemy wymagane)(lub $null); X=@(systemy wykluczone)(lub $null); Team=zespol }
$Reguly = @(
  @{ N='RF profile';      T='rf profile|zebra';                                        S=$null; X=$null;      Team='SHOPFLOOR-WAREHOUSE+INTRALOG' }
  @{ N='Folder';          T='folder access|delete folder|folder';                      S=$null; X=$null;      Team='TOOLS-ORCHESTRATION' }
  @{ N='Fiori';           T='fiori';                                                   S=$null; X=$null;      Team='APPL-INTEGRATION-SAP-CROSS-APPL' }
  @{ N='GRC problem';     T='\bgrc\b|cannot find roles|nie widac rol';                 S=$null; X=$null;      Team='APPL-INTEGRATION-SAP-CROSS-APPL' }
  @{ N='Omada';           T='omada';                                                   S=$null; X=$null;      Team='IDENTITY-TOOLS' }
  @{ N='Shopfloor';       T='shopfloor';                                               S=$null; X=$null;      Team='GLOBAL-SERVICEDESK' }
  @{ N='AD group';        T='ad group|add user to ad|dest-lg-ro';                       S=$null; X=$null;      Team='GLOBAL-SERVICEDESK' }
  @{ N='Lock/Unlock';     T='locking|unlock|password reset|extend validity|lock account'; S=$null; X=$null;   Team='GLOBAL-SERVICEDESK' }
  @{ N='Approver !P50';   T='approver';                                                S=$null; X=@('P50');   Team='APPL-INTEGRATION-SAP-CROSS-APPL' }  # ? approver P50 -> gdzie
  @{ N='AcctCreate GSD';  T='account creation|create account|new account|new user|zalozenie konta|utworzenie konta|konto'; S=@('PHE','ESS','BWP','BGP','B4P','P50','P4M','K4M','Q4M','IAP'); X=$null; Team='GLOBAL-SERVICEDESK' }
  @{ N='AcctCreate IDT';  T='account creation|create account|zalozenie konta|konto';   S=@('SM1','PFI'); X=$null; Team='IDENTITY-TOOLS' }
  @{ N='Removing P50';    T='removing roles|remove role|usuniecie roli|usun';          S=@('P50'); X=$null;   Team='GLOBAL-SERVICEDESK' }
  @{ N='Role assign SM1'; T='role assignment|assign.*role|transactions to roles';      S=@('SM1'); X=$null;   Team='APPL-INTEGRATION-SAP-CROSS-APPL' }
  @{ N='P50 issues';      T='issue|error|not working|problem|cannot|blad|nie dziala';  S=@('P50'); X=$null;   Team='APPL-INTEGRATION-SAP-CROSS-APPL' }
  @{ N='BKP';             T=$null; S=@('BKP'); X=$null;                                 Team='BACKEND-SAP-BASIS' }
  @{ N='BEP';             T=$null; S=@('BEP'); X=$null;                                 Team='ENGINEERING-WEB-APPL' }
  @{ N='Reporting';       T=$null; S=@('BWP','BGP','B4P','SAC','MAQ-IS','MAQ'); X=$null; Team='ENTERPRISE-REPORTING' }
  @{ N='HCM';             T=$null; S=@('PHE','PHR','HRP','SF','ESS'); X=$null;          Team='WORKFORCE-HCM-OPERATIONS' }
  @{ N='SupplyChain';     T=$null; S=@('PPH','DPH','QPH','KPH'); X=$null;               Team='SUPPLY-CHAIN-OPERATIONS' }
  @{ N='Identity';        T=$null; S=@('SM1','PFI'); X=$null;                           Team='IDENTITY-TOOLS' }
  @{ N='P50 fallback';    T=$null; S=@('P50'); X=$null;                                 Team='APPL-INTEGRATION-SAP-CROSS-APPL' }  # ?
)
# ----------------------------------------------------------------------------------

$OBECNA         = "TOOLS-ACCESS-MANAGEMENT"   # obecna grupa (do namierzenia pola)
$KomentarzSlowa = 'notatk|komentarz|comment|\bnote\b|reply|add a note|wpisz|wiadomo|activity|aktywno'
$TrybPopup = $true   # $true = popup Tak/Nie/Anuluj + auto-zapis; $false = pauza w konsoli (ENTER)
$KomentarzPublic = $true   # zaznacz "Public" w notatce (zeby zglaszajacy widzial)
$PomijajJuzPytane = $true  # $false = NIE pomijaj ticketow o ktore juz pytano (przetworz ponownie)
$PlikLogu       = "$env:USERPROFILE\Documents\sap_router_log.csv"
$PlikHistoria   = "$env:USERPROFILE\sap_router_historia.txt"   # numery juz odeslane (do wykrycia POWROTU)
$HistoriaDni    = 90   # ile dni pamietac odeslane tickety (0 = bez limitu)

# ---- NASZE systemy (obsluguje zespol -> rotacja osob) ----
$NaszeExact   = @('P4M','K4M','Q4M','P50','PGT','P02','PGE','G4M','D4M','M4M','T4M','E50','M50','Q50')
$NaszeWzorce  = @('^B.P$','^.TM$','^.EW$','^IA.$')   # BxP, xTM, xEW, IAx
$NaszeWyjatki = @('BKP','BEP')                        # NIE nasze - ida wg tabeli
# MARS -> zawsze Kinga; Kamil (M0235728) NIE jest przypisywany do ticketow
$Kinga = 'M0076236'
# Rotacja miedzy kolegami (kompletne bez komentarza, niekompletne + komentarz)
$Koledzy = @('M0076236','M0204125','M0227642','M0234670')   # bez Milosza i bez Kamila
# Mapa ID -> imie (dla czytelnej listy przy 'Przypisz osobe'). Uzupelnij imiona:
$OsobyNazwy = @{ 'M0076236'='Kinga'; 'M0204125'=''; 'M0227642'=''; 'M0234670'='' }
$PlikRotacji = "$env:USERPROFILE\sap_router_rotacja.txt"
$MaxTicketow    = 50
$CzasLadowania  = 2500
$CzasListy      = 1800
$Etykiety = @('#Application\s*Name\s*:+\s*([A-Za-z0-9]+)','SAP\s*ERP\s*System\s*:+\s*([A-Za-z0-9]+)','\bSystem\s*:+\s*([A-Za-z0-9]+)')

Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; Add-Type -AssemblyName System.Windows.Forms
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
$WALK=[System.Windows.Automation.TreeWalker]::ControlViewWalker
$CTL=[System.Windows.Automation.ControlType]
# SZYBKIE + ODPORNE: FindAll tylko dla danego typu kontrolki (silnik filtruje -> maly zbior),
# potem dopasowanie nazwy "zawiera" (bez czulosci na wielkosc liter).
function Find1($root,$ctype,$substr){ $cond=New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$ctype); foreach($e in $root.FindAll($TS::Descendants,$cond)){ $nm=(ToAscii $e.Current.Name); if($nm -match $substr){ return $e } }; return $null }

function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function EscSK($s){ $r=''; foreach($c in $s.ToCharArray()){ if('+^%~(){}[]'.Contains([string]$c)){ $r+='{'+$c+'}' } else { $r+=$c } }; return $r }
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }

function Czy-Nasz($s){ if(-not $s){return $false}; $s=$s.ToUpper(); if($NaszeWyjatki -contains $s){ return $false }; if($NaszeExact -contains $s){ return $true }; foreach($w in $NaszeWzorce){ if($s -match $w){ return $true } }; return $false }
function NaszSystem($txt){
  # wildcardy (BxP, xEW...) TYLKO z pola Application Name (pewne)
  if($txt -match '(?:#Application\s*Name|SAP\s*ERP\s*System)\s*:+\s*([A-Za-z0-9]{2,4})'){ $s=$Matches[1].ToUpper(); if(Czy-Nasz $s){ return $s } }
  # luzny skan tekstu tylko dla DOKLADNYCH nazw (zeby nie zlapac np. NEW)
  foreach($m in [regex]::Matches($txt,'\b[A-Za-z0-9]{3}\b')){ $s=$m.Value.ToUpper(); if($NaszeExact -contains $s){ return $s } }
  return $null
}
function Nastepna-Osoba{
  if($Koledzy.Count -eq 0){ return '' }
  $idx=0; if(Test-Path $PlikRotacji){ try{ $idx=[int](Get-Content $PlikRotacji -Raw) }catch{ $idx=0 } }
  $o=$Koledzy[$idx % $Koledzy.Count]; Set-Content -Path $PlikRotacji -Value (($idx+1) % $Koledzy.Count); return $o
}
function Komentarz-Tresc($braki){
  $p=@(); if($braki -contains 'system'){ $p+='the SAP system (e.g. P50)' }; if($braki -contains 'user'){ $p+='the user ID (e.g. M0123456)' }; if($braki -contains 'role'){ $p+='the role(s) required' }
  if($p.Count -eq 0){ return '' }
  return ('Hi, please provide '+($p -join ' and ')+'. Thanks.')
}
function Wykryj-Systemy($txt){ $up=$txt.ToUpper(); $found=@(); foreach($s in $ZnaneSystemy){ if($up -match ('\b'+[regex]::Escape($s)+'\b')){ $found+=$s } }; return $found }
function Zespol-Dla($txt){
  $low=$txt.ToLower(); $sys=@(Wykryj-Systemy $txt)
  foreach($r in $Reguly){
    if($r.T -and ($low -notmatch $r.T)){ continue }
    if($r.S -and -not (@($sys | Where-Object { $r.S -contains $_ }).Count)){ continue }
    if($r.X -and (@($sys | Where-Object { $r.X -contains $_ }).Count)){ continue }
    return [pscustomobject]@{ Team=$r.Team; Regula=$r.N; Sys=$sys }
  }
  return [pscustomobject]@{ Team=''; Regula=''; Sys=$sys }
}

function Przetworz($txt){
 $mars=[bool]($txt -match '\bMARS\b')
 $nasz=NaszSystem $txt
 if($mars -or $nasz){ $team=''; $system=$(if($nasz){$nasz}elseif($mars){'MARS'}else{''}); $regula=$(if($mars){'MARS'}else{'NASZE'}); $czyNasz=$true }
 else{
   $zd=Zespol-Dla $txt; $team=$zd.Team; $system=($zd.Sys -join ','); $regula=$zd.Regula; $czyNasz=$false
   if(-not $system){ foreach($e in $Etykiety){ if($txt -match $e){ $system=$Matches[1].ToUpper(); break } } }
 }
 $role=@()
 foreach($m in [regex]::Matches($txt,'\bZ[A-Z0-9]+-[A-Z0-9_]+\b','IgnoreCase')){ $r=$m.Value.ToUpper(); if($role -notcontains $r){$role+=$r} }
 foreach($m in [regex]::Matches($txt,'Business\s*Role\s*:+\s*([^\r\n]+)','IgnoreCase')){ $v=$m.Groups[1].Value.Trim(); if($v -and ($role -notcontains $v)){ $role+=$v } }
 $userName=''; if($txt -match '(?:#User\s*Full\s*Name|Full\s*Name)\s*:+\s*([^\r\n]+)'){ $userName=$Matches[1].Trim() }
 $userId=''; if($txt -match '\b[EM]\d{7}\b'){ $userId=$Matches[0] }
 $refUser=[bool]($txt -match 'reference user|\bref\.?\s*user\b|copy (the )?access from|copy from user|copy roles from|same (access|rights|roles) as|access like|like user\b')
 return [pscustomobject]@{ System=$system; Team=$team; Nasz=$czyNasz; Mars=$mars; Regula=$regula; Role=$role; RefUser=$refUser; UserName=$userName; UserId=$userId } }

function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }
function Get-ViewDetails($win){ $l=@(); foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if( ($nm -match 'wyswietl' -and $nm -match 'szczeg') -or ($nm -match 'view' -and $nm -match 'detail') ){ $l+=$e } }; return $l }
# klucz = STABILNE ID zgloszenia z wiersza (np. WO0000012345); fallback: caly tekst
function Get-RowKey($btn){ $node=$btn; for($k=0;$k -lt 8;$k++){ $p=$WALK.GetParent($node); if(-not $p){ break }; $node=$p; $rr=$node.Current.BoundingRectangle; if($rr.Width -ge 400 -and $rr.Height -le 140){ break } }; $t=''; foreach($d in $node.FindAll($TS::Descendants,$TRUE1)){ $nm=$d.Current.Name; if($nm){ $t+=$nm+' ' } }; $m=[regex]::Match($t,'\b[A-Z]{1,4}\d{8,}\b'); if($m.Success){ return $m.Value }; return ($t -replace '\s+',' ').Trim() }
function Find-El($win,[string[]]$musi){ foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ $nm=(ToAscii $e.Current.Name).ToLower(); if(-not $nm){continue}; $ok=$true; foreach($m in $musi){ if($nm -notmatch $m){ $ok=$false; break } }; if($ok){ return $e } }; return $null }
function Klik-XY($x,$y){ [Win]::Click([int]$x,[int]$y) }
function Klik-El($el){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ return $false }; [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); return $true }
function Front($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 350 }
function Do-Widoku($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{} }
function Przewin-Dol($vd){ if($vd.Count -gt 0){ $r=$vd[$vd.Count-1].Current.BoundingRectangle; [Win]::Wheel([int]($r.X+$r.Width/2),[int]($r.Y),-700) } }
function Zapewnij-Widok($el){ try{ ($el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)).ScrollIntoView() }catch{}; Start-Sleep -Milliseconds 500; $sw=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width; $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; $wx=[int]($sw/2); $wy=[int]($sh/2); for($k=0;$k -lt 14;$k++){ $r=$el.Current.BoundingRectangle; if($r.Width -le 0){ Start-Sleep -Milliseconds 300; continue }; $cy=$r.Y+$r.Height/2; if($cy -gt 120 -and $cy -lt ($sh-200)){ break }; if($cy -ge ($sh-200)){ [Win]::Wheel($wx,$wy,-400) } else { [Win]::Wheel($wx,$wy,400) }; Start-Sleep -Milliseconds 400 } }
function Find-ClearX($win,$field){ $fr=$field.Current.BoundingRectangle; foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){ if($e.Current.ControlType.ProgrammaticName -notmatch 'Button'){ continue }; $br=$e.Current.BoundingRectangle; if($br.Width -le 0 -or $br.Width -gt 45){ continue }; if([Math]::Abs(($br.Y+$br.Height/2)-($fr.Y+$fr.Height/2)) -lt 22 -and $br.X -ge ($fr.X-5) -and $br.X -le ($fr.X+$fr.Width+70)){ return $e } }; return $null }
function Kopiuj-Strone($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 350; [System.Windows.Forms.SendKeys]::SendWait('{TAB}'); Start-Sleep -Milliseconds 250; [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 200; [System.Windows.Forms.SendKeys]::SendWait('^c'); Start-Sleep -Milliseconds 400; return (Get-Clipboard -Raw) }
# czyta ticket = clipboard (Ctrl+A lapie tresc + komentarze). Bez skanu drzewa.
function Czytaj-Strone($win){ return (Kopiuj-Strone $win) }
function Wstecz($win){ [Win]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle)|Out-Null; Start-Sleep -Milliseconds 300; [System.Windows.Forms.SendKeys]::SendWait('%{LEFT}') }

# klik "Edit assignee" (otwiera edytor grupy/osoby)
function Klik-EditAssignee($win){
  $edit=Find1 $win $CTL::Button 'edit assignee'; if(-not $edit){ $edit=Find1 $win $CTL::Hyperlink 'edit assignee' }
  if(-not $edit){ $edit=Find1 $win $CTL::Button 'edit' }
  if($edit){ Write-Host ("   [edit] klikam '"+$edit.Current.Name+"'") -ForegroundColor DarkGray; Front $win; Klik-El $edit|Out-Null; Start-Sleep -Milliseconds 2000; return $true }
  Write-Host "   [edit] nie znalazlem 'Edit assignee'" -ForegroundColor Red; return $false
}
# znajdz pole ComboBox/Edit wg listy nazw (priorytet) z wykluczeniami; z retry
function Znajdz-PoleEx($win,$includes,$excludes){
  for($i=0;$i -lt 5;$i++){
    $cb=@($win.FindAll($TS::Descendants,(New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$CTL::ComboBox))))
    $ed=@($win.FindAll($TS::Descendants,(New-Object System.Windows.Automation.PropertyCondition($AE::ControlTypeProperty,$CTL::Edit))))
    $all=$cb+$ed
    foreach($inc in $includes){ foreach($e in $all){ $nm=(ToAscii $e.Current.Name).ToLower(); if($nm -match $inc){ $bad=$false; foreach($x in $excludes){ if($x -and ($nm -match $x)){ $bad=$true; break } }; if(-not $bad){ return $e } } } }
    Start-Sleep -Milliseconds 700
  }
  return $null
}
# przewin do pola, wyczysc (Ctrl+A+Del), wpisz, wybierz z podpowiedzi
function Wpisz-Combo($win,$target,$wartosc){
  Front $win
  Zapewnij-Widok $target
  $fr=$target.Current.BoundingRectangle; $cx=[int]($fr.X+$fr.Width/2); $cy=[int]($fr.Y+$fr.Height/2)
  $sh=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
  if($cy -lt 60 -or $cy -gt ($sh-90)){ Write-Host ("   [pole poza ekranem y="+$cy+" - NIE klikam (zeby nie minimalizowac)]") -ForegroundColor Red; return $false }
  Front $win
  Klik-XY $cx $cy; Start-Sleep -Milliseconds 400
  [System.Windows.Forms.SendKeys]::SendWait('^a'); Start-Sleep -Milliseconds 150; [System.Windows.Forms.SendKeys]::SendWait('{DELETE}'); Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait((EscSK $wartosc)); Start-Sleep -Milliseconds 1300
  [System.Windows.Forms.SendKeys]::SendWait('{DOWN}'); Start-Sleep -Milliseconds 300
  [System.Windows.Forms.SendKeys]::SendWait('{ENTER}'); Start-Sleep -Milliseconds 300
}

# AKCJA: Edit assignee -> pole "Support group" -> wpisz $grupa (nie zapisuje). Zwraca $true.
function Akcja-Grupa($win,$grupa){
  Klik-EditAssignee $win | Out-Null
  $t=Znajdz-PoleEx $win @('assignee support group','support group') @('manager')
  if(-not $t){ Write-Host "   [grupa] nie znalazlem pola grupy" -ForegroundColor Red; return $false }
  Wpisz-Combo $win $t $grupa
  [console]::Beep(800,200); return $true
}

# AKCJA: Edit assignee -> pole "Person" -> wpisz $osoba (nie zapisuje). Zwraca $true.
function Akcja-Osoba($win,$osoba){
  Klik-EditAssignee $win | Out-Null
  $t=Znajdz-PoleEx $win @('request assignee','\bperson\b','assignee') @('group','grupa','manager')
  if(-not $t){ Write-Host "   [osoba] nie znalazlem pola osoby (Request assignee/Person)" -ForegroundColor Red; return $false }
  Wpisz-Combo $win $t $osoba
  [console]::Beep(800,200); return $true
}

# AKCJA: wpisz komentarz $msg (nie wysyla). Zwraca $true.
function Akcja-Komentarz($win,$msg){
  Front $win
  $target=Find1 $win $CTL::Edit "New note"
  if(-not $target){ Write-Host "   [komentarz] nie znalazlem pola 'New note' - pomijam" -ForegroundColor Red; return $false }
  Zapewnij-Widok $target
  $r=$target.Current.BoundingRectangle
  $shC=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height; $cyC=[int]($r.Y+$r.Height/2)
  if($cyC -lt 60 -or $cyC -gt ($shC-90)){ Write-Host "   [komentarz poza ekranem - NIE klikam (zeby nie minimalizowac)]" -ForegroundColor Red; return $false }
  Front $win
  [Win]::Click([int]($r.X+$r.Width/2),[int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds 500
  [System.Windows.Forms.SendKeys]::SendWait((EscSK $msg)); Start-Sleep -Milliseconds 300
  if($KomentarzPublic){ $cb=Find1 $win $CTL::CheckBox "Public"; if($cb){ try{ $tp=$cb.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern); if($tp.Current.ToggleState.ToString() -ne 'On'){ Klik-El $cb|Out-Null } }catch{ Klik-El $cb|Out-Null } } }
  [console]::Beep(800,200); return $true
}
# jesli wyskoczy "You have unsaved data. Do you want to continue?" - klika Yes/Tak/Continue/OK
function Obsluz-Ostrzezenie($win){
  Start-Sleep -Milliseconds 500
  foreach($n in @('^Yes$','^Tak$','^Continue$','^OK$')){ $b=Find1 $win $CTL::Button $n; if($b){ Front $win; Klik-El $b|Out-Null; Start-Sleep -Milliseconds 700; Write-Host "   [ostrzezenie] kliknieto '$($b.Current.Name)'" -ForegroundColor DarkGray; return $true } }
  return $false
}

# popup + auto-zapis
function Zapisz-Ticket($win){ foreach($n in @('Save','Zapisz','Save changes','Save and close')){ $b=Find1 $win $CTL::Button $n; if($b){ Klik-El $b|Out-Null; return $true } }; return $false }
# wlasne okno potwierdzenia z dodatkowymi akcjami; zwraca: yes/no/cancel/comment/osoba/grupa
function Pokaz-Potwierdz($opis){
  $f=New-Object System.Windows.Forms.Form
  $f.Text='Router - potwierdz'; $f.Width=500; $f.Height=252; $f.TopMost=$true; $f.StartPosition='CenterScreen'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
  $lb=New-Object System.Windows.Forms.Label; $lb.Text=$opis; $lb.Left=16; $lb.Top=14; $lb.Width=462; $lb.Height=64; $f.Controls.Add($lb)
  $bYes=New-Object System.Windows.Forms.Button; $bYes.Text='Zapisz i dalej'; $bYes.Left=16; $bYes.Top=86; $bYes.Width=150; $bYes.Height=44; $bYes.BackColor=[System.Drawing.Color]::FromArgb(60,160,90); $bYes.ForeColor='White'
  $bNo=New-Object System.Windows.Forms.Button; $bNo.Text='Pomin (bez zapisu)'; $bNo.Left=176; $bNo.Top=86; $bNo.Width=150; $bNo.Height=44
  $bStop=New-Object System.Windows.Forms.Button; $bStop.Text='STOP'; $bStop.Left=336; $bStop.Top=86; $bStop.Width=142; $bStop.Height=44; $bStop.ForeColor='Red'
  $bKom=New-Object System.Windows.Forms.Button; $bKom.Text='Dodaj komentarz...'; $bKom.Left=16; $bKom.Top=138; $bKom.Width=150; $bKom.Height=38; $bKom.BackColor=[System.Drawing.Color]::FromArgb(150,90,190); $bKom.ForeColor='White'
  $bOso=New-Object System.Windows.Forms.Button; $bOso.Text='Przypisz osobe...'; $bOso.Left=176; $bOso.Top=138; $bOso.Width=150; $bOso.Height=38
  $bGr=New-Object System.Windows.Forms.Button; $bGr.Text='Zmien grupe...'; $bGr.Left=336; $bGr.Top=138; $bGr.Width=142; $bGr.Height=38
  $bYes.Add_Click({ $f.Tag='yes'; $f.Close() }.GetNewClosure())
  $bNo.Add_Click({ $f.Tag='no'; $f.Close() }.GetNewClosure())
  $bStop.Add_Click({ $f.Tag='cancel'; $f.Close() }.GetNewClosure())
  $bKom.Add_Click({ $f.Tag='comment'; $f.Close() }.GetNewClosure())
  $bOso.Add_Click({ $f.Tag='osoba'; $f.Close() }.GetNewClosure())
  $bGr.Add_Click({ $f.Tag='grupa'; $f.Close() }.GetNewClosure())
  $f.Controls.AddRange(@($bYes,$bNo,$bStop,$bKom,$bOso,$bGr))
  [void]$f.ShowDialog()
  $r=$f.Tag; $f.Dispose()
  if(-not $r){ return 'cancel' }
  return $r
}
function Zatwierdz($win,$opis,$saveFn,$w=$null,$braki=@(),$tkey=''){
  if(-not $TrybPopup){ Read-Host ("   >>> "+$opis+" - sprawdz, ZAPISZ recznie, ENTER"); return 'saved' }
  while($true){
    $odp=Pokaz-Potwierdz $opis
    if($odp -eq 'cancel'){ return 'stop' }
    if($odp -eq 'no'){ Write-Host "   pominieto (bez zapisu)" -ForegroundColor DarkGray; return 'skip' }
    if($odp -eq 'comment'){
      $wyb=Wybierz-Komentarz $tkey $braki $w
      if($wyb.Action -eq 'stop'){ return 'stop' }
      if($wyb.Action -eq 'comment' -and $wyb.Text){ $script:KomentarzPublic=[bool]$wyb.Public; Akcja-Komentarz $win $wyb.Text | Out-Null; Write-Host "   [dodano komentarz]" -ForegroundColor DarkGray }
      continue
    }
    if($odp -eq 'osoba'){
      $wb=@($Koledzy | ForEach-Object { $nm=$OsobyNazwy[$_]; $lab=if($nm){ "$nm ($_)" }else{ $_ }; [pscustomobject]@{ L=$lab; V=$_ } })
      $os=Wybierz-Zliste 'Przypisz osobe' 'Wybierz osobe z listy (albo wpisz ID):' $wb "$env:USERPROFILE\sap_panel_osoby.txt"
      if($os){ Akcja-Osoba $win $os | Out-Null }
      continue
    }
    if($odp -eq 'grupa'){
      $wb=@($Reguly | ForEach-Object { $_.Team } | Where-Object { $_ } | Select-Object -Unique | ForEach-Object { [pscustomobject]@{ L=$_; V=$_ } })
      $gr=Wybierz-Zliste 'Zmien grupe' 'Wybierz grupe z listy (albo wpisz nazwe):' $wb "$env:USERPROFILE\sap_panel_grupy.txt"
      if($gr){ Akcja-Grupa $win $gr | Out-Null }
      continue
    }
    # yes
    Front $win
    if(& $saveFn $win){ Write-Host "   zapisano" -ForegroundColor Green } else { Read-Host "   nie znalazlem przycisku zapisu - zrob recznie i ENTER" }
    Start-Sleep -Milliseconds 600; Obsluz-Ostrzezenie $win | Out-Null; return 'saved'
  }
}

if($mode -eq 'panel'){
  # ---- KAFELKI WBUDOWANE (akcje: grupa/osoba/komentarz) ----
  $Kafelki = @(
    @{ Text='Not our scope -> GSD'; Comment='Not our scope.'; Public=$false; Grupa='GLOBAL-SERVICEDESK'; Osoba='' }
    @{ Text='Przypisz do GSD'; Comment=''; Public=$false; Grupa='GLOBAL-SERVICEDESK'; Osoba='' }
    @{ Text='Komentarz: podaj system + user'; Comment='Hi, please provide the SAP system (e.g. P50) and the user ID (e.g. M0123456). Thanks.'; Public=$true; Grupa=''; Osoba='' }
    @{ Text='Komentarz: podaj role'; Comment='Hi, please provide the role(s) required. Thanks.'; Public=$true; Grupa=''; Osoba='' }
  )
  # ---- WLASNE KAFELKI-KOMENTARZE (Twoja lista, zapamietane miedzy uruchomieniami) ----
  $PlikKafelki = "$env:USERPROFILE\sap_panel_kafelki.txt"   # kolumny: Public,Text
  function AsBool($v){ return ($v -eq $true -or $v -eq '1' -or $v -eq 'True') }
  function Wczytaj-Kafelki{ $l=@(); if(Test-Path $PlikKafelki){ try{ $l=@(Import-Csv $PlikKafelki) }catch{ $l=@() } }; return $l }
  function Zapisz-Kafelki($lista){
    if(@($lista).Count -gt 0){ @($lista) | Select-Object Public,Text | Export-Csv -Path $PlikKafelki -NoTypeInformation -Encoding UTF8 }
    elseif(Test-Path $PlikKafelki){ Remove-Item $PlikKafelki -Force }
  }
  $script:customy = @(Wczytaj-Kafelki)

  # ---- wpisz komentarz/grupe/osobe do ticketa, potem zapytaj o zapis ----
  function Zastosuj($comment,$public,$grupa,$osoba){
    $win=Get-EdgeWindow; if(-not $win){ [System.Windows.Forms.MessageBox]::Show('Nie znalazlem okna Edge.') | Out-Null; return }
    $pf.WindowState='Minimized'; [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 500   # zejdz z drogi, oddaj fokus Edge
    try{
      if($comment){ $script:KomentarzPublic=[bool]$public; Akcja-Komentarz $win $comment | Out-Null }
      if($grupa){ Akcja-Grupa $win $grupa | Out-Null }
      if($osoba){ Akcja-Osoba $win $osoba | Out-Null }
      # z komentarzem: NIE zapisuj od razu - zapytaj (zapisac i dalej / zostaw)
      if($comment){
        $pf.WindowState='Normal'; $pf.TopMost=$true; $pf.Activate()
        $odp=[System.Windows.Forms.MessageBox]::Show("Komentarz wpisany.`n`nTAK = zapisz i przejdz do nastepnego ticketa`nNIE = zostaw niezapisane (sprawdze recznie)","Panel - potwierdz",'YesNo','Question')
        if($odp -ne 'Yes'){ Write-Host "   pominieto zapis (Twoj wybor)" -ForegroundColor DarkGray; return }
        $pf.WindowState='Minimized'; [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 500
      }
      Zapisz-Ticket $win | Out-Null; Start-Sleep -Milliseconds 700; Obsluz-Ostrzezenie $win | Out-Null
    } finally { $pf.WindowState='Normal'; $pf.TopMost=$true; $pf.Activate() }
    [console]::Beep(800,200)
  }

  $pf=New-Object System.Windows.Forms.Form
  $pf.Text='Ticket Panel'; $pf.Width=340; $pf.TopMost=$true; $pf.StartPosition='Manual'; $pf.Location=New-Object System.Drawing.Point(20,20); $pf.FormBorderStyle='FixedSingle'; $pf.ControlBox=$true; $pf.MaximizeBox=$false; $pf.MinimizeBox=$false
  $pf.Add_Shown({ $pf.TopMost=$true; $pf.Activate(); $pf.BringToFront() })

  # trwale kontrolki sekcji "wlasny komentarz" (tworzone raz, pozycjonowane przy kazdej przebudowie)
  $lbl=New-Object System.Windows.Forms.Label; $lbl.Text='Nowy komentarz (dodaj jako kafelek):'; $lbl.Width=300; $lbl.Height=18
  $tb=New-Object System.Windows.Forms.TextBox; $tb.Multiline=$true; $tb.Width=300; $tb.Height=60
  $cbPub=New-Object System.Windows.Forms.CheckBox; $cbPub.Text='Public (widzi zglaszajacy)'; $cbPub.Width=280
  $bApply=New-Object System.Windows.Forms.Button; $bApply.Text='Zastosuj teraz (bez zapisu na liste)'; $bApply.Width=300; $bApply.Height=32
  $bAddTile=New-Object System.Windows.Forms.Button; $bAddTile.Text='+ Dodaj jako kafelek'; $bAddTile.Width=300; $bAddTile.Height=34; $bAddTile.BackColor=[System.Drawing.Color]::FromArgb(150,90,190); $bAddTile.ForeColor='White'
  $bClose=New-Object System.Windows.Forms.Button; $bClose.Text='Zamknij'; $bClose.Width=300; $bClose.Height=30
  $bApply.Add_Click({ if([string]::IsNullOrWhiteSpace($tb.Text)){ [System.Windows.Forms.MessageBox]::Show('Wpisz tresc komentarza.') | Out-Null; return }; $this.Enabled=$false; try{ Zastosuj $tb.Text $cbPub.Checked '' '' }finally{ $this.Enabled=$true } })
  $bAddTile.Add_Click({
    if([string]::IsNullOrWhiteSpace($tb.Text)){ [System.Windows.Forms.MessageBox]::Show('Wpisz tresc komentarza.') | Out-Null; return }
    $nowy=[pscustomobject]@{ Public=$(if($cbPub.Checked){'1'}else{'0'}); Text=$tb.Text.Trim() }
    $script:customy=@($script:customy)+$nowy
    Zapisz-Kafelki $script:customy
    $tb.Clear(); $cbPub.Checked=$false
    BudujPanel
  })
  $bClose.Add_Click({ $pf.Close() })

  # przebuduj caly uklad (wbudowane kafelki + wlasne + sekcja dodawania)
  function BudujPanel{
    $pf.SuspendLayout()
    $pf.Controls.Clear()
    $yy=12
    # -- wbudowane akcje --
    foreach($k in $Kafelki){
      $hasCom=[bool]$k.Comment
      $b=New-Object System.Windows.Forms.Button; $b.Text=$k.Text; $b.Left=12; $b.Top=$yy; $b.Height=44; $b.AutoEllipsis=$true
      if($hasCom){
        $b.Width=214
        $chk=New-Object System.Windows.Forms.CheckBox; $chk.Text='Public'; $chk.Left=232; $chk.Top=($yy+13); $chk.Width=88; $chk.Checked=(AsBool $k.Public)
        $pf.Controls.Add($chk)
        $t=$k; $c=$chk; $btn=$b
        $b.Add_Click({ $btn.Enabled=$false; try{ Zastosuj $t.Comment $c.Checked $t.Grupa $t.Osoba }finally{ $btn.Enabled=$true } }.GetNewClosure())
      } else {
        $b.Width=308
        $t=$k; $btn=$b
        $b.Add_Click({ $btn.Enabled=$false; try{ Zastosuj $t.Comment $false $t.Grupa $t.Osoba }finally{ $btn.Enabled=$true } }.GetNewClosure())
      }
      $pf.Controls.Add($b); $yy+=50
    }
    # -- Twoje wlasne kafelki-komentarze --
    if(@($script:customy).Count -gt 0){
      $sep=New-Object System.Windows.Forms.Label; $sep.Text='--- Twoje kafelki ---'; $sep.Left=12; $sep.Top=$yy; $sep.Width=300; $sep.Height=16; $sep.ForeColor='Gray'; $pf.Controls.Add($sep); $yy+=20
    }
    foreach($k in @($script:customy)){
      $etyk=$k.Text; if($etyk.Length -gt 60){ $etyk=$etyk.Substring(0,57)+'...' }
      $b=New-Object System.Windows.Forms.Button; $b.Text=$etyk; $b.Left=12; $b.Top=$yy; $b.Width=170; $b.Height=44; $b.AutoEllipsis=$true
      $chk=New-Object System.Windows.Forms.CheckBox; $chk.Text='Public'; $chk.Left=188; $chk.Top=($yy+13); $chk.Width=88; $chk.Checked=(AsBool $k.Public)
      $del=New-Object System.Windows.Forms.Button; $del.Text='X'; $del.Left=278; $del.Top=$yy; $del.Width=42; $del.Height=44; $del.ForeColor='Red'
      $t=$k; $c=$chk; $btn=$b
      $b.Add_Click({ $btn.Enabled=$false; try{ Zastosuj $t.Text $c.Checked '' '' }finally{ $btn.Enabled=$true } }.GetNewClosure())
      $del.Add_Click({ $script:customy=@(@($script:customy) | Where-Object { $_ -ne $t }); Zapisz-Kafelki $script:customy; BudujPanel }.GetNewClosure())
      $pf.Controls.Add($b); $pf.Controls.Add($chk); $pf.Controls.Add($del); $yy+=50
    }
    # -- sekcja: nowy komentarz -> dodaj jako kafelek --
    $yy+=8
    $lbl.Left=12;     $lbl.Top=$yy;     $pf.Controls.Add($lbl);     $yy+=20
    $tb.Left=12;      $tb.Top=$yy;      $pf.Controls.Add($tb);      $yy+=66
    $cbPub.Left=12;   $cbPub.Top=$yy;   $pf.Controls.Add($cbPub);   $yy+=26
    $bApply.Left=12;  $bApply.Top=$yy;  $pf.Controls.Add($bApply);  $yy+=38
    $bAddTile.Left=12;$bAddTile.Top=$yy;$pf.Controls.Add($bAddTile);$yy+=40
    $bClose.Left=12;  $bClose.Top=$yy;  $pf.Controls.Add($bClose);  $yy+=38
    $pf.ClientSize=New-Object System.Drawing.Size(324,$yy)
    $pf.ResumeLayout()
  }

  BudujPanel
  [void]$pf.ShowDialog()
  return
}

# ---------------- OKNO WYBORU KOMENTARZA (auto: NASZE niekompletne) ----------------
# Nie wkleja komentarza automatem. Pokazuje liste propozycji (w tym Twoje wlasne kafelki
# z panelu) + pole do edycji + Public. Zwraca Action = comment/none/stop.
function Wybierz-Komentarz($tkey,$braki,$w){
  $PlikKafelki="$env:USERPROFILE\sap_panel_kafelki.txt"
  $opcje=New-Object System.Collections.ArrayList
  $sug=Komentarz-Tresc $braki
  if($sug){ [void]$opcje.Add([pscustomobject]@{ L='Sugerowany (wg brakow)'; Text=$sug; Public=$true }) }
  if(-not $w.RefUser){ [void]$opcje.Add([pscustomobject]@{ L='Zapytaj o reference user'; Text='Hi, please provide the reference user (the account whose access should be copied). Thanks.'; Public=$true }) }
  [void]$opcje.Add([pscustomobject]@{ L='Podaj system + user'; Text='Hi, please provide the SAP system (e.g. P50) and the user ID (e.g. M0123456). Thanks.'; Public=$true })
  [void]$opcje.Add([pscustomobject]@{ L='Podaj role (lub reference user)'; Text='Hi, please provide the role(s) required, or a reference user to copy access from. Thanks.'; Public=$true })
  if(Test-Path $PlikKafelki){ try{ foreach($c in @(Import-Csv $PlikKafelki)){ if($c.Text){ [void]$opcje.Add([pscustomobject]@{ L=('[moj] '+$c.Text); Text=$c.Text; Public=($c.Public -eq '1') }) } } }catch{} }

  $f=New-Object System.Windows.Forms.Form
  $f.Text=('Komentarz - '+$tkey); $f.Width=560; $f.Height=440; $f.TopMost=$true; $f.StartPosition='CenterScreen'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
  $info=New-Object System.Windows.Forms.Label; $info.Text=('Ticket NASZE, niekompletny. Braki: '+($braki -join ', ')+'.  Wybierz komentarz (albo bez).'); $info.Left=12; $info.Top=10; $info.Width=524; $info.Height=32; $f.Controls.Add($info)
  $lst=New-Object System.Windows.Forms.ListBox; $lst.Left=12; $lst.Top=46; $lst.Width=524; $lst.Height=140; foreach($o in $opcje){ [void]$lst.Items.Add($o.L) }; $f.Controls.Add($lst)
  $txt=New-Object System.Windows.Forms.TextBox; $txt.Multiline=$true; $txt.Left=12; $txt.Top=194; $txt.Width=524; $txt.Height=84; $txt.ScrollBars='Vertical'; $f.Controls.Add($txt)
  $cbPub=New-Object System.Windows.Forms.CheckBox; $cbPub.Text='Public (widzi zglaszajacy)'; $cbPub.Left=12; $cbPub.Top=286; $cbPub.Width=240; $cbPub.Checked=$true; $f.Controls.Add($cbPub)
  $bSave=New-Object System.Windows.Forms.Button; $bSave.Text='+ Zapisz na liste (kafelek)'; $bSave.Left=270; $bSave.Top=282; $bSave.Width=266; $bSave.Height=30; $f.Controls.Add($bSave)
  $lst.Add_SelectedIndexChanged({ $i=$lst.SelectedIndex; if($i -ge 0 -and $i -lt $opcje.Count){ $txt.Text=$opcje[$i].Text; $cbPub.Checked=[bool]$opcje[$i].Public } }.GetNewClosure())
  if($opcje.Count -gt 0){ $lst.SelectedIndex=0 }
  $bSave.Add_Click({
    if([string]::IsNullOrWhiteSpace($txt.Text)){ [System.Windows.Forms.MessageBox]::Show('Wpisz tresc komentarza.') | Out-Null; return }
    $nowy=[pscustomobject]@{ Public=$(if($cbPub.Checked){'1'}else{'0'}); Text=$txt.Text.Trim() }
    $ex=@(); if(Test-Path $PlikKafelki){ try{ $ex=@(Import-Csv $PlikKafelki) }catch{} }
    @($ex+$nowy) | Select-Object Public,Text | Export-Csv -Path $PlikKafelki -NoTypeInformation -Encoding UTF8
    $o=[pscustomobject]@{ L=('[moj] '+$nowy.Text); Text=$nowy.Text; Public=($nowy.Public -eq '1') }
    [void]$opcje.Add($o); [void]$lst.Items.Add($o.L); $lst.SelectedIndex=$lst.Items.Count-1
    [console]::Beep(800,150)
  }.GetNewClosure())
  $bAdd=New-Object System.Windows.Forms.Button; $bAdd.Text='Dodaj wybrany komentarz'; $bAdd.Left=12; $bAdd.Top=340; $bAdd.Width=250; $bAdd.Height=38; $bAdd.BackColor=[System.Drawing.Color]::FromArgb(46,120,210); $bAdd.ForeColor='White'
  $bNone=New-Object System.Windows.Forms.Button; $bNone.Text='Bez komentarza (tylko osoba)'; $bNone.Left=272; $bNone.Top=340; $bNone.Width=190; $bNone.Height=38
  $bStop=New-Object System.Windows.Forms.Button; $bStop.Text='STOP'; $bStop.Left=470; $bStop.Top=340; $bStop.Width=66; $bStop.Height=38; $bStop.ForeColor='Red'
  $bAdd.Add_Click({ $f.Tag=[pscustomobject]@{ Action='comment'; Text=$txt.Text; Public=$cbPub.Checked }; $f.Close() }.GetNewClosure())
  $bNone.Add_Click({ $f.Tag=[pscustomobject]@{ Action='none' }; $f.Close() }.GetNewClosure())
  $bStop.Add_Click({ $f.Tag=[pscustomobject]@{ Action='stop' }; $f.Close() }.GetNewClosure())
  $f.Controls.Add($bAdd); $f.Controls.Add($bNone); $f.Controls.Add($bStop)
  [void]$f.ShowDialog()
  $rr=$f.Tag; $f.Dispose()
  if(-not $rr){ return [pscustomobject]@{ Action='none' } }
  return $rr
}

# ---------------- WYBOR Z LISTY (grupa / osoba) z zapisem wlasnych ----------------
# $wbudowane = tablica @{ L=etykieta; V=wartosc }. $plik = CSV (kolumna V) z wlasnymi.
# Zwraca wybrana wartosc (string) albo '' gdy anulowano.
function Wybierz-Zliste($tytul,$naglowek,$wbudowane,$plik){
  $opcje=New-Object System.Collections.ArrayList
  foreach($o in $wbudowane){ [void]$opcje.Add($o) }
  if($plik -and (Test-Path $plik)){ try{ foreach($c in @(Import-Csv $plik)){ if($c.V){ [void]$opcje.Add([pscustomobject]@{ L=('[moj] '+$c.V); V=$c.V }) } } }catch{} }

  $f=New-Object System.Windows.Forms.Form
  $f.Text=$tytul; $f.Width=520; $f.Height=420; $f.TopMost=$true; $f.StartPosition='CenterScreen'; $f.FormBorderStyle='FixedDialog'; $f.MaximizeBox=$false; $f.MinimizeBox=$false
  $info=New-Object System.Windows.Forms.Label; $info.Text=$naglowek; $info.Left=12; $info.Top=10; $info.Width=486; $info.Height=20; $f.Controls.Add($info)
  $lst=New-Object System.Windows.Forms.ListBox; $lst.Left=12; $lst.Top=36; $lst.Width=486; $lst.Height=210; foreach($o in $opcje){ [void]$lst.Items.Add($o.L) }; $f.Controls.Add($lst)
  $txt=New-Object System.Windows.Forms.TextBox; $txt.Left=12; $txt.Top=256; $txt.Width=360; $txt.Height=26; $f.Controls.Add($txt)
  $bSave=New-Object System.Windows.Forms.Button; $bSave.Text='+ Zapisz'; $bSave.Left=382; $bSave.Top=254; $bSave.Width=116; $bSave.Height=28; $f.Controls.Add($bSave)
  $lst.Add_SelectedIndexChanged({ $i=$lst.SelectedIndex; if($i -ge 0 -and $i -lt $opcje.Count){ $txt.Text=$opcje[$i].V } }.GetNewClosure())
  if($opcje.Count -gt 0){ $lst.SelectedIndex=0 }
  $bSave.Add_Click({
    if([string]::IsNullOrWhiteSpace($txt.Text) -or -not $plik){ return }
    $nowy=[pscustomobject]@{ V=$txt.Text.Trim() }
    $ex=@(); if(Test-Path $plik){ try{ $ex=@(Import-Csv $plik) }catch{} }
    @($ex+$nowy) | Select-Object V | Export-Csv -Path $plik -NoTypeInformation -Encoding UTF8
    $o=[pscustomobject]@{ L=('[moj] '+$nowy.V); V=$nowy.V }
    [void]$opcje.Add($o); [void]$lst.Items.Add($o.L); $lst.SelectedIndex=$lst.Items.Count-1
    [console]::Beep(800,150)
  }.GetNewClosure())
  $bOk=New-Object System.Windows.Forms.Button; $bOk.Text='Wybierz'; $bOk.Left=12; $bOk.Top=298; $bOk.Width=242; $bOk.Height=42; $bOk.BackColor=[System.Drawing.Color]::FromArgb(46,120,210); $bOk.ForeColor='White'
  $bCancel=New-Object System.Windows.Forms.Button; $bCancel.Text='Anuluj'; $bCancel.Left=262; $bCancel.Top=298; $bCancel.Width=236; $bCancel.Height=42
  $bOk.Add_Click({ $f.Tag=$txt.Text.Trim(); $f.Close() }.GetNewClosure())
  $bCancel.Add_Click({ $f.Tag=''; $f.Close() }.GetNewClosure())
  $f.Controls.Add($bOk); $f.Controls.Add($bCancel)
  [void]$f.ShowDialog()
  $r=$f.Tag; $f.Dispose()
  if(-not $r){ return '' }
  return [string]$r
}

# --- Start ---
Clear-Host
Write-Host "SAP Ticket Router - PELNY (routing do zespolow)" -ForegroundColor Cyan
$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem okna Edge." -ForegroundColor Red; return }
$vd=Get-ViewDetails $win; Write-Host ("Widocznych na starcie: "+$vd.Count) -ForegroundColor Green
if($vd.Count -eq 0){ Write-Host "Brak 'View Details'." -ForegroundColor Red; return }
for($c=6;$c -ge 1;$c--){ Write-Host ("Start za "+$c+"s - zostaw myszke...") -ForegroundColor Yellow; Start-Sleep -Seconds 1 }

$routed=0; $nasze=0; $commented=0; $waiting=0; $powroty=0; $doReki=@(); $seen=@{}; $stall=0; $nr=0; $wyniki=@()
$historia=@{}
if(Test-Path $PlikHistoria){
  $keep=@()
  foreach($l in Get-Content $PlikHistoria){
    $l=$l.Trim(); if(-not $l){ continue }
    $p=$l -split ';',2; $id=$p[0]; $data=if($p.Count -gt 1){ $p[1] } else { '' }
    $stary=$false
    if($HistoriaDni -gt 0 -and $data){ try{ if(((Get-Date)-[datetime]$data).TotalDays -gt $HistoriaDni){ $stary=$true } }catch{} }
    if(-not $stary){ $historia[$id]=1; $keep+=$l }
  }
  Set-Content -Path $PlikHistoria -Value $keep -Encoding UTF8   # przytnij stare
}
Write-Host ("Historia odeslanych: "+$historia.Count+" numerow (pamiec: "+$(if($HistoriaDni -gt 0){$HistoriaDni.ToString()+' dni'}else{'bez limitu'})+")") -ForegroundColor DarkGray

while($stall -lt 4 -and $seen.Count -lt $MaxTicketow){
  $win=Get-EdgeWindow; $vd=Get-ViewDetails $win
  if($vd.Count -eq 0){ Start-Sleep -Milliseconds 1200; $stall++; continue }
  $target=$null; $tkey=$null
  foreach($btn in $vd){ $key=Get-RowKey $btn; if($key -and -not $seen.ContainsKey($key)){ $target=$btn; $tkey=$key; break } }
  if(-not $target){ Write-Host "Widoczne zrobione - przewijam..." -ForegroundColor DarkGray; Przewin-Dol $vd; Start-Sleep -Milliseconds 900; $stall++; continue }
  $seen[$tkey]=1; $stall=0; $nr++
  Do-Widoku $target; Start-Sleep -Milliseconds 300
  $r=$target.Current.BoundingRectangle; if($r.Width -le 0){ continue }
  Front $win
  Klik-XY ([int]($r.X+$r.Width/2)) ([int]($r.Y+$r.Height/2)); Start-Sleep -Milliseconds $CzasLadowania

  $win=Get-EdgeWindow; $txt=Czytaj-Strone $win; $w=Przetworz $txt
  $haslo=[bool]($txt -match 'password|passwort|haslo|hasla'); $brakSys=[string]::IsNullOrEmpty($w.System); $brakUser=[string]::IsNullOrEmpty($w.UserId); $brakRole=(($w.Role.Count -eq 0) -and (-not $w.RefUser) -and (-not $haslo))
  $brakiAll=@(); if($brakSys){$brakiAll+='system'}; if($brakUser){$brakiAll+='user'}; if($brakRole){$brakiAll+='role'}
  $juzPytano = ($txt -match 'please provide')
  $powrot = $historia.ContainsKey($tkey)
  $skipWaiting = $false
  if((-not $powrot) -and $juzPytano -and $PomijajJuzPytane){
    $o=[System.Windows.Forms.MessageBox]::Show("Ticket "+$tkey+" - juz pytano/robione.`n`nTAK = pomin     NIE = przetworz mimo to     ANULUJ = STOP","Router - juz pytano",'YesNoCancel','Question')
    if($o -eq 'Cancel'){ break }
    if($o -eq 'Yes'){ $skipWaiting=$true }
  }
  $akcja=''
  if($powrot){
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  !!! POWROT - ten ticket juz byl odeslany! Cos nie tak - SPRAWDZ RECZNIE") -ForegroundColor Red
    [console]::Beep(400,400); $akcja='POWROT'; $powroty++
  }elseif($skipWaiting){
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  JUZ PYTANO - pominiete (Twoj wybor)") -ForegroundColor DarkYellow
    $akcja='waiting'; $waiting++
  }elseif($w.Nasz){
    if($w.Mars){
      $osoba=$Kinga
      Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  MARS -> Kinga ("+$osoba+")") -ForegroundColor Cyan
      $win=Get-EdgeWindow; Akcja-Osoba $win $osoba | Out-Null
      $rz=Zatwierdz $win ("MARS - przypisac do Kingi ("+$osoba+")?") { param($ww) Zapisz-Ticket $ww } $w $brakiAll $tkey
      if($rz -eq 'stop'){ break }
      if($rz -ne 'skip'){ $akcja='mars'; $nasze++ }
    }else{
      $braki=@(); if($brakUser){$braki+='user'}; if($brakRole){$braki+='role'}
      $osoba=Nastepna-Osoba
      if($braki.Count -eq 0){
        Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  NASZE KOMPLETNY -> "+$osoba) -ForegroundColor Cyan
        if($w.Role.Count -gt 0){ Write-Host ("   ROLE: "+($w.Role -join ', ')) }
        $win=Get-EdgeWindow; Akcja-Osoba $win $osoba | Out-Null
        $rz=Zatwierdz $win ("Przypisac do "+$osoba+"?") { param($ww) Zapisz-Ticket $ww } $w $brakiAll $tkey
        if($rz -eq 'stop'){ break }
        if($rz -ne 'skip'){ $akcja='nasz-complete'; $nasze++ }
      }else{
        Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  NASZE NIEKOMPLETNY (brak: "+($braki -join '+')+") -> "+$osoba) -ForegroundColor Yellow
        $win=Get-EdgeWindow; Akcja-Osoba $win $osoba | Out-Null       # NAJPIERW osoba, komentarz w oknie potwierdzenia
        $rz=Zatwierdz $win ("Przypisz do "+$osoba+" (brak: "+($braki -join '+')+"). Dodaj komentarz i zapisz?") { param($ww) Zapisz-Ticket $ww } $w $brakiAll $tkey
        if($rz -eq 'stop'){ break }
        if($rz -ne 'skip'){ $nasze++ }
        $akcja='nasz-incomplete'
      }
    }
  }elseif($w.Team){
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  -> "+$w.Team+"  ["+$w.Regula+"]") -ForegroundColor Green
    if($w.Role.Count -gt 0){ Write-Host ("   ROLE: "+($w.Role -join ', ')) }
    Write-Host ("   AKCJA: przypisz do "+$w.Team) -ForegroundColor Yellow
    $win=Get-EdgeWindow
    if(Akcja-Grupa $win $w.Team){ $rz=Zatwierdz $win ("Przypisac grupe: "+$w.Team+"?") { param($ww) Zapisz-Ticket $ww } $w $brakiAll $tkey; if($rz -eq 'stop'){ break }; if($rz -ne 'skip'){ $akcja='assign'; $routed++; $historia[$tkey]=1; Add-Content -Path $PlikHistoria -Value ($tkey+';'+(Get-Date -Format 'yyyy-MM-dd')) } else { $akcja='assign-skip' } }
  }elseif($brakSys){
    $msg=Komentarz-Tresc @('system')
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  BRAK systemu -> KOMENTARZ") -ForegroundColor Magenta
    $win=Get-EdgeWindow; Akcja-Komentarz $win $msg | Out-Null
    $rz=Zatwierdz $win ("Komentarz (podaj system) - zapisac?") { param($ww) Zapisz-Ticket $ww } $w $brakiAll $tkey
    if($rz -eq 'stop'){ break }
    if($rz -ne 'skip'){ $akcja='comment'; $commented++ }
  }else{
    Write-Host ("--- Ticket #"+$nr+" ("+$tkey+")  SYSTEM="+$w.System+"  DO_SPRAWDZENIA") -ForegroundColor Red
    $doReki += ("#"+$nr+" "+$tkey); $akcja='skip'
  }
  $wyniki += [pscustomobject]@{ Czas=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); Ticket=$tkey; System=$w.System; Team=$w.Team; Regula=$w.Regula; Akcja=$akcja; Braki=($brakiAll -join '+'); User=$w.UserName; UserId=$w.UserId; Role=($w.Role -join ';') }

  $win=Get-EdgeWindow; Wstecz $win; Start-Sleep -Milliseconds 700; $win=Get-EdgeWindow; Obsluz-Ostrzezenie $win; Start-Sleep -Milliseconds $CzasListy
}

Write-Host ""; Write-Host "=========== PODSUMOWANIE ===========" -ForegroundColor Cyan
Write-Host ("Przetworzone : "+$nr)
Write-Host ("NASZE (osoba): "+$nasze) -ForegroundColor Cyan
Write-Host ("Zroutowane   : "+$routed) -ForegroundColor Green
Write-Host ("Komentarze   : "+$commented) -ForegroundColor Magenta
Write-Host ("Czeka (juz pytano): "+$waiting) -ForegroundColor DarkYellow
Write-Host ("POWROTY (!)  : "+$powroty) -ForegroundColor Red
Write-Host ("DO_SPRAWDZENIA: "+$doReki.Count) -ForegroundColor Red
if($doReki.Count -gt 0){ $doReki | ForEach-Object { Write-Host ("  - "+$_) } }
if($wyniki.Count -gt 0){ $wyniki | Export-Csv -Path $PlikLogu -NoTypeInformation -Encoding UTF8 }
Write-Host ("Log: "+$PlikLogu) -ForegroundColor DarkGray; Write-Host "====================================" -ForegroundColor Cyan
