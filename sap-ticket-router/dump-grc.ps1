# ============================================================
#  DUMPER GRC v2 - WSZYSTKIE pola Edit/ComboBox (tez puste) z indeksem i pozycja Y
#  Odpal na stronie "Access Request". Nic nie zmienia.
# ============================================================
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
function GVal($e){ try{ ($e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value }catch{ $null } }
function SafeXY($r){ try{ if([double]::IsInfinity($r.X)){ return '(poza)' }; return ('x='+[int]$r.X+' y='+[int]$r.Y) }catch{ return '(?)' } }
$grc=$null; foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Access Request'){ $grc=$w; break } }
if(-not $grc){ Write-Host "Nie znalazlem okna 'Access Request'." -ForegroundColor Red; return }
Write-Host ("OKNO: "+$grc.Current.Name) -ForegroundColor Cyan
Write-Host "=== EDIT / COMBOBOX (wszystkie, z indeksem) ===" -ForegroundColor Cyan
$i=0
foreach($e in $grc.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -match 'Edit|ComboBox'){
    Write-Host ("#"+$i+" ["+($ct -replace 'ControlType.','')+"] name='"+$e.Current.Name+"' val='"+(GVal $e)+"' "+(SafeXY $e.Current.BoundingRectangle))
    $i++; if($i -ge 200){ break }
  }
}
Write-Host ("Edit/Combo razem: "+$i) -ForegroundColor DarkGray
Write-Host ""; Write-Host "=== BUTTONY z nazwa (Add, Submit, tab-y...) ===" -ForegroundColor Cyan
$j=0
foreach($e in $grc.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -match 'Button|Hyperlink|TabItem'){ $nm=$e.Current.Name; if($nm){ Write-Host ("["+($ct -replace 'ControlType.','')+"] '"+$nm+"' "+(SafeXY $e.Current.BoundingRectangle)); $j++; if($j -ge 120){break} } }
}
Write-Host ("Buttony razem: "+$j) -ForegroundColor DarkGray
