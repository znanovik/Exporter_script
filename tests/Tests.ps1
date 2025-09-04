<#
Tests: 00,01,02,03,04,05 
Checks that the script creates a backup file with a timestamped name
#>

Write-Host "Running Tests"

# --- Setup ---
$Browser = "Chrome"
$DryRun = $false
$TestRoot = "$PSScriptRoot\workspace"
$BackupPath = "$TestRoot\backups"
$source = "$PSScriptRoot\data\sample_bookmarks.json"
$LogPath = "$TestRoot\log.txt"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ScriptPath = "$PSScriptRoot\..\scripts\Exporter_script.ps1"

# Ensure clean test environment
Remove-Item $BackupPath\* -Force -ErrorAction SilentlyContinue
Remove-Item $LogPath -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

# Verify script exists
if (-Not (Test-Path $ScriptPath)) {
    Write-Host "❌ Script not found at $ScriptPath"
    exit
}

# --- Execution ---
if (-Not (Test-Path $ScriptPath)) {
    Write-Host "❌ Script not found at $ScriptPath"
    exit
}
& $ScriptPath -Browser $Browser -DryRun:$DryRun -BackupPath $BackupPath -LogPath $LogPath -SourcePath $source

# Wait a moment to ensure file system updates
Start-Sleep -Seconds 2

# --- Assertion ---
$backupFiles = Get-ChildItem $BackupPath -Filter "Bookmarks_*.json"
if ($backupFiles.Count -ge 1) {
    Write-Host "Backup file created: $($backupFiles[0].Name)"
} else {
    Write-Host "No backup file found"
}

# --- Dry-run Check ---
if ($DryRun -eq $true -and $backupFiles.Count -eq 0) {
    Write-Host "✅ Dry-run mode respected: no backup created"
}

# Check for timestamped filename    
$expectedPattern = "Bookmarks_$timestamp*.json"
$matchedFiles = Get-ChildItem $BackupPath -Filter $expectedPattern

if ($matchedFiles.Count -ge 1) {
    Write-Host "✅ Timestamped backup file found: $($matchedFiles[0].Name)"
} else {
    Write-Host "❌ No matching backup file found"
}

# --- Log Check (optional) ---
if (Test-Path $LogPath) {
    $logContent = Get-Content $LogPath
    if ($logContent -match "Backup completed") {
        Write-Host "Log confirms backup"
    } else {
        Write-Host "Log does not confirm backup"
    }
}