#Requires -Version 5.1
<#
.SYNOPSIS
    Universal Smart Logging Framework with Environment-Aware Output Management

.DESCRIPTION
    Enterprise-grade logging framework that provides intelligent logging adaptation
    to development, production, and CI environments. Features structured logging,
    automatic log rotation, compression, performance tracking, and cross-platform support.

.NOTES
    Author: Avanade Modern Workplace Engineering
    Version: 3.0.0
    Compatible: PowerShell 5.1+ (Windows/Linux/macOS)
    License: MIT

.LINK
    https://github.com/avanade/smart-logging-framework
#>

#region Module Initialization
$Script:Context = $null
$Script:PerformanceTimers = @{}

#region Smart Logging Configuration
$Script:LoggingConfig = [PSCustomObject]@{
    # Enhanced Environment Detection
    IsProduction = $env:COMPUTERNAME -match '(PROD|PRD|CORP|ENTERPRISE|AVANADE)' -or
                   $env:USERDNSDOMAIN -match '(corp|avanade|production)' -or
                   ($PWD.Path -notmatch 'OneDrive|Development|Dev|temp|test' -and $env:USERPROFILE -notmatch 'OneDrive')
    
    IsDevelopment = $PWD.Path -match '(OneDrive|Development|Dev|temp|test)' -or 
                    $env:USERPROFILE -match 'OneDrive' -or
                    $env:NODE_ENV -eq 'development'
    
    IsCI = $env:CI -eq 'true' -or 
           $env:GITHUB_ACTIONS -eq 'true' -or 
           $env:AZURE_PIPELINES -eq 'true' -or
           $env:TF_BUILD -eq 'true'

    # Enhanced Logging Strategies
    LogLevel = if ($env:LOG_LEVEL) { $env:LOG_LEVEL }
               elseif ($env:COMPUTERNAME -match '(PROD|PRD|CORP|ENTERPRISE|AVANADE)') { 'INFO' }
               elseif ($PWD.Path -match '(OneDrive|Development|Dev|temp|test)') { 'DEBUG' }
               else { 'INFO' }

    # Output Control
    SuppressVerbose = -not ($VerbosePreference -eq 'Continue')
    UseInteractiveOutput = $Host.UI.SupportsVirtualTerminal -and 
                          -not ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')

    # Enhanced File Management
    MaxLogSizeMB = if ($env:COMPUTERNAME -match '(PROD|PRD|CORP)') { 100 } else { 50 }
    LogRetentionDays = if ($env:COMPUTERNAME -match '(PROD|PRD|CORP)') { 90 } else { 30 }
    EnableLogRotation = $true
    EnableCompression = $true
    
    # Cross-platform paths
    DefaultLogBase = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'C:\temp\logs' } else { '/tmp/logs' }
}
#endregion Smart Logging Configuration

#region Core Logging Functions
<#
.SYNOPSIS
    Writes a structured log message with specified level and component.

.DESCRIPTION
    Advanced logging function providing structured logging with support for multiple
    log levels, components, output destinations, and cross-platform compatibility.

.PARAMETER Message
    The message to log. This parameter is mandatory.

.PARAMETER Level
    The log level. Valid values: DEBUG, INFO, WARN, ERROR, SUCCESS, PROGRESS. Default: INFO

.PARAMETER Component
    The component or script name generating the log entry. Default: calling script filename

.PARAMETER ToConsoleOnly
    Switch to output only to console, not to log file.

.PARAMETER ToFileOnly
    Switch to output only to log file, not to console.

.PARAMETER SkipTimestamp
    Switch to skip timestamp in the log output.

.PARAMETER Data
    Additional structured data to include in the log entry.

.EXAMPLE
    Write-SmartLog -Message "Process completed successfully" -Level "SUCCESS"

.EXAMPLE
    Write-SmartLog -Message "Configuration error detected" -Level "ERROR" -Component "Config"

.EXAMPLE
    Write-SmartLog -Message "User action" -Level "INFO" -Data @{UserId="123"; Action="Login"}

.NOTES
    Requires Initialize-SmartLogging to be called first to set up logging configuration.
#>
function Write-SmartLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "SUCCESS", "PROGRESS")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$Component = ($MyInvocation.PSCommandPath | Split-Path -Leaf),

        [Parameter(Mandatory = $false)]
        [switch]$ToConsoleOnly,

        [Parameter(Mandatory = $false)]
        [switch]$ToFileOnly,

        [Parameter(Mandatory = $false)]
        [switch]$SkipTimestamp,

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )

    # Structured log entry
    $Timestamp = if (-not $SkipTimestamp) { Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff" } else { "" }
    $ProcessId = $PID
    $ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    $User = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }

    # Create structured entry for file logging
    $StructuredEntry = if ($SkipTimestamp) {
        "[$Level] [$Component] $Message"
    } else {
        "$Timestamp [$Level] [$($ProcessId):$($ThreadId)] [$User] [$Component] $Message"
    }

    # Add structured data if provided
    if ($Data.Count -gt 0) {
        $DataJson = $Data | ConvertTo-Json -Compress
        $StructuredEntry += " | Data: $DataJson"
    }

    # Clean entry for console
    $CleanEntry = if ($SkipTimestamp) {
        "[$Level] $Message"
    } else {
        "$(Get-Date -Format "HH:mm:ss") [$Level] $Message"
    }

    # Console output with level-based filtering
    if (-not $ToFileOnly -and $Script:LoggingConfig.UseInteractiveOutput) {
        $ShowConsole = $Level -in @('WARN', 'ERROR', 'SUCCESS', 'PROGRESS') -or
                       $VerbosePreference -eq 'Continue' -or
                       ($Level -eq 'INFO' -and -not $Script:LoggingConfig.SuppressVerbose)

        if ($ShowConsole) {
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                Write-Information $CleanEntry -InformationAction Continue
            } else {
                Write-Output $CleanEntry
            }
        }
    }

    # File logging (always enabled unless ToConsoleOnly)
    if (-not $ToConsoleOnly -and $Script:Context -and $Script:Context.LogFile) {
        try {
            # Check log rotation before writing
            if ($Script:LoggingConfig.EnableLogRotation) {
                Test-LogRotation -LogPath $Script:Context.LogFile
            }

            Add-Content -Path $Script:Context.LogFile -Value $StructuredEntry -ErrorAction Stop -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file '$($Script:Context.LogFile)': $($_.Exception.Message)"
        }
    }

    # PowerShell streams for pipeline compatibility
    switch ($Level) {
        'DEBUG' { Write-Debug $Message }
        'WARN' { Write-Warning $Message }
        'ERROR' { Write-Error $Message -ErrorAction Continue }
        'VERBOSE' { Write-Verbose $Message }
        default { Write-Information $Message -InformationAction Continue }
    }
}

<#
.SYNOPSIS
    Legacy Write-StructuredLog function for backward compatibility.

.DESCRIPTION
    Provides compatibility with existing Write-StructuredLog calls by mapping
    to the new Write-SmartLog function with appropriate parameter conversion.

.PARAMETER Message
    The log message to write.

.PARAMETER Level
    The log level (Info, Warning, Error, Debug).

.PARAMETER Component
    The component or function generating the log entry.

.PARAMETER LogPath
    Optional path to write log file. Uses Context.LogFile if not specified.

.EXAMPLE
    Write-StructuredLog -Message "Process started" -Level Info -Component "Main"
#>
function Write-StructuredLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$Component = 'General',

        [Parameter()]
        [string]$LogPath
    )

    # Map legacy levels to new levels
    $NewLevel = switch ($Level) {
        'Info' { 'INFO' }
        'Warning' { 'WARN' }
        'Error' { 'ERROR' }
        'Debug' { 'DEBUG' }
        default { 'INFO' }
    }

    # If LogPath is specified, temporarily override context
    if ($LogPath -and $Script:Context) {
        $OriginalLogFile = $Script:Context.LogFile
        $Script:Context.LogFile = $LogPath
        Write-SmartLog -Message $Message -Level $NewLevel -Component $Component
        $Script:Context.LogFile = $OriginalLogFile
    } else {
        Write-SmartLog -Message $Message -Level $NewLevel -Component $Component
    }
}
#endregion Core Logging Functions

#region Log Rotation and Management
function Test-LogRotation {
    <#
    .SYNOPSIS
        Tests if log rotation is needed and performs rotation if necessary.
    .PARAMETER LogPath
        Path to the log file to check for rotation.
    #>
    param([string]$LogPath)

    if (-not (Test-Path $LogPath)) { return }

    $LogFile = Get-Item $LogPath
    $LogSizeMB = [Math]::Round($LogFile.Length / 1MB, 2)

    if ($LogSizeMB -gt $Script:LoggingConfig.MaxLogSizeMB) {
        $RotatedPath = $LogPath -replace '\.(log|txt)$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').$($Matches[1])"
        Move-Item -Path $LogPath -Destination $RotatedPath -Force

        # Compress rotated log if in production environment
        if ($Script:LoggingConfig.EnableCompression -and $Script:LoggingConfig.IsProduction) {
            Compress-LogFile -LogPath $RotatedPath -RemoveOriginal $true
        } else {
            Write-SmartLog "Log rotated: $($LogSizeMB)MB → $RotatedPath" -Level 'INFO' -Component 'LogRotation'
        }
    }
}

function Clear-OldLogs {
    <#
    .SYNOPSIS
        Clears old log files based on retention policy.
    .PARAMETER LogDirectory
        Directory containing logs to clean up.
    #>
    param([string]$LogDirectory)

    if (-not (Test-Path $LogDirectory)) { return }

    $CutoffDate = (Get-Date).AddDays(-$Script:LoggingConfig.LogRetentionDays)
    $OldLogs = Get-ChildItem -Path $LogDirectory -Filter "*.log" |
               Where-Object { $_.LastWriteTime -lt $CutoffDate }

    if ($OldLogs) {
        foreach ($LogFile in $OldLogs) {
            if ($Script:LoggingConfig.EnableCompression) {
                Compress-LogFile -LogPath $LogFile.FullName -RemoveOriginal $true
            } else {
                Remove-Item -Path $LogFile.FullName -Force
            }
        }
        Write-SmartLog "Processed $($OldLogs.Count) old log files (>$($Script:LoggingConfig.LogRetentionDays) days)" -Level 'INFO' -Component 'LogCleanup'
    }
}

function Compress-LogFile {
    <#
    .SYNOPSIS
        Compresses log files to save disk space in production environments.
    .PARAMETER LogPath
        Path to the log file to compress.
    .PARAMETER RemoveOriginal
        Whether to remove the original file after compression.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $false)]
        [bool]$RemoveOriginal = $true
    )

    try {
        if (-not (Test-Path $LogPath)) {
            Write-Warning "Log file not found: $LogPath"
            return
        }

        if (-not $Script:LoggingConfig.EnableCompression) {
            Write-Verbose "Log compression disabled, skipping: $LogPath"
            return
        }

        $LogFile = Get-Item $LogPath
        $CompressedPath = $LogPath -replace '\.(log|txt)$', "_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"

        # Use .NET compression for cross-platform compatibility
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Create temporary directory
        $TempDir = New-TemporaryFile | ForEach-Object { 
            Remove-Item $_ -Force
            New-Item -ItemType Directory -Path $_ -Force
        }
        $TempLogPath = Join-Path $TempDir.FullName $LogFile.Name

        # Copy to temp and compress
        Copy-Item -Path $LogPath -Destination $TempLogPath -Force
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $TempDir.FullName, 
            $CompressedPath, 
            [System.IO.Compression.CompressionLevel]::Optimal, 
            $false
        )

        # Calculate compression metrics
        $OriginalSizeMB = [Math]::Round($LogFile.Length / 1MB, 2)
        $CompressedSizeMB = [Math]::Round((Get-Item $CompressedPath).Length / 1MB, 2)
        $CompressionRatio = [Math]::Round((1 - ($CompressedSizeMB / $OriginalSizeMB)) * 100, 1)

        if ($RemoveOriginal) {
            Remove-Item -Path $LogPath -Force
            Write-SmartLog "Log compressed: $($LogFile.Name) ($($OriginalSizeMB)MB → $($CompressedSizeMB)MB, $($CompressionRatio)% reduction)" -Level 'INFO' -Component 'LogCompression'
        } else {
            Write-SmartLog "Log archived: $($LogFile.Name) ($($OriginalSizeMB)MB → $($CompressedSizeMB)MB, $($CompressionRatio)% reduction)" -Level 'INFO' -Component 'LogCompression'
        }

        # Cleanup
        Remove-Item -Path $TempDir.FullName -Recurse -Force

    } catch {
        Write-Error "Failed to compress log file '$LogPath': $($_.Exception.Message)"
        if ($TempDir -and (Test-Path $TempDir.FullName)) {
            Remove-Item -Path $TempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
#endregion Log Rotation and Management

#region Progress and Section Management
function Write-Progress-Start {
    <#
    .SYNOPSIS
        Starts a progress operation with logging.
    #>
    param(
        [string]$Activity,
        [string]$Status = "Starting...",
        [int]$Id = 0
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete 0 -Id $Id
    Write-SmartLog "Started: $Activity - $Status" -Level 'PROGRESS'
}

function Write-Progress-Update {
    <#
    .SYNOPSIS
        Updates progress with logging.
    #>
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [int]$Id = 0
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
    Write-SmartLog "Progress: $Activity - $Status ($PercentComplete%)" -Level 'PROGRESS' -ToFileOnly
}

function Write-Progress-Complete {
    <#
    .SYNOPSIS
        Completes a progress operation with logging.
    #>
    param(
        [string]$Activity,
        [int]$Id = 0
    )
    Write-Progress -Activity $Activity -Completed -Id $Id
    Write-SmartLog "Completed: $Activity" -Level 'SUCCESS'
}

function Write-Section-Start {
    <#
    .SYNOPSIS
        Writes a section header to the log.
    #>
    param(
        [string]$Title,
        [string]$Icon = ">"
    )
    $Border = "=" * 60
    Write-SmartLog $Border -Level 'INFO' -SkipTimestamp
    Write-SmartLog "$Icon $Title" -Level 'INFO' -SkipTimestamp
    Write-SmartLog $Border -Level 'INFO' -SkipTimestamp
}

function Write-Section-End {
    <#
    .SYNOPSIS
        Writes a section footer with completion status.
    #>
    param(
        [string]$Title,
        [string]$Status = "COMPLETED",
        [timespan]$Duration
    )
    $StatusIcon = switch ($Status) {
        "COMPLETED" { "[OK]" }
        "FAILED" { "[FAIL]" }
        default { "[INFO]" }
    }
    $DurationText = if ($Duration) { " ($('{0:F2}' -f $Duration.TotalSeconds)s)" } else { "" }
    Write-SmartLog "$StatusIcon $Title $Status$DurationText" -Level 'SUCCESS' -SkipTimestamp
    Write-SmartLog "" -Level 'INFO' -SkipTimestamp
}
#endregion Progress and Section Management

#region Error Handling
function Write-Error-Context {
    <#
    .SYNOPSIS
        Writes detailed error context with structured information.
    #>
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Context = "General Error",
        [hashtable]$AdditionalInfo = @{}
    )

    $ErrorDetails = @{
        Message = $ErrorRecord.Exception.Message
        ScriptName = $ErrorRecord.InvocationInfo.ScriptName
        LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
        Command = $ErrorRecord.InvocationInfo.MyCommand.Name
        Context = $Context
        Timestamp = Get-Date -Format "o"
    }

    # Add additional context
    foreach ($key in $AdditionalInfo.Keys) {
        $ErrorDetails[$key] = $AdditionalInfo[$key]
    }

    # Log structured error
    $ErrorJson = $ErrorDetails | ConvertTo-Json -Compress
    Write-SmartLog "ERROR_CONTEXT: $ErrorJson" -Level 'ERROR' -Component 'ErrorHandler'

    # User-friendly console output
    Write-SmartLog "Error in $Context`: $($ErrorRecord.Exception.Message)" -Level 'ERROR'
    Write-SmartLog "Location: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)" -Level 'ERROR'
}
#endregion Error Handling

#region Performance Tracking
function Start-PerformanceTimer {
    <#
    .SYNOPSIS
        Starts a performance timer for an operation.
    #>
    param([string]$OperationName)

    if (-not $Script:PerformanceTimers) { $Script:PerformanceTimers = @{} }
    $Script:PerformanceTimers[$OperationName] = [System.Diagnostics.Stopwatch]::StartNew()
    Write-SmartLog "Performance timer started: $OperationName" -Level 'DEBUG' -Component 'Performance'
}

function Stop-PerformanceTimer {
    <#
    .SYNOPSIS
        Stops a performance timer and optionally logs the result.
    #>
    param(
        [string]$OperationName,
        [switch]$LogResult
    )

    if ($Script:PerformanceTimers -and $Script:PerformanceTimers.ContainsKey($OperationName)) {
        $Timer = $Script:PerformanceTimers[$OperationName]
        $Timer.Stop()
        $Duration = $Timer.Elapsed
        $DurationMs = [Math]::Round($Duration.TotalMilliseconds, 2)

        if ($LogResult) {
            Write-SmartLog "Performance: $OperationName completed in $DurationMs ms" -Level 'INFO' -Component 'Performance'
        }

        $Script:PerformanceTimers.Remove($OperationName)
        return $Duration
    } else {
        Write-SmartLog "Warning: No timer found for operation '$OperationName'" -Level 'WARN' -Component 'Performance'
        return $null
    }
}
#endregion Performance Tracking

#region Log Path Management
function Get-SmartLogPath {
    <#
    .SYNOPSIS
        Generates an appropriate log file path based on environment and script context.
    #>
    param(
        [string]$ScriptName,
        [string]$LogType = "Main"
    )

    # Cross-platform base log directory selection
    $BaseLogDir = if ($Script:LoggingConfig.IsProduction) {
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            "C:\temp\logs"
        } else {
            "/tmp/logs"
        }
    } elseif ($Script:LoggingConfig.IsDevelopment) {
        Join-Path $PWD.Path "logs"
    } else {
        $Script:LoggingConfig.DefaultLogBase
    }

    $TimestampFolder = Get-Date -Format "yyyyMMdd"
    $LogDir = Join-Path $BaseLogDir $TimestampFolder

    # Ensure directory exists with cross-platform support
    if (-not (Test-Path $LogDir)) {
        try {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        } catch {
            # Fallback to workspace temp
            $FallbackDir = Join-Path $PWD.Path "temp" "logs" $TimestampFolder
            try {
                New-Item -ItemType Directory -Path $FallbackDir -Force | Out-Null
                $LogDir = $FallbackDir
            } catch {
                Write-Warning "Failed to create log directory. Using current directory."
                $LogDir = $PWD.Path
            }
        }
    }

    # Generate log file name
    $LogFileName = switch ($LogType) {
        "Transcript" { "$ScriptName-Transcript-$(Get-Date -Format 'HHmmss').log" }
        "Error" { "$ScriptName-Errors-$(Get-Date -Format 'HHmmss').log" }
        "Performance" { "$ScriptName-Performance-$(Get-Date -Format 'HHmmss').log" }
        default { "$ScriptName-$(Get-Date -Format 'HHmmss').log" }
    }

    return Join-Path $LogDir $LogFileName
}
#endregion Log Path Management

#region Initialization and Context Management
<#
.SYNOPSIS
    Initializes the SmartLogging framework for the current script.

.DESCRIPTION
    Sets up the SmartLogging context with script name, log file path, and initial state.
    Must be called before using other SmartLogging functions.

.PARAMETER ScriptName
    The name of the script that will be logging.

.PARAMETER LogType
    The type of log. Default: "Main".

.PARAMETER LogPath
    Custom log file path. If not specified, generates based on environment.

.EXAMPLE
    Initialize-SmartLogging -ScriptName "MyScript.ps1"

.EXAMPLE
    Initialize-SmartLogging -ScriptName "MyScript.ps1" -LogType "Installation"

.NOTES
    Creates a script-scoped Context object used by all other SmartLogging functions.
#>
function Initialize-SmartLogging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        
        [Parameter(Mandatory = $false)]
        [string]$LogType = "Main",
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )

    $LogFile = if ($LogPath) { $LogPath } else { Get-SmartLogPath -ScriptName $ScriptName -LogType $LogType }

    $Script:Context = [PSCustomObject]@{
        ScriptName = $ScriptName
        LogFile = $LogFile
        HasError = $false
        StartTime = Get-Date
        TestResults = @{}
        Environment = @{
            IsProduction = $Script:LoggingConfig.IsProduction
            IsDevelopment = $Script:LoggingConfig.IsDevelopment
            IsCI = $Script:LoggingConfig.IsCI
        }
    }

    Write-SmartLog "Smart logging initialized for $ScriptName" -Level 'INFO'
    Write-SmartLog "Log file: $($Script:Context.LogFile)" -Level 'DEBUG'
    Write-SmartLog "Environment: Production=$($Script:Context.Environment.IsProduction), Development=$($Script:Context.Environment.IsDevelopment), CI=$($Script:Context.Environment.IsCI)" -Level 'DEBUG'

    return $Script:Context
}

function Get-SmartLogSummary {
    <#
    .SYNOPSIS
        Generates a summary of the current logging session.
    #>
    if (-not $Script:Context) {
        Write-Warning "Smart logging not initialized. Call Initialize-SmartLogging first."
        return $null
    }

    $Duration = (Get-Date) - $Script:Context.StartTime
    $Summary = [PSCustomObject]@{
        ScriptName = $Script:Context.ScriptName
        LogFile = $Script:Context.LogFile
        Duration = $Duration
        HasError = $Script:Context.HasError
        TestResults = $Script:Context.TestResults
        Environment = $Script:Context.Environment
        LoggingConfig = $Script:LoggingConfig
    }

    Write-SmartLog "Execution summary generated" -Level 'INFO'
    return $Summary
}

function Reset-SmartLogging {
    <#
    .SYNOPSIS
        Resets the SmartLogging context and timers.
    #>
    $Script:Context = $null
    $Script:PerformanceTimers = @{}
    Write-SmartLog "Smart logging context reset" -Level 'INFO'
}
#endregion Initialization and Context Management

#region Module Exports
Export-ModuleMember -Function @(
    'Write-SmartLog',
    'Write-StructuredLog',
    'Initialize-SmartLogging',
    'Get-SmartLogSummary',
    'Reset-SmartLogging',
    'Write-Progress-Start',
    'Write-Progress-Update', 
    'Write-Progress-Complete',
    'Write-Section-Start',
    'Write-Section-End',
    'Write-Error-Context',
    'Start-PerformanceTimer',
    'Stop-PerformanceTimer',
    'Get-SmartLogPath',
    'Clear-OldLogs',
    'Compress-LogFile',
    'Test-LogRotation'
)
#endregion Module Exports
