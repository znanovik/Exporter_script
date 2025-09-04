# Bookmarks Backup PowerShell (BME_PS)

**Date**: 2024-06-28  
**Version**: 1.0  
**Requires**: PowerShell 5.1+  (recommended: PowerShell 7+ for better UTF-8 and localization support)
**Compatibility**: Windows 7 / 10 / 11  

⚠️ **Warning**: By default, the script deletes archived files permanently — they are not moved to the Windows Recycle Bin.  
After ZIP packaging, original files are removed without the possibility of recovery via standard system tools.

---

## Purpose

A PowerShell script for backing up browser bookmarks (Edge or Chrome) into multiple formats: HTML, CSV, and Markdown.  
It creates timestamped copies in the `/backups` folder, archives older files in `/archive`, and optionally packages them into ZIP archives.  
The script also handles logging and log cleanup.

---

## Features

- Detects and processes the browser's native `Bookmarks` file as soon as it becomes available (for default profile only)
- Converts bookmarks from JSON to HTML, CSV, and Markdown  
- Timestamped filenames: `yyyy.MM.dd_HH.mm.ss_fff`  
- Automatically creates `/backups` and `/archive` folders  
- Adaptive retention logic (default settings):  
  - 1 latest file per format  
  - Up to 5 archived copies  
  - Older files are moved to ZIP  
  - ZIP archive holds up to 30 entries; older ZIP contents are deleted permanently  
- Logging:  
  - Console output  
  - Log file `backup_log.txt` stored in `/backups`  
  - Log retention is adaptive (default: 35 days)

---

## Configuration

Before running, you can customize:

- Browser selection (`Edge` or `Chrome`)  
- Date format  
- Output formats (enable/disable JSON, HTML, CSV, Markdown)  
- Number of backup and archive copies  
- Log retention duration

If no customization is needed, simply run the provided `.bat` file and collect your backups from `/backups`.

---

## Automation

To schedule automatic execution, use Windows Task Scheduler:

1. Create a new task  
2. In **Triggers**, set your desired schedule  
3. In **Actions**:  
   - Program: `powershell.exe`  
   - Arguments (example):  
     -ExecutionPolicy Bypass -File "C:\path\scripts\Exporter_script.ps1" -Browser Edge
💡 Note: For better handling of UTF-8 encoding and localized strings (especially with non-English characters), it is recommended to use PowerShell 7+ () instead of the legacy .

Example `.bat` launcher using PowerShell 7:
start pwsh.exe -NoExit -ExecutionPolicy Bypass -File "scripts\Exporter_script.ps1" -Browser Edge

---

## Debug Mode

Use the `-DryRun` parameter to simulate execution without deleting or packaging files.  
This is useful for testing logic and structure safely.

---

## Tests

Test scripts and sample data are located in the `/tests` folder.

The main test runner [`Tests.ps1`](/tests/Tests.ps1) orchestrates validation across core functional areas:

### Included Test Cases

- **Test 00 – Initial Setup**  
  Verifies that all required folders, sample data, and environment variables are correctly initialized.

- **Test 01 – Timestamped Backup Creation**  
  Ensures that new backup files are created with unique timestamped filenames.

- **Test 02 – Archive Rotation**  
  Creates multiple backup files and confirms that older ones are deleted once the retention limit is exceeded.

- **Test 03 – ZIP Packaging Threshold**  
  Fills the archive folder to the defined threshold and checks that older entries are removed from the ZIP archive.

- **Test 04 – Log Cleanup**  
  Validates that log entries older than the configured retention period are removed.

- **Test 05 – Dry-Run Mode**  
  Runs the script in simulation mode ($DryRun = $true in Setup block). Verifies that no files are written, deleted, or archived. Use $false to test actual execution.

⚠️ Note: All test data in `/tests/data`is synthetic and does not contain personal or private information.

---

## Architecture Overview

The diagram below illustrates the core step-by-step logic of the script:

![Architecture Diagram] (/diagrams/architecture_0.8.png)

 You can also view the source diagram file: [`architecture_0.8.puml`](/diagrams/architecture_0.8.puml)
 The diagram depicts the process starting with detection of the browser bookmarks file, followed by conversion to multiple formats such as HTML, CSV, and Markdown. It illustrates the creation of timestamped backup files in the backups folder, archiving of older files, and optional packaging into ZIP archives. The diagram also shows adaptive retention logic for backups, archives, and ZIP contents, as well as logging and log cleanup steps.

---

## Changelog

**v1.0** — Initial release (2024-06-28
  
- Bookmark export in multiple formats.
- Adaptive archiving and ZIP packaging.  
- Logging and retention logic.
- Dry-run mode for safe testing.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details
