# ============================================================
#  DUMPER GRC - wypisuje pola na stronie "Access Request" (SAP NWBC)
#  Odpal gdy okno Access Request jest otwarte. Nic nie zmienia.
#  Wynik: wklej / zrzut (User, Functional Area, Description, Add).
# ============================================================
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes
$AE=[System.Windows.Automation.AutomationElement]; $TS=[System.Windows.Automation.TreeScope]; $TRUE1=[System.Windows.Automation.Condition]::TrueCondition
function ToAscii($s){ if(-not $s){return ''}; $n=$s.Normalize([Text.NormalizationForm]::FormD); -join($n.ToCharArray()|Where-Object{[Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'}) }
function GVal($e){ try{ ($e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)).Current.Value }catch{ $null } }
$grc=$null; foreach($w in $AE::RootElement.FindAll($TS::Children,$TRUE1)){ if($w.Current.Name -match 'Access Request'){ $grc=$w; break } }
if(-not $grc){ Write-Host "Nie znalazlem okna 'Access Request'. Otworz je i sprobuj znowu." -ForegroundColor Red; return }
Write-Host ("OKNO: "+$grc.Current.Name) -ForegroundColor Cyan
$i=0
foreach($e in $grc.FindAll($TS::Descendants,$TRUE1)){
  $ct=$e.Current.ControlType.ProgrammaticName
  if($ct -match 'Edit|ComboBox|Button|Hyperlink'){
    $nm=$e.Current.Name; if($nm -or (GVal $e)){ Write-Host ("["+($ct -replace 'ControlType.','')+"] name='"+$nm+"' val='"+(GVal $e)+"'"); $i++; if($i -ge 120){ break } }
  }
}
Write-Host ("Razem: "+$i) -ForegroundColor DarkGray
