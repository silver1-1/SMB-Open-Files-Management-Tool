<#
.SYNOPSIS
    Instantly audits and terminates active SMB network file locks and sessions via an interactive CLI.
.DESCRIPTION
    Queries the local SMB server for open files, allowing dual-mode filtering by Username or 
    File/Path strings. Tracks and displays Open Mode metrics and automates ghost file purges.
.NOTES
    Author:       Mathias McDowell
    Version:      1.0
#>

# --- ADMINISTRATOR PRIVILEGE CHECK ---
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n==========================================================================================" -ForegroundColor Red
    Write-Host " [ERROR] ADMINISTRATOR PRIVILEGES REQUIRED" -ForegroundColor Red -BackgroundColor Black
    Write-Host "==========================================================================================" -ForegroundColor Red
    Write-Host " This utility interacts with low-level SMB server handles and requires administrative access."
    Write-Host " Please close this window, right-click on the script file itself, and select:"
    Write-Host " 'Run as Administrator'" -ForegroundColor Green
    Write-Host "==========================================================================================" -ForegroundColor Red
    for ($i = 15; $i -gt 0; $i--) {
        Write-Progress -Activity "Missing Administrative Privileges" -Status "Closing this window automatically in $i seconds..." -PercentComplete (($i / 15) * 100)
        Start-Sleep -Seconds 1
    }
    Exit
}

# --- DYNAMIC CONSOLE WINDOW RESIZING ---
if ($Host.Name -eq "ConsoleHost") {
    $windowSize = $Host.UI.RawUI.WindowSize
    $bufferSize = $Host.UI.RawUI.BufferSize
    
    $bufferSize.Width = 140
    $Host.UI.RawUI.BufferSize = $bufferSize
    
    $windowSize.Width = 140
    $Host.UI.RawUI.WindowSize = $windowSize
}

# --- GLOBAL UTILITY ENGINE ---
$global:currentStage = "MainMenu"
$global:fileList     = @()
$global:searchMode   = ""
$global:searchString = ""

function Show-HelpMenu {
    Write-Host "`n======================================== HELP MANUAL ======================================" -ForegroundColor White -BackgroundColor DarkGray
    Write-Host " This utility allows administrators to seamlessly audit and close active server handles."
    Write-Host " You can type 'help' or '/help' at ANY prompt to call this reference guide instantly.`n"
    Write-Host " STAGE 0: Audit Selection (Main Menu)"
    Write-Host "   Choose [1] to find locks by Username, or [2] to search by a File Name/Path string."
    Write-Host " "
    Write-Host " STAGE 1: Target Metadata Dashboard"
    Write-Host "   - Index          : Dynamic execution identifier."
    Write-Host "   - ClientUserName : Authenticated Active Directory identity."
    Write-Host "   - Permissions    : Active 'Open Mode' (Read, Write, or Delete states)."
    Write-Host "   - Path           : Exact UNC network volume path."
    Write-Host " "
    Write-Host " STAGE 2: Core Execution Commands"
    Write-Host "   [Index Number] : Terminates file handle and purges Excel ghost files (~$)."
    Write-Host "   [S]            : Drops entire SMB connection infrastructure for listed clients."
    Write-Host "   [R]            : Refreshes active handle stream."
    Write-Host "   [M]            : Escapes back out to Main Menu."
    Write-Host "   [E]            : Cleanly terminates environment."
    Write-Host "===========================================================================================" -ForegroundColor White -BackgroundColor DarkGray
    Write-Host "Resuming script execution. Returning to current stage: [$global:currentStage]...`n" -ForegroundColor DarkGray
}

function Get-ValidatedInput {
    param([string]$PromptMessage)
    while ($true) {
        $rawInput = (Read-Host -Prompt $PromptMessage)
        if ($null -eq $rawInput) { $rawInput = "" }
        $sanitized = $rawInput.Trim()
        if ($sanitized -match '^([hH][eE][lL][pP]|\/[hH][eE][lL][pP]|\?|-[hH][eE][lL][pP])$') {
            Show-HelpMenu
            continue
        }
        return $sanitized
    }
}

function Update-OpenFiles {
    Write-Host "`nRefreshing active server handles matching '$global:searchString'..." -ForegroundColor Cyan
    if ($global:searchMode -eq "User") {
        $rawFiles = Get-SmbOpenFile | Where-Object { $_.ClientUserName -like "*$global:searchString*" }
    } else {
        $rawFiles = Get-SmbOpenFile | Where-Object { $_.Path -like "*$global:searchString*" }
    }
    $global:fileList = @()
    if ($null -ne $rawFiles) {
        foreach ($file in $rawFiles) {
            # Translate SMB numerical access bitmask into human readable strings
            $rawPerm = [int]$file.Permissions
            $readablePerm = switch ($rawPerm) {
                1       { "Read" }
                2       { "Write" }
                3       { "Read/Write" }
                4       { "Delete" }
                5       { "Read/Delete" }
                6       { "Write/Delete" }
                7       { "Full Control (Delete)" }
                default { "Custom ($rawPerm)" }
            }

            $global:fileList += [PSCustomObject]@{
                Index          = $global:fileList.Count + 1
                Path           = $file.Path
                ClientUserName = $file.ClientUserName
                Permissions    = $readablePerm
                NativeObject   = $file
            }
        }
    }
}

# SHOW HELP AT FIRST BOOT
Show-HelpMenu

$masterLoop = $true
while ($masterLoop) {
    $global:currentStage = "MainMenu"
    Write-Host "==========================================================================================" -ForegroundColor Gray
    Write-Host " SMB File Lock Engine - Choose Audit Mode:" -ForegroundColor Green
    Write-Host "   [1] Search by USERNAME"
    Write-Host "   [2] Search by FILE NAME or PATH"
    Write-Host "   [E] Exit Utility"
    Write-Host "==========================================================================================" -ForegroundColor Gray
    
    $mainChoice = Get-ValidatedInput -PromptMessage "Select a mode"
    
    if ($mainChoice -match '^[eEcC]$') { 
        Exit 
    }
    elseif ($mainChoice -eq "1") {
        $global:currentStage = "UsernameInput"
        $global:searchMode = "User"
        $global:searchString = Get-ValidatedInput -PromptMessage "Enter the username"
    }
    elseif ($mainChoice -eq "2") {
        $global:currentStage = "PathInput"
        $global:searchMode = "Path"
        $global:searchString = Get-ValidatedInput -PromptMessage "Enter the file name or partial path"
    }
    else {
        Write-Host "[ERROR] Invalid selection. Choose 1, 2, or E." -ForegroundColor Red
        Start-Sleep -Seconds 1.5
        continue
    }

    if ([string]::IsNullOrWhiteSpace($global:searchString)) {
        Write-Warning "Search parameters cannot be empty."
        Start-Sleep -Seconds 1.5
        continue
    }

    Update-OpenFiles

    if ($global:fileList.Count -eq 0) {
        Write-Host "No open files found matching query string: '$global:searchString'." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        continue
    }

    $global:currentStage = "MenuSelection"
    $operationLoop = $true

    while ($operationLoop) {
        if ($global:fileList.Count -eq 0) {
            Write-Host "`nAll matching file handles successfully released!" -ForegroundColor Green
            Start-Sleep -Seconds 1.5
            $operationLoop = $false
            break
        }

        Write-Host "`n==========================================================================================" -ForegroundColor Gray
        Write-Host "Active Handles Matching Query Context: '$global:searchString'" -ForegroundColor Green
        
        $global:fileList | Format-Table -Property Index, ClientUserName, Permissions, Path -Wrap -AutoSize | Out-String | Write-Host

        Write-Host "Operations Dashboard Options:"
        Write-Host "  [1 to $($global:fileList.Count)] : Select index to close lock & clean ghost files"
        Write-Host "  [S]          : Terminate listed users' entire SMB Session structure"
        Write-Host "  [R]          : Refresh the active handle stream"
        Write-Host "  [M]          : Return to main menu (New Search)"
        Write-Host "  [E]          : Exit and close shell environment"
        Write-Host "  [Help]       : View application manual syntax"
        Write-Host "==========================================================================================" -ForegroundColor Gray
        
        $choice = Get-ValidatedInput -PromptMessage "Enter your execution choice"
        
        if ($choice -match '^[eEcC]$') {
            Write-Host "Terminating shell..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            Exit
        }
        elseif ($choice -match '^[mM]$') {
            Write-Host "Returning to Main Menu..." -ForegroundColor Gray
            $operationLoop = $false
            break
        }
        elseif ($choice -match '^[rR]$') {
            Update-OpenFiles
            Write-Host "List synchronized!" -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        elseif ($choice -match '^[sS]$') {
            Write-Host "`nIsolating and terminating active SMB session infrastructures..." -ForegroundColor Red
            $targetUsers = $global:fileList | Select-Object -ExpandProperty ClientUserName -Unique
            foreach ($user in $targetUsers) {
                Get-SmbSession | Where-Object { $_.ClientUserName -eq $user } | Close-SmbSession -Force
            }
            Write-Host "Target SMB Session infrastructures severed safely." -ForegroundColor Green
            Start-Sleep -Seconds 1.5
            Update-OpenFiles
        }
        elseif ($choice -match '^\d+$') {
            $selectedIndex = [int]$choice
            if ($selectedIndex -ge 1 -and $selectedIndex -le $global:fileList.Count) {
                $targetFile = $global:fileList[$selectedIndex - 1]
                $filePath = $targetFile.Path
                
                Write-Host "`nClosing SMB file lock: $filePath..." -ForegroundColor DarkYellow
                $targetFile.NativeObject | Close-SmbOpenFile -Force
                Write-Host "SMB lock released!" -ForegroundColor Green
                
                $parentDir = Split-Path $filePath -Parent
                $fileName  = Split-Path $filePath -Leaf
                
                if ($fileName -like "*.xlsx" -or $fileName -like "*.xls" -or $fileName -like "*.xlsm") {
                    $ghostFilePath = Join-Path $parentDir ("~$" + $fileName)
                    Write-Host "Auditing for MS Office temporary lock architecture..." -ForegroundColor Gray
                    if (Test-Path $ghostFilePath -ErrorAction SilentlyContinue) {
                        Write-Host "Found ghost lock file! Executing structural purge..." -ForegroundColor DarkYellow
                        try {
                            Remove-Item $ghostFilePath -Force -ErrorAction Stop
                            Write-Host "Successfully deleted the ghost lock file!" -ForegroundColor Green
                        } catch {
                            Write-Warning "Could not force delete $ghostFilePath. File system locks may be releasing slowly."
                        }
                    } else {
                        Write-Host "[OK] No ghost lock file exists for this asset." -ForegroundColor Green
                    }
                } else {
                    Write-Host "[OK] Target asset is not an Excel workbook." -ForegroundColor Gray
                }
                
                Update-OpenFiles
                Start-Sleep -Seconds 1.5
            }
            else {
                Write-Host "`n[ERROR] '$choice' is out of range." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        else {
            Write-Host "`n[ERROR] '$choice' is not a valid runtime option." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}