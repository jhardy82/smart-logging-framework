#Requires -Version 5.1

<#
.SYNOPSIS
    Replaces the Initialize-SmartLogging function with a fixed version
.DESCRIPTION
    This script corrects the Initialize-SmartLogging function to properly handle
    directory vs. file paths for log creation
#>

$psm1Path = Join-Path -Path $PSScriptRoot -ChildPath "src\src\core\SmartLogging.psm1"
Write-Host "Processing: $psm1Path" -ForegroundColor Yellow

# Read the module content
$content = Get-Content -Path $psm1Path -Raw

# Original function pattern to replace (simplified match)
$oldFunctionPattern = @'
function Initialize-SmartLogging \{
(.*?)
return \$Script:Context
\}
'@

# New function with fix
$newFunction = @'
function Initialize-SmartLogging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [string]$LogType = "Main",

        [Parameter(Mandatory = $false)]
        [string]$LogPath,

        [Parameter(Mandatory = $false)]
        [string]$Environment,

        [Parameter(Mandatory = $false)]
        [hashtable]$ContextForgeConfig,

        [Parameter(Mandatory = $false)]
        [bool]$IsDebug = $false,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # Handle log file path determination first
    if ($LogPath) {
        # Check if LogPath is a directory
        if ((Test-Path -Path $LogPath -PathType Container) -or
            (-not (Test-Path -Path $LogPath) -and -not $LogPath.Contains("."))) {
            # LogPath is a directory - generate a file name within it
            $TimestampStr = Get-Date -Format "yyyyMMdd-HHmmss"
            $LogFileName = "$ScriptName-$TimestampStr.log"
            $LogFile = Join-Path -Path $LogPath -ChildPath $LogFileName

            # Ensure directory exists
            $LogDir = Split-Path -Path $LogFile -Parent
            if (-not (Test-Path -Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            }
        } else {
            # LogPath is a file path - use as-is
            $LogFile = $LogPath

            # Ensure parent directory exists
            $LogDir = Split-Path -Path $LogFile -Parent
            if (-not (Test-Path -Path $LogDir)) {
                New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
            }
        }
    } else {
        # No LogPath provided - get default path
        $LogFile = Get-SmartLogPath -ScriptName $ScriptName -LogType $LogType
    }

    # Create the context object
    $Script:Context = [PSCustomObject]@{
        ScriptName  = $ScriptName
        LogFile     = $LogFile
        LogPath     = Split-Path -Path $LogFile -Parent
        HasError    = $false
        StartTime   = Get-Date
        TestResults = @{}
        Environment = @{
            IsProduction  = $Script:LoggingConfig.IsProduction
            IsDevelopment = $Script:LoggingConfig.IsDevelopment
            IsCI          = $Script:LoggingConfig.IsCI
        }
    }

    Write-SmartLog "Smart logging initialized for $ScriptName" -Level 'INFO'
    Write-SmartLog "Log file: $($Script:Context.LogFile)" -Level 'DEBUG'
    Write-SmartLog "Environment: Production=$($Script:Context.Environment.IsProduction), Development=$($Script:Context.Environment.IsDevelopment), CI=$($Script:Context.Environment.IsCI)" -Level 'DEBUG'

    return $Script:Context
}
'@

# Replace function directly
try {
    # Find where the Initialize-SmartLogging function is defined
    $startPattern = "function Initialize-SmartLogging {"
    $endPattern = "#endregion Initialization and Context Management"

    $startIndex = $content.IndexOf($startPattern)
    $endIndex = $content.IndexOf($endPattern, $startIndex)

    if ($startIndex -lt 0 -or $endIndex -lt 0) {
        Write-Error "Could not find function boundaries in the module file"
        exit 1
    }

    # Extract the function content
    $oldFunction = $content.Substring($startIndex, $endIndex - $startIndex)

    # Replace the function
    $newContent = $content.Replace($oldFunction, $newFunction)

    # Write the modified content back to the file
    Set-Content -Path $psm1Path -Value $newContent -Force

    Write-Host "✓ Function replaced successfully" -ForegroundColor Green
} catch {
    Write-Host "✕ Error updating module: $($_.Exception.Message)" -ForegroundColor Red
}

# Make a backup of the original file
$backupPath = "$psm1Path.bak"
if (-not (Test-Path $backupPath)) {
    Copy-Item -Path $psm1Path -Destination $backupPath -Force
    Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Green
}

Write-Host "Fix completed. Run debug-test.ps1 to verify." -ForegroundColor Cyan
