# Script for backing up bookmarks from Edge or Chrome to HTML, CSV, and Markdown formats
# Creates backups in the `backups` folder, maintaining a dynamic number of recent copies, archiving and packaging older ones
# Requires PowerShell 5.1 or higher
# Date: 2024-06-28
# Version: 1.0

# Browser selection: "Edge" or "Chrome"
param (
    [ValidateSet("Edge", "Chrome")]
    [string]$Browser = "Edge",

    [bool]$DryRun = $false,

    [string]$BackupPath = "$PSScriptRoot\..\backups",

    [string]$LogPath = "$PSScriptRoot\..\backups\backup_log.txt",
    
    [string]$SourcePath = ""  # Path to Bookmarks file (optional; if empty, defaults based on browser)
    )

# Log dry-run action
if ($DryRun) {
    Add-Content $LogPath "[DryRun] Backup skipped at $(Get-Date)"
    Write-Host "Dry-run mode: no changes made"
    exit 0  
}



# PowerShell version check
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.1 or higher is required"
    exit 1
}

# Parameters for archiving and packaging logic
# (can be adjusted as needed)

# Storage architecture limits
$latestCopies     = 1    # most recent version
$maxUnarchived    = 4    # unarchived copies
$threshold        = 4    # ZIP packaging threshold
$maxFilesPerZip   = 30   # max files per ZIP archive

# Dynamic log retention limit (in days)
# Can be manually set for testing
$logRetentionDays = $null  # ← or $logRetentionDays = 3

# If not manually set, calculate retention based on storage limits
if (-not ($logRetentionDays)) {
    $logRetentionDays = $latestCopies + $maxUnarchived + $maxFilesPerZip
}
Write-Host "Log retention: $logRetentionDays days"

# Redundant check (can be simplified)
if (-not $logRetentionDays) {
    $logRetentionDays = $latestCopies + $maxUnarchived + $maxFilesPerZip
}
Write-Host "Log retention: $logRetentionDays days"

# Function to write log entries
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logPath "[$timestamp] $message"
}

# Function to clean log entries older than a specified number of days
function Clear-Log {
    param (
        [string]$logFilePath,
        [int]$retentionDays,
        [bool]$DryRun = $false
    )

    if (-not (Test-Path $logFilePath)) { return }

    $cutoffDate = (Get-Date).AddDays(-$retentionDays)
    $lines = Get-Content $logFilePath
    $filteredLines = @()

    foreach ($line in $lines) {
        if ($line -match '^

\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]

') {
            $timestamp = $line.Substring(1, 19)
            try {
                $entryDate = [datetime]::ParseExact($timestamp, 'yyyy-MM-dd HH:mm:ss', $null)
                if ($entryDate -ge $cutoffDate) {
                    $filteredLines += $line
                }
            } catch {
                $filteredLines += $line
            }
        } else {
            $filteredLines += $line
        }
    }

    if (-not $DryRun) {
        $filteredLines | Set-Content $logFilePath
        Write-Log "Log cleanup: removed entries older than $retentionDays days"
    } else {
        Write-Log "[DryRun] Skipped log cleanup — would have removed entries older than $retentionDays days"
    }
}

# Perform log cleanup based on retention depth
if (-not $DryRun) {
    # Perform log cleanup based on retention depth
    Clear-Log -logFilePath $logPath -retentionDays $logRetentionDays
} else {
    Write-Host "🚫 Dry-run: Skipped log cleanup"
    Add-Content $logPath "[DryRun] Skipped Clear-Log at $(Get-Date)"
}


# Output configuration parameters
Write-Host "Browser: $Browser"
Write-Host "Retention limit (unarchived): $latestCopies"
Write-Host "Archiving limit (max unarchived in archive): $maxUnarchived"
Write-Host "ZIP packaging threshold: $threshold"
Write-Host "Max files per ZIP: $maxFilesPerZip"    

# Create destination folder if it doesn't exist
if (-not (Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath | Out-Null
}

# Initialize log file if it doesn't exist
if (-not (Test-Path $logPath)) {
    New-Item -ItemType File -Path $logPath | Out-Null
}

# Root keys used in browser's JSON bookmarks file
$rootKeys = @("bookmark_bar", "other", "synced") # Add more root folders here if needed (e.g., "mobile", "trash", "managed")

# Function to write log entries
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logPath "[$timestamp] $message"
}

# Determine source path if not provided as a parameter 
Write-Host "SourcePath before check: '$SourcePath'"
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    Write-Host "SourcePath is empty — selecting default based on browser"
    switch ($Browser) {
        "Chrome" { $SourcePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks" }
        "Edge"   { $SourcePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Bookmarks" }
    }
} else {
    Write-Host "SourcePath provided: $SourcePath"
}

# Validate that the Bookmarks file exists
if (-not (Test-Path $SourcePath)) {
    Write-Error "Bookmarks file not found at path: $SourcePath"
    exit 1
}

# Generate timestamp for filenames (safe and readable format)
$timestamp = Get-Date -Format "yyyy.MM.dd_HH.mm.ss_fff"

# Redundant folder creation check (already performed earlier)
if (-not (Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath | Out-Null
}

# Function to archive older files, keeping only the latest N copies
function Compress-OldFiles {
    param (
        [string]$folder,
        [string]$extension,
        [int]$maxUnarchived = 0
    )

    $archiveFolder = Join-Path $folder "archive"
    if (-not (Test-Path $archiveFolder)) {
        New-Item -ItemType Directory -Path $archiveFolder | Out-Null
    }

    $files = Get-ChildItem -Path $folder -Filter "*.$extension" | Sort-Object LastWriteTime
    if ($files.Count -gt $maxUnarchived) {
        $filesToMove = $files | Select-Object -First ($files.Count - $maxUnarchived)
        foreach ($file in $filesToMove) {
            Move-Item $file.FullName -Destination $archiveFolder -Force
            Write-Log "Archived: $($file.Name)"
        }
    }
}

# Parameter to control whether ZIP filename includes a timestamp
$useTimestampInZipName = $true  # or $false
Write-Log "Packaging mode: " + ($useTimestampInZipName ? "timestamped ZIP" : "fixed ZIP name")

# Function to package archived files into a ZIP if their count exceeds the threshold
function Compress-FilesToZip {
    param (
        [string]$archiveFolder,
        [string]$extension,
        [int]$threshold = 4,
        [int]$maxFilesPerZip = 30
    )

    switch ($extension.ToLower()) {
        "md"   { $label = "MD" }
        "csv"  { $label = "CSV" }
        "html" { $label = "HTML" }
        "json" { $label = "JSON" }
        default { $label = $extension.ToUpper() }
    }

    Write-Log "Archiving type: $label → $extension"
    Write-Log "LABEL: $label | EXTENSION: $extension"

    $archivedFiles = Get-ChildItem -Path $archiveFolder -Filter "*.$extension"
    if ($archivedFiles.Count -lt $threshold) {
        Write-Log "Files to package ($extension): $($archivedFiles.Count) — below ZIP threshold"
        return
    }

    $zipName = "backup_$label.zip"
    $zipPath = Join-Path $archiveFolder $zipName

    $tempFolder = Join-Path $archiveFolder "$label-temp"
    if (Test-Path $tempFolder) { Remove-Item $tempFolder -Recurse -Force }
    New-Item -ItemType Directory -Path $tempFolder | Out-Null

    # Unpack existing ZIP if present
    if (Test-Path $zipPath) {
        Expand-Archive -Path $zipPath -DestinationPath $tempFolder -Force
        Remove-Item $zipPath -Force
        Write-Log "Previous archive unpacked: $zipName"
    }

    # Copy new files into temp folder
    foreach ($file in $archivedFiles) {
        Copy-Item $file.FullName -Destination $tempFolder
        Remove-Item $file.FullName -Force
        Write-Log "Added to archive: $($file.Name)"
    }

    # Apply file count limit
    $allFiles = Get-ChildItem -Path $tempFolder -Filter "*.$extension" | Sort-Object LastWriteTime
    if ($allFiles.Count -gt $maxFilesPerZip) {
        $filesToDelete = $allFiles | Select-Object -First ($allFiles.Count - $maxFilesPerZip)
        foreach ($file in $filesToDelete) {
            Remove-Item $file.FullName -Force
            Write-Log "Removed from archive (limit): $($file.Name)"
        }
    }

    # Compress into ZIP
    Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipPath -Force
    Remove-Item $tempFolder -Recurse -Force
    Write-Log "ZIP archive updated: $zipName"
}

# Path to JSON backup file
$jsonBackupPath = Join-Path $BackupPath "Bookmarks_$timestamp.json"

# Archive older files, keeping only the latest 1 (adapted)
if (-not $DryRun) {
    # Archive older files, keeping only the latest 1
Compress-OldFiles -folder $BackupPath -extension "json"
Compress-OldFiles -folder $BackupPath -extension "html"
Compress-OldFiles -folder $BackupPath -extension "csv"
Compress-OldFiles -folder $BackupPath -extension "md"
} else {
    Write-Host "🚫 Dry-run: Skipped file compression and cleanup"
}

# Package archived files into ZIP if threshold (4+) is reached
if (-not $DryRun) {
    # Package archived files into ZIP if threshold (4+) is reached
    $archiveFolder = Join-Path $BackupPath "archive"
    Compress-FilesToZip -archiveFolder $archiveFolder -extension "json" -threshold 4
    Compress-FilesToZip -archiveFolder $archiveFolder -extension "html" -threshold 4
    Compress-FilesToZip -archiveFolder $archiveFolder -extension "csv"  -threshold 4
    Compress-FilesToZip -archiveFolder $archiveFolder -extension "md"   -threshold 4
} else {
    Write-Host "🚫 Dry-run: Skipped ZIP packaging"
    Add-Content $LogPath "[DryRun] Skipped ZIP packaging at $(Get-Date)"
}

# Create JSON backup    
if (-not $DryRun) {
    Copy-Item $SourcePath $jsonBackupPath -Force
    #TODO Экспорт в HTML, CSV, Markdown 
    #TODO Архивация, удаление, очистка
} else {
    Write-Host "🚫 Dry-run: Skipped file creation and packaging"
}

Write-Log "Backup started"
Write-Log "JSON created: $jsonBackupPath"
Write-Log "Source: $SourcePath"

# Read JSON content
try {
    $bookmarksJson = Get-Content $jsonBackupPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error reading JSON: $_"
    exit
}

# Merge all bookmarks from root folders
$allBookmarks = @()
$allBookmarks += $bookmarksJson.roots.bookmark_bar.children
$allBookmarks += $bookmarksJson.roots.other.children
$allBookmarks += $bookmarksJson.roots.synced.children

# Function to count URLs in JSON structure
function Measure-UrlsInJson {
    param ($nodes)

    $result = @{
        total = 0
        folders = 0
        urls = 0
    }

    foreach ($node in $nodes) {
        $result.total++  # ← fix: count every node

        if ($node.type -eq "url") {
            $result.urls++
        } elseif ($node.type -eq "folder" -and $node.children) {
            $result.folders++
            $childStats = Measure-UrlsInJson $node.children
            $result.total += $childStats.total
            $result.folders += $childStats.folders
            $result.urls += $childStats.urls
        }
    }

    return $result
}

# Count bookmarks in JSON
$totalStats = @{
    total = 0
    folders = 0
    urls = 0
}

foreach ($key in $rootKeys) {
    $rootNode = $bookmarksJson.roots.$key
    if ($rootNode.children) {
        $stats = Measure-UrlsInJson $rootNode.children
        Write-Log "[$key] — URLs: $($stats.urls), folders: $($stats.folders), total nodes: $($stats.total)"
        $totalStats.total += $stats.total
        $totalStats.folders += $stats.folders
        $totalStats.urls += $stats.urls
    }
}

# Log total bookmark count
Write-Log "Total bookmarks in JSON: $($totalStats.urls)"
Write-Host "Total bookmarks in JSON: $($totalStats.urls)"

# Path to HTML backup file
$htmlPath = Join-Path $BackupPath "Bookmarks_$timestamp.html"

# Build HTML backup content
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Edge Bookmarks Backup</title>
</head>
<body>
    <h1>Edge Bookmarks ($timestamp)</h1>
    <ul>
"@

# Recursive function to convert bookmarks to HTML
function Convert-BookmarksToHtml {
    param ($nodes)

    foreach ($node in $nodes) {
        if ($node.type -eq "url") {
            $script:htmlContent += "        <li><a href='$($node.url)'>$($node.name)</a></li>`n"
        } elseif ($node.type -eq "folder") {
            $script:htmlContent += "        <li><strong>$($node.name)</strong><ul>`n"
            Convert-BookmarksToHtml $node.children
            $script:htmlContent += "        </ul></li>`n"
        }
    }
}

# Start HTML conversion
Convert-BookmarksToHtml $allBookmarks

# Finalize HTML content
$htmlContent += @"
    </ul>
</body>
</html>
"@

# Save HTML file
if (-not $DryRun) {
    $htmlContent | Out-File -Encoding UTF8 $htmlPath
    Write-Log "HTML file saved at: $htmlPath"
} else {
    Write-Log "[DryRun] Skipped saving HTML file — target would be: $htmlPath"
    Write-Host "🚫 Dry-run: Skipped saving HTML file"
}

# Count number of links in HTML
$htmlCount = ($htmlContent -split "`n" | Where-Object { $_ -match "<li><a href=" }).Count

Write-Host "Done! HTML file saved at: $htmlPath"
Write-Log "HTML created: $htmlPath"
Write-Log "Total bookmarks in HTML: $htmlCount"
Write-Host "Total bookmarks in HTML: $htmlCount"

# Path to CSV file (if needed)
$csvPath = Join-Path $BackupPath "Bookmarks_$timestamp.csv"

# Initialize collection to store bookmark data before exporting to CSV
$csvData = New-Object System.Collections.Generic.List[Object]

# Recursive function to traverse bookmarks and collect data for CSV
Write-Host "Bookmarks in bookmark_bar: $($bookmarksJson.roots.bookmark_bar.children.Count)"
Write-Host "Bookmarks in other: $($bookmarksJson.roots.other.children.Count)"
Write-Host "Bookmarks in synced: $($bookmarksJson.roots.synced.children.Count)"

function Convert-BookmarksForCsv {
    param ($nodes, $folderPath = "")

    foreach ($node in $nodes) {
        if ($node.type -eq "url") {
            $csvData.Add([PSCustomObject]@{
                Folder = $folderPath
                Name   = $node.name
                URL    = $node.url
            })
        } elseif ($node.type -eq "folder") {
            $newPath = if ($folderPath) { "$folderPath\$($node.name)" } else { $node.name }
            Convert-BookmarksForCsv $node.children $newPath
        }
    }
}

# Start conversion to CSV
Convert-BookmarksForCsv $allBookmarks

# Save CSV file (only if not DryRun)
if (-not $DryRun) {
    $csvData.ToArray() | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Log "CSV created: $csvPath"
    Write-Log "Total bookmarks: $($csvData.Count)"
    Write-Host "Done! CSV file saved at: $csvPath"
    Write-Host "Total bookmarks: $($csvData.Count)"
} else {
    Write-Log "[DryRun] Skipped saving CSV file — target would be: $csvPath"
    Write-Log "[DryRun] Total bookmarks (simulated): $($csvData.Count)"
    Write-Host "🚫 Dry-run: Skipped saving CSV file"
    Write-Host "Total bookmarks (simulated): $($csvData.Count)"
}

# Path to Markdown file
$mdPath = Join-Path $BackupPath "Bookmarks_$timestamp.md"

# Initialize list of lines
$script:mdLines = New-Object System.Collections.Generic.List[string]
$script:mdLines.Add("# Bookmarks Backup ($timestamp)")
$script:mdLines.Add("")

# Count and log node statistics per root section
$script:mdLines.Add("<details>")
$script:mdLines.Add("<summary> Bookmark Statistics </summary>")
$script:mdLines.Add("")
$script:mdLines.Add("| Section        | URLs | Folders | Total Nodes |")
$script:mdLines.Add("|----------------|------|---------|--------------|")

foreach ($key in $rootKeys) {
    $rootNode = $bookmarksJson.roots.$key
    if ($rootNode.children) {
        $stats = Measure-UrlsInJson $rootNode.children
        $script:mdLines.Add("| $key | $($stats.urls) | $($stats.folders) | $($stats.total) |")
    }
}

$script:mdLines.Add("| **Total**      | **$($totalStats.urls)** | **$($totalStats.folders)** | **$($totalStats.total)** |")
$script:mdLines.Add("")
$script:mdLines.Add("</details>")
$script:mdLines.Add("")

# Recursive function to convert bookmarks to Markdown
function Convert-BookmarksToMarkdown {
    param (
        $nodes,
        $folderPath = "",
        $depth = 2
    )

    $localIndex = 1

    foreach ($node in $nodes) {
        if ($node.url) {
            $line = "$localIndex. [$($node.name)]($($node.url))"
            if ($folderPath) { $line += " — *$folderPath*" }
            $script:mdLines.Add($line)
            $localIndex++
        } elseif ($node.type -eq "folder" -and $node.children) {
            $newPath = if ($folderPath) { "$folderPath/$($node.name)" } else { $node.name }
            $script:mdLines.Add("`n" + ("#" * $depth) + " $($node.name)")
            Convert-BookmarksToMarkdown $node.children $newPath ($depth + 1)
        }
    }
}

# Start Markdown conversion
Convert-BookmarksToMarkdown $allBookmarks "" 2

if (-not $DryRun) {
    # Save Markdown file
    $script:mdLines | Out-File -Encoding UTF8 $mdPath
    Write-Log "Markdown created: $mdPath"

    $mdCount = ($mdLines | Where-Object { $_ -match "^\d+\. 

\[.*\]

\(.*\)" }).Count
    Write-Log "Total bookmarks in Markdown: $mdCount"
    Write-Host "Done! Markdown file saved at: $mdPath"
    Write-Host "Total bookmarks in Markdown: $mdCount"
} else {
    $mdCount = ($mdLines | Where-Object { $_ -match "^\d+\. 

\[.*\]

\(.*\)" }).Count
    Write-Log "[DryRun] Skipped saving Markdown file — target would be: $mdPath"
    Write-Log "[DryRun] Total bookmarks in Markdown (simulated): $mdCount"
    Write-Host "🚫 Dry-run: Skipped saving Markdown file"
    Write-Host "Total bookmarks in Markdown (simulated): $mdCount"
}

# Finalize log (mode)
$rootKeys = $bookmarksJson.roots | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

# Compare bookmark counts across formats
Write-Log "Comparison:"
Write-Log "JSON: $($statsFromAll.urls)"
Write-Log "CSV: $($csvData.Count)"
Write-Log "Markdown: $mdCount"
Write-Log "HTML: $htmlCount"

# Final summary log
$summary = "Summary: URLs: $($totalStats.urls), Folders: $($totalStats.folders), Total Nodes: $($totalStats.total)"
Write-Log $summary
Write-Host $summary
