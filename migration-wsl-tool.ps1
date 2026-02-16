#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    WSL Distribution Migration Tool - GUI Version
.DESCRIPTION
    WSL distribution migration tool using Windows Forms
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest

# ====== Global Variables ======
$Script:SelectedDistro = $null
$Script:Distros = @()
$Script:Form = $null

# ====== Utility Functions ======
function Get-WslDistributions {
    try {
        $originalEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        
        $wslOutput = wsl --list --verbose 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
        
        $distros = $wslOutput | 
            Select-Object -Skip 1 | 
            Where-Object { $_.Trim() -ne '' } |
            ForEach-Object {
                $line = $_ -replace '\x00', ''
                if ($line -match '^\s*(\*?)\s*(.+?)\s+(Stopped|Running)\s+(\d+)\s*$') {
                    [PSCustomObject]@{
                        Default = $matches[1] -eq '*'
                        Name    = $matches[2].Trim()
                        State   = $matches[3]
                        Version = $matches[4]
                        Display = "$($matches[2].Trim()) - WSL$($matches[4]) ($($matches[3]))"
                    }
                }
            }
        
        return $distros
    }
    finally {
        [Console]::OutputEncoding = $originalEncoding
    }
}

function Start-WslMove {
    param(
        [string]$DistroName,
        [string]$Version,
        [string]$TargetPath,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )
    
    $tempFile = Join-Path $TargetPath "$DistroName.tar"
    
    try {
        # Export
        $StatusLabel.Text = "Exporting... (this may take a while)"
        $ProgressBar.Value = 20
        [System.Windows.Forms.Application]::DoEvents()
        
        $exportCmd = "wsl --export `"$DistroName`" `"$tempFile`""
        cmd /c $exportCmd 2>&1 | Out-Null
        
        if (-not (Test-Path $tempFile)) {
            throw "Export failed"
        }
        
        # Unregister
        $StatusLabel.Text = "Unregistering existing distribution..."
        $ProgressBar.Value = 50
        [System.Windows.Forms.Application]::DoEvents()
        
        wsl --unregister $DistroName | Out-Null
        
        # Import
        $StatusLabel.Text = "Importing to new location..."
        $ProgressBar.Value = 75
        [System.Windows.Forms.Application]::DoEvents()
        
        $importCmd = "wsl --import `"$DistroName`" `"$TargetPath`" `"$tempFile`" --version $Version"
        cmd /c $importCmd 2>&1 | Out-Null
        
        # Cleanup
        $StatusLabel.Text = "Completed!"
        $ProgressBar.Value = 100
        [System.Windows.Forms.Application]::DoEvents()
        
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        
        return $true
    }
    catch {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

# ====== GUI Creation ======
$form = New-Object System.Windows.Forms.Form
$form.Text = 'WSL Distribution Migration'
$form.Size = New-Object System.Drawing.Size(600, 450)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$Script:Form = $form

# Title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(550, 30)
$titleLabel.Text = 'WSL Distribution Migration Tool'
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$form.Controls.Add($titleLabel)

# Separator
$separator1 = New-Object System.Windows.Forms.Label
$separator1.Location = New-Object System.Drawing.Point(20, 55)
$separator1.Size = New-Object System.Drawing.Size(550, 2)
$separator1.BorderStyle = 'Fixed3D'
$form.Controls.Add($separator1)

# Distribution selection label
$distroLabel = New-Object System.Windows.Forms.Label
$distroLabel.Location = New-Object System.Drawing.Point(20, 70)
$distroLabel.Size = New-Object System.Drawing.Size(550, 25)
$distroLabel.Text = 'Select distribution to move:'
$distroLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($distroLabel)

# Distribution ComboBox
$distroComboBox = New-Object System.Windows.Forms.ComboBox
$distroComboBox.Location = New-Object System.Drawing.Point(20, 100)
$distroComboBox.Size = New-Object System.Drawing.Size(550, 30)
$distroComboBox.DropDownStyle = 'DropDownList'
$distroComboBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($distroComboBox)

# Refresh button
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(470, 135)
$refreshButton.Size = New-Object System.Drawing.Size(100, 30)
$refreshButton.Text = 'Refresh'
$refreshButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$refreshButton.Add_Click({
    $Script:Distros = @(Get-WslDistributions)
    $distroComboBox.Items.Clear()
    
    if ($Script:Distros.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'No WSL distributions found.',
            'Notice',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    } else {
        $Script:Distros | ForEach-Object { $distroComboBox.Items.Add($_.Display) } | Out-Null
        $distroComboBox.SelectedIndex = 0
    }
})
$form.Controls.Add($refreshButton)

# Target path label
$targetLabel = New-Object System.Windows.Forms.Label
$targetLabel.Location = New-Object System.Drawing.Point(20, 180)
$targetLabel.Size = New-Object System.Drawing.Size(550, 25)
$targetLabel.Text = 'Target folder path:'
$targetLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($targetLabel)

# Target path TextBox
$targetTextBox = New-Object System.Windows.Forms.TextBox
$targetTextBox.Location = New-Object System.Drawing.Point(20, 210)
$targetTextBox.Size = New-Object System.Drawing.Size(450, 30)
$targetTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($targetTextBox)

# Browse button
$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(480, 208)
$browseButton.Size = New-Object System.Drawing.Size(90, 28)
$browseButton.Text = 'Browse...'
$browseButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select target folder for WSL distribution"
    $folderBrowser.ShowNewFolderButton = $true
    
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $targetTextBox.Text = $folderBrowser.SelectedPath
    }
})
$form.Controls.Add($browseButton)

# Info label
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Location = New-Object System.Drawing.Point(20, 250)
$infoLabel.Size = New-Object System.Drawing.Size(550, 40)
$infoLabel.Text = "Tip: Large file migration may take time.`n   Using SSD drives will be faster."
$infoLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$infoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($infoLabel)

# Progress label
$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Location = New-Object System.Drawing.Point(20, 300)
$progressLabel.Size = New-Object System.Drawing.Size(550, 20)
$progressLabel.Text = 'Ready'
$progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($progressLabel)

# ProgressBar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 325)
$progressBar.Size = New-Object System.Drawing.Size(550, 25)
$progressBar.Style = 'Continuous'
$form.Controls.Add($progressBar)

# Move button
$moveButton = New-Object System.Windows.Forms.Button
$moveButton.Location = New-Object System.Drawing.Point(370, 365)
$moveButton.Size = New-Object System.Drawing.Size(90, 35)
$moveButton.Text = 'Move'
$moveButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$moveButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$moveButton.ForeColor = [System.Drawing.Color]::White
$moveButton.FlatStyle = 'Flat'
$moveButton.Add_Click({
    if ($distroComboBox.SelectedIndex -lt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            'Please select a distribution.',
            'Input Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($targetTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show(
            'Please enter target path.',
            'Input Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    $selectedDistro = $Script:Distros[$distroComboBox.SelectedIndex]
    $targetPath = $targetTextBox.Text.TrimEnd('\')
    
    # Validation
    if ($targetPath -match '^[A-Za-z]:\\?$') {
        [System.Windows.Forms.MessageBox]::Show(
            'Drive root cannot be used as target folder.',
            'Input Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }
    
    # Confirmation
    $confirmResult = [System.Windows.Forms.MessageBox]::Show(
        "Distribution: $($selectedDistro.Name)`nTarget path: $targetPath`n`nContinue?",
        'Confirmation',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($confirmResult -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }
    
    # Create folder
    if (-not (Test-Path $targetPath)) {
        try {
            New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to create target folder: $($_.Exception.Message)",
                'Error',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
    }
    
    # Disable UI
    $moveButton.Enabled = $false
    $cancelButton.Enabled = $false
    $distroComboBox.Enabled = $false
    $targetTextBox.Enabled = $false
    $browseButton.Enabled = $false
    $refreshButton.Enabled = $false
    $progressBar.Value = 0
    
    try {
        $result = Start-WslMove `
            -DistroName $selectedDistro.Name `
            -Version $selectedDistro.Version `
            -TargetPath $targetPath `
            -ProgressBar $progressBar `
            -StatusLabel $progressLabel
        
        if ($result) {
            [System.Windows.Forms.MessageBox]::Show(
                "Distribution migrated successfully!`n`nNew location: $targetPath",
                'Completed',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            $Script:Form.Close()
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error occurred: $($_.Exception.Message)",
            'Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        $progressBar.Value = 0
        $progressLabel.Text = 'Error occurred'
    }
    finally {
        $moveButton.Enabled = $true
        $cancelButton.Enabled = $true
        $distroComboBox.Enabled = $true
        $targetTextBox.Enabled = $true
        $browseButton.Enabled = $true
        $refreshButton.Enabled = $true
    }
})
$form.Controls.Add($moveButton)

# Close button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(470, 365)
$cancelButton.Size = New-Object System.Drawing.Size(100, 35)
$cancelButton.Text = 'Close'
$cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cancelButton.Add_Click({ $form.Close() })
$form.Controls.Add($cancelButton)

# Initial load
$Script:Distros = @(Get-WslDistributions)
if ($Script:Distros.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        'No WSL distributions found.',
        'Notice',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
} else {
    $Script:Distros | ForEach-Object { $distroComboBox.Items.Add($_.Display) } | Out-Null
    $distroComboBox.SelectedIndex = 0
}

# Show form
[void]$form.ShowDialog()
