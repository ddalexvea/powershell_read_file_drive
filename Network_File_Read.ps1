# PowerShell script to read a file from network drive in a loop
# Variables - Change these as needed
$NetworkDrive = "\\tsclient\Downloads"
$FileName = "example.txt"
$LogPath = "C:\Test\NetworkFileReadLoop.log"
$Verbose = $true
$LoopIntervalMinutes = 1  # Loop interval in minutes
$MaxIterations = 0        # Set to 0 for infinite loop, or specify max iterations
$EnableLoop = $true       # Set to false to run only once

# Log rotation settings
$MaxLogSizeMB = 100        # Maximum log file size in MB before rotation

# Construct full file path
$FilePath = Join-Path $NetworkDrive $FileName

# Ensure log directory exists
$LogDirectory = Split-Path $LogPath -Parent
if (!(Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# Function to rotate log file when it gets too large
function Rotate-Log {
    try {
        if (Test-Path $LogPath) {
            $LogFile = Get-Item $LogPath
            $LogSizeMB = [math]::Round($LogFile.Length / 1MB, 2)
            
            if ($LogSizeMB -ge $MaxLogSizeMB) {
                Write-Host "Log file size ($LogSizeMB MB) exceeds limit ($MaxLogSizeMB MB). Rotating log..." -ForegroundColor Yellow
                
                # Read all lines from the log file
                $AllLines = Get-Content $LogPath
                
                if ($AllLines.Count -gt 10) {  # Only rotate if we have more than 10 lines
                    # Calculate how many lines to remove (10% of current file size)
                    $CurrentFileSizeBytes = $LogFile.Length
                    $BytesToRemove = [math]::Floor($CurrentFileSizeBytes * 0.10)  # 10% of current size
                    $AverageBytesPerLine = $CurrentFileSizeBytes / $AllLines.Count
                    $LinesToRemove = [math]::Floor($BytesToRemove / $AverageBytesPerLine)
                    
                    # Ensure we remove at least 1 line but not more than 90% of total lines
                    $LinesToRemove = [math]::Max(1, [math]::Min($LinesToRemove, [math]::Floor($AllLines.Count * 0.9)))
                    
                    # Keep the newer lines (remove the oldest)
                    $LinesToKeep = $AllLines | Select-Object -Skip $LinesToRemove
                    
                    # Create rotation header
                    $RotationHeader = @(
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [WARNING] - Log rotated: removed oldest $LinesToRemove lines (~10% of file size), kept $($LinesToKeep.Count) newer lines",
                        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] - Previous log size: $LogSizeMB MB, Lines before rotation: $($AllLines.Count), Removed: $LinesToRemove lines"
                    )
                    
                    # Write the kept lines and rotation info back to the file (rotation info at the end)
                    $LinesToKeep + $RotationHeader | Set-Content $LogPath
                    
                    # Calculate new file size
                    $NewFileSize = [math]::Round((Get-Item $LogPath).Length / 1MB, 2)
                    Write-Host "Log rotation completed. Removed $LinesToRemove oldest lines. New size: $NewFileSize MB" -ForegroundColor Green
                } else {
                    Write-Host "Log file has too few lines ($($AllLines.Count)) for rotation. Minimum 10 lines required." -ForegroundColor Yellow
                }
            }
        }
    } catch {
        Write-Host "Error during log rotation: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to write to log with timestamp and automatic rotation
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    # Check if log rotation is needed before writing
    Rotate-Log
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] - $Message"
    Add-Content -Path $LogPath -Value $LogEntry
    
    if ($Verbose -or $Level -eq "ERROR") {
        Write-Host $LogEntry -ForegroundColor $(if($Level -eq "ERROR"){"Red"}elseif($Level -eq "SUCCESS"){"Green"}elseif($Level -eq "WARNING"){"Yellow"}else{"White"})
    }
}

# Function to read network file
function Read-NetworkFile {
    param([int]$IterationNumber)
    
    Write-Log "=== Network File Read Operation Started (Iteration $IterationNumber) ===" "INFO"
    
    try {
        # Check if network drive is accessible
        if (!(Test-Path $NetworkDrive)) {
            throw "Network drive $NetworkDrive is not accessible or not mapped"
        }
        Write-Log "Network drive $NetworkDrive is accessible" "SUCCESS"

        # Check if target file exists
        if (!(Test-Path $FilePath)) {
            throw "Target file $FilePath does not exist"
        }
        Write-Log "Target file exists and is accessible" "SUCCESS"

        # Get file information
        $FileInfo = Get-Item $FilePath
        Write-Log "File details:" "INFO"
        Write-Log "  Size: $($FileInfo.Length) bytes" "INFO"
        Write-Log "  Created: $($FileInfo.CreationTime)" "INFO"
        Write-Log "  Modified: $($FileInfo.LastWriteTime)" "INFO"

        # Read the file (test read operation)
        $StartTime = Get-Date
        $FileContent = Get-Content -Path $FilePath -ErrorAction Stop
        $EndTime = Get-Date
        $ReadDuration = ($EndTime - $StartTime).TotalMilliseconds
        
        $LineCount = if ($FileContent) { $FileContent.Count } else { 0 }
        
        Write-Log "File read operation completed successfully" "SUCCESS"
        Write-Log "  Lines read: $LineCount" "INFO"
        Write-Log "  Read duration: $ReadDuration ms" "INFO"
        
        return $true
        
    } catch {
        Write-Log "Failed to read file: $($_.Exception.Message)" "ERROR"
        Write-Log "Error type: $($_.Exception.GetType().FullName)" "ERROR"
        if ($_.Exception.InnerException) {
            Write-Log "Inner exception: $($_.Exception.InnerException.Message)" "ERROR"
        }
        return $false
    }
    
    Write-Log "=== Network File Read Operation Completed (Iteration $IterationNumber) ===" "SUCCESS"
}

# Main execution starts here
Write-Log "=== NETWORK FILE READ LOOP SCRIPT STARTED ===" "INFO"
Write-Log "Configuration:" "INFO"
Write-Log "  Network Drive: $NetworkDrive" "INFO"
Write-Log "  File Name: $FileName" "INFO"
Write-Log "  Full Path: $FilePath" "INFO"
Write-Log "  Log Path: $LogPath" "INFO"
Write-Log "  Loop Interval: $LoopIntervalMinutes minute(s)" "INFO"
Write-Log "  Max Iterations: $(if($MaxIterations -eq 0){'Infinite'}else{$MaxIterations})" "INFO"
Write-Log "  Loop Enabled: $EnableLoop" "INFO"
Write-Log "Log Rotation Settings:" "INFO"
Write-Log "  Max Log Size: $MaxLogSizeMB MB" "INFO"
Write-Log "  Rotation Method: Remove oldest 10% of file size when limit exceeded" "INFO"
Write-Log "Runtime Info:" "INFO"
Write-Log "  Service Account: $env:USERNAME" "INFO"
Write-Log "  Computer: $env:COMPUTERNAME" "INFO"
Write-Log "  PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"

$IterationCount = 0
$SuccessfulReads = 0
$FailedReads = 0

try {
    do {
        $IterationCount++
        Write-Log "Starting iteration $IterationCount" "INFO"
        
        # Display summary for console
        if ($Verbose -and $IterationCount -gt 1) {
            Write-Host "`n=== ITERATION $IterationCount STARTING ===" -ForegroundColor Cyan
            Write-Host " Previous Stats: $SuccessfulReads successful, $FailedReads failed" -ForegroundColor White
            Write-Host " Next check scheduled at: $(Get-Date -Date (Get-Date).AddMinutes($LoopIntervalMinutes) -Format 'HH:mm:ss')" -ForegroundColor White
        }
        
        # Perform the file read operation
        $ReadSuccess = Read-NetworkFile -IterationNumber $IterationCount
        
        if ($ReadSuccess) {
            $SuccessfulReads++
        } else {
            $FailedReads++
        }
        
        # Log iteration summary
        Write-Log "Iteration $IterationCount completed. Success: $ReadSuccess" "INFO"
        Write-Log "Total Stats - Successful: $SuccessfulReads, Failed: $FailedReads" "INFO"
        
        # Check if we should continue looping
        $ShouldContinue = $EnableLoop -and ($MaxIterations -eq 0 -or $IterationCount -lt $MaxIterations)
        
        if ($ShouldContinue) {
            $NextRunTime = (Get-Date).AddMinutes($LoopIntervalMinutes)
            Write-Log "Waiting $LoopIntervalMinutes minute(s) until next iteration (next run: $($NextRunTime.ToString('HH:mm:ss')))" "INFO"
            
            # Sleep for the specified interval (convert minutes to seconds)
            Start-Sleep -Seconds ($LoopIntervalMinutes * 60)
        }
        
    } while ($ShouldContinue)
    
} catch {
    Write-Log "Critical error in main loop: $($_.Exception.Message)" "ERROR"
    exit 1
} finally {
    # Final summary
    Write-Log "=== NETWORK FILE READ LOOP SCRIPT COMPLETED ===" "INFO"
    Write-Log "Final Statistics:" "INFO"
    Write-Log "  Total Iterations: $IterationCount" "INFO"
    Write-Log "  Successful Reads: $SuccessfulReads" "INFO"
    Write-Log "  Failed Reads: $FailedReads" "INFO"
    Write-Log "  Success Rate: $(if($IterationCount -gt 0){[math]::Round(($SuccessfulReads / $IterationCount) * 100, 2)}else{0})%" "INFO"
    
    if ($Verbose) {
        Write-Host "`n=== FINAL SUMMARY ===" -ForegroundColor Cyan
        Write-Host " Total iterations completed: $IterationCount" -ForegroundColor Green
        Write-Host " Successful reads: $SuccessfulReads" -ForegroundColor Green
        Write-Host " Failed reads: $FailedReads" -ForegroundColor $(if($FailedReads -gt 0){"Red"}else{"Green"})
        Write-Host " Success rate: $(if($IterationCount -gt 0){[math]::Round(($SuccessfulReads / $IterationCount) * 100, 2)}else{0})%" -ForegroundColor Green
        Write-Host " Log file location: $LogPath" -ForegroundColor Green
    }
}
 
