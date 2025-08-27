# Network File Monitor

PowerShell script that monitors network file accessibility with automatic logging and rotation.

## Usage

1. Edit these variables in the script:
```powershell
$NetworkDrive = "\\your-server\share"
$FileName = "your-file.txt"
$LogPath = "C:\Your\Path\monitoring.log"
$LoopIntervalMinutes = 1
```

2. Run the script:
```powershell
.\NetworkFileReadLoop.ps1
```

## Features

- Continuous monitoring with configurable intervals
- Detailed logging with timestamps
- Automatic log rotation (removes oldest 10% when file reaches 100MB)
- Success/failure statistics
- Performance metrics

## Requirements

- PowerShell 5.1+
- Network access to target location
- Write permissions for log directory
