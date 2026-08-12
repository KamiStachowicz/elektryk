# ============================================================
#  DUMPER pol - pokazuje jak wygląda pole "Assignee support group"
#  (i inne pola) w drzewie UIA. Odpal na OTWARTYM tickecie.
#  Nic nie zmienia. Wynik: wklej mi / zrzut ekranu.
# ============================================================
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function Get-Val($e){ try{ $vp=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); return $vp.Current.Value }catch{ return $null } }
function Get-EdgeWindow{ foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Edge'){ return $w } }; return $null }

$win=Get-EdgeWindow; if(-not $win){ Write-Host "Nie znalazlem Edge." -ForegroundColor Red; return }

Write-Host "=== POLA POWIAZANE Z GRUPA/ASSIGNEE ===" -ForegroundColor Cyan
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $nm=$e.Current.Name; $val=Get-Val $e; $hay=((ToAscii ($nm+' '+$val))).ToLower()
  if($hay -match 'tools-access|assignee|support group|grupa|przypisan|request assignee'){
    $ct=$e.Current.ControlType.ProgrammaticName
    Write-Host ("["+$ct+"] name='"+$nm+"' val='"+$val+"'") -ForegroundColor Yellow
  }
}

Write-Host ""; Write-Host "=== WSZYSTKIE POLA EDIT/COMBOBOX ===" -ForegroundColor Cyan
$i=0
foreach($e in $win.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -match 'Edit|ComboBox'){
    $r=$e.Current.BoundingRectangle
    Write-Host ("["+$ct+"] name='"+$e.Current.Name+"' val='"+(Get-Val $e)+"' x="+[int]$r.X+" y="+[int]$r.Y)
    $i++; if($i -ge 80){ break }
  }
}
Write-Host ("Razem Edit/ComboBox: "+$i) -ForegroundColor DarkGray
