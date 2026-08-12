# ============================================================
#  START - menu glowne: DISPATCH (router ticketow) / GRC (zakladanie GRC)
#  Odpal ten plik (F5). Wybierz tryb.
# ============================================================
$BASE = if($PSScriptRoot){ $PSScriptRoot } elseif($MyInvocation.MyCommand.Path){ Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$mode=''
$form=New-Object System.Windows.Forms.Form
$form.Text='SAP Ticket Tool'; $form.Width=340; $form.Height=260; $form.TopMost=$true; $form.StartPosition='CenterScreen'; $form.FormBorderStyle='FixedDialog'; $form.MaximizeBox=$false; $form.MinimizeBox=$false

$lbl=New-Object System.Windows.Forms.Label; $lbl.Text='Wybierz tryb:'; $lbl.Left=20; $lbl.Top=15; $lbl.Width=280; $lbl.Font=New-Object System.Drawing.Font('Segoe UI',11); $form.Controls.Add($lbl)

$bD=New-Object System.Windows.Forms.Button
$bD.Text='DISPATCH  (routing ticketow)'; $bD.Left=20; $bD.Top=50; $bD.Width=290; $bD.Height=70
$bD.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold)
$bD.BackColor=[System.Drawing.Color]::FromArgb(46,120,210); $bD.ForeColor='White'
$bD.Add_Click({ $script:mode='dispatch'; $form.Close() })
$form.Controls.Add($bD)

$bG=New-Object System.Windows.Forms.Button
$bG.Text='GRC  (zakladanie konta GRC)'; $bG.Left=20; $bG.Top=130; $bG.Width=290; $bG.Height=70
$bG.Font=New-Object System.Drawing.Font('Segoe UI',13,[System.Drawing.FontStyle]::Bold)
$bG.BackColor=[System.Drawing.Color]::FromArgb(60,160,90); $bG.ForeColor='White'
$bG.Add_Click({ $script:mode='grc'; $form.Close() })
$form.Controls.Add($bG)

[void]$form.ShowDialog()

if($mode -eq 'dispatch'){
  $p=Join-Path $BASE 'router-full.ps1'
  if(Test-Path $p){ & $p } else { [System.Windows.Forms.MessageBox]::Show("Nie znalazlem router-full.ps1 w:`n$BASE") }
}elseif($mode -eq 'grc'){
  $p=Join-Path $BASE 'grc.ps1'
  if(Test-Path $p){ & $p } else { [System.Windows.Forms.MessageBox]::Show("GRC - jeszcze nie zbudowane. Opisz proces zakladania GRC.") }
}
