#Requires -Version 5.1
<#
.SYNOPSIS
    ContextForge Integration Helper Functions for Smart Logging Framework

.DESCRIPTION
    Provides helper functions to integrate Smart Logging Framework with ContextForge patterns.
    Includes configuration management, context object enhancement, and cross-tool communication.

.NOTES
    Author: ContextForge Development Team
    Version: 1.0.0
    Compatible: PowerShell 5.1+ (Windows/Linux/macOS)
    License: MIT
    Integration Target: PowerCompany Tools Ecosystem

.LINK
    https://github.com/jhardy82/PowerCompany-smart-logging-framework
#>

#region Configuration Management Functions

<#
.SYNOPSIS
    Implements the Get-OrElse fallback pattern for configuration values.

.DESCRIPTION
    Provides null-safe fallback configuration pattern commonly used in ContextForge.
    Returns the primary value if not null/empty, otherwise returns the default value.

.PARAMETER Value
    The primary value to check. Can be null, empty, or have a value.

.PARAMETER Default
    The fallback value to use if the primary value is null or empty.

.EXAMPLE
    $logLevel = Get-OrElse -Value $config.LogLevel -Default "INFO"

.EXAMPLE
    $timeout = Get-OrElse -Value $env:TIMEOUT -Default 30
#>
function Get-OrElse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        $Value,

        [Parameter(Mandatory = $true)]
        $Default
    )

    if ($null -eq $Value -or
        ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) -or
        ($Value -is [array] -and $Value.Count -eq 0)) {
        return $Default
    }

    return $Value
}

<#
.SYNOPSIS
    Loads ContextForge configuration from standard locations.

.DESCRIPTION
    Attempts to load ContextForge configuration from multiple standard locations:
    - Environment variables
    - Local configuration files
    - Workspace configuration
    - Default fallback values

.PARAMETER ConfigPath
    Optional explicit path to configuration file.

.EXAMPLE
    $config = Get-ContextForgeConfig

.EXAMPLE
    $config = Get-ContextForgeConfig -ConfigPath ".\config\contextforge.json"
#>
function Get-ContextForgeConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Default configuration
    $defaultConfig = @{
        Environment        = $null
        IsDevelopment      = $null
        IsCI               = $null
        LogLevel           = $null
        MaxLogSizeMB       = $null
        LogRetentionDays   = $null
        EnableLogRotation  = $null
        EnableCompression  = $null
        LogBasePath        = $null
        DeploymentPhase    = "Development"
        IntegrationVersion = "1.0.0"
    }

    # Try to load from specified config path
    if ($ConfigPath -and (Test-Path $ConfigPath)) {
        try {
            if ($ConfigPath -like "*.json") {
                $fileConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
            } elseif ($ConfigPath -like "*.yml" -or $ConfigPath -like "*.yaml") {
                # Basic YAML support (would need proper YAML module for full support)
                Write-Warning "YAML configuration detected but not fully supported. Consider JSON format."
                return $defaultConfig
            }

            # Merge with defaults
            foreach ($key in $fileConfig.Keys) {
                if ($defaultConfig.ContainsKey($key)) {
                    $defaultConfig[$key] = $fileConfig[$key]
                }
            }
        } catch {
            Write-Warning "Failed to load configuration from $ConfigPath : $($_.Exception.Message)"
        }
    }

    # Try standard locations
    $standardPaths = @(
        ".\ContextForgeConfig.json",
        ".\config\ContextForge.json",
        ".\FeatureUpdateConfig.json",
        "$env:USERPROFILE\.contextforge\config.json"
    )

    foreach ($path in $standardPaths) {
        if (Test-Path $path) {
            try {
                $fileConfig = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
                foreach ($key in $fileConfig.Keys) {
                    if ($defaultConfig.ContainsKey($key) -and $null -eq $defaultConfig[$key]) {
                        $defaultConfig[$key] = $fileConfig[$key]
                    }
                }
                break
            } catch {
                Write-Verbose "Could not load config from $path : $($_.Exception.Message)"
            }
        }
    }

    # Environment variable overrides
    if ($env:CONTEXTFORGE_ENVIRONMENT) { $defaultConfig.Environment = $env:CONTEXTFORGE_ENVIRONMENT }
    if ($env:CONTEXTFORGE_LOG_LEVEL) { $defaultConfig.LogLevel = $env:CONTEXTFORGE_LOG_LEVEL }
    if ($env:CONTEXTFORGE_DEPLOYMENT_PHASE) { $defaultConfig.DeploymentPhase = $env:CONTEXTFORGE_DEPLOYMENT_PHASE }

    return $defaultConfig
}

#endregion Configuration Management Functions

#region Context Object Enhancement Functions

<#
.SYNOPSIS
    Creates an enhanced context object with ContextForge integration patterns.

.DESCRIPTION
    Extends the standard Smart Logging context object with ContextForge-specific fields
    including deployment phase, enterprise context, and cross-tool communication data.

.PARAMETER BaseContext
    The base context object to enhance.

.PARAMETER Config
    Configuration object to use for context enhancement.

.EXAMPLE
    $enhancedContext = New-ContextForgeContext -BaseContext $context -Config $config
#>
function New-ContextForgeContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$BaseContext,

        [Parameter(Mandatory = $false)]
        [hashtable]$Config = @{}
    )

    # Create enhanced context with ContextForge fields
    $enhancedContext = [PSCustomObject]@{
        # Smart-Logging Core Fields (preserve existing)
        ScriptName         = $BaseContext.ScriptName
        LogFile            = $BaseContext.LogFile
        HasError           = $BaseContext.HasError
        StartTime          = $BaseContext.StartTime
        TestResults        = if ($BaseContext.TestResults) { $BaseContext.TestResults } else { @{} }
        Environment        = if ($BaseContext.Environment) { $BaseContext.Environment } else { @{} }

        # ContextForge Standard Fields
        Timestamp          = Get-Date
        InstanceId         = [guid]::NewGuid()
        Config             = $Config

        # Enterprise Context Fields
        DeploymentPhase    = Get-OrElse -Value $Config.DeploymentPhase -Default "Development"
        SiteCode           = Get-OrElse -Value $Config.SiteCode -Default $null
        UserImpact         = Get-OrElse -Value $Config.UserImpact -Default "Low"
        RollbackPlan       = Get-OrElse -Value $Config.RollbackPlan -Default $null

        # Network Optimization Fields
        BandwidthPolicy    = Get-OrElse -Value $Config.BandwidthPolicy -Default "Normal"
        CDNEndpoint        = Get-OrElse -Value $Config.CDNEndpoint -Default $null
        LocalCacheStatus   = Get-OrElse -Value $Config.LocalCacheStatus -Default "Unknown"

        # Cross-Tool Integration Fields
        ToolName           = Get-OrElse -Value $Config.ToolName -Default "smart-logging-framework"
        IntegrationVersion = Get-OrElse -Value $Config.IntegrationVersion -Default "1.0.0"
        DependentTools     = Get-OrElse -Value $Config.DependentTools -Default @()
        CrossToolData      = Get-OrElse -Value $Config.CrossToolData -Default @{}

        # Performance Tracking
        PerformanceMetrics = @{
            InitializationTime = (Get-Date) - $BaseContext.StartTime
            MemoryUsage        = Get-OrElse -Value $Config.InitialMemoryUsage -Default 0
            LoggingOverhead    = 0
        }
    }

    return $enhancedContext
}

<#
.SYNOPSIS
    Updates context object with cross-tool communication data.

.DESCRIPTION
    Safely updates the context object with data from other PowerCompany tools,
    maintaining data structure integrity and adding communication timestamps.

.PARAMETER Context
    The context object to update.

.PARAMETER SourceTool
    Name of the tool providing the data.

.PARAMETER MessageType
    Type of cross-tool message.

.PARAMETER Data
    Data payload from the source tool.

.EXAMPLE
    Update-CrossToolContext -Context $context -SourceTool "workspace-analyzer" -MessageType "AnalysisComplete" -Data $analysisResults
#>
function Update-CrossToolContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$SourceTool,

        [Parameter(Mandatory = $true)]
        [string]$MessageType,

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{}
    )

    # Ensure CrossToolData structure exists
    if (-not $Context.CrossToolData) {
        $Context.CrossToolData = @{}
    }

    # Create message structure
    $crossToolMessage = @{
        SourceTool        = $SourceTool
        MessageType       = $MessageType
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Data              = $Data
        ContextInstanceId = $Context.InstanceId
    }

    # Add to cross-tool data with timestamp key
    $messageKey = "$SourceTool-$MessageType-$(Get-Date -Format 'HHmmss')"
    $Context.CrossToolData[$messageKey] = $crossToolMessage

    # Update dependent tools list if not already present
    if ($Context.DependentTools -notcontains $SourceTool) {
        $Context.DependentTools += $SourceTool
    }

    Write-Verbose "Updated cross-tool context: $SourceTool -> $MessageType"
}

#endregion Context Object Enhancement Functions

#region Performance and Monitoring Functions

<#
.SYNOPSIS
    Tracks performance metrics for logging operations.

.DESCRIPTION
    Monitors and records performance impact of logging operations to ensure
    minimal overhead on host applications and tools.

.PARAMETER Context
    The context object to update with performance data.

.PARAMETER OperationType
    Type of operation being measured.

.PARAMETER StartTime
    Start time of the operation.

.PARAMETER EndTime
    End time of the operation (defaults to current time).

.EXAMPLE
    Add-PerformanceMetric -Context $context -OperationType "LogWrite" -StartTime $start
#>
function Add-PerformanceMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$OperationType,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime = (Get-Date)
    )

    if (-not $Context.PerformanceMetrics) {
        $Context.PerformanceMetrics = @{}
    }

    $duration = ($EndTime - $StartTime).TotalMilliseconds

    if (-not $Context.PerformanceMetrics.$OperationType) {
        $Context.PerformanceMetrics.$OperationType = @{
            Count     = 0
            TotalMs   = 0
            AverageMs = 0
            MaxMs     = 0
            MinMs     = [double]::MaxValue
        }
    }

    $metrics = $Context.PerformanceMetrics.$OperationType
    $metrics.Count++
    $metrics.TotalMs += $duration
    $metrics.AverageMs = $metrics.TotalMs / $metrics.Count
    $metrics.MaxMs = [Math]::Max($metrics.MaxMs, $duration)
    $metrics.MinMs = [Math]::Min($metrics.MinMs, $duration)

    # Update overall logging overhead
    if ($OperationType -like "*Log*") {
        $Context.PerformanceMetrics.LoggingOverhead = $metrics.TotalMs
    }
}

<#
.SYNOPSIS
    Generates a performance summary for the current context.

.DESCRIPTION
    Creates a comprehensive performance report for logging and integration operations.

.PARAMETER Context
    The context object containing performance metrics.

.EXAMPLE
    $performanceReport = Get-PerformanceSummary -Context $context
#>
function Get-PerformanceSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context
    )

    if (-not $Context.PerformanceMetrics) {
        return @{ Message = "No performance metrics available" }
    }

    $summary = @{
        ContextAge           = (Get-Date) - $Context.StartTime
        TotalLoggingOverhead = $Context.PerformanceMetrics.LoggingOverhead
        Operations           = @{}
    }

    foreach ($operation in $Context.PerformanceMetrics.Keys) {
        if ($operation -ne "LoggingOverhead" -and $operation -ne "InitializationTime" -and $operation -ne "MemoryUsage") {
            $summary.Operations[$operation] = $Context.PerformanceMetrics[$operation]
        }
    }

    return $summary
}

#endregion Performance and Monitoring Functions

#region Utility Functions

<#
.SYNOPSIS
    Validates ContextForge integration compatibility.

.DESCRIPTION
    Performs compatibility checks to ensure proper integration between
    Smart Logging Framework and ContextForge patterns.

.PARAMETER Context
    The context object to validate.

.EXAMPLE
    $isValid = Test-ContextForgeCompatibility -Context $context
#>
function Test-ContextForgeCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context
    )

    $validationResults = @{
        IsValid  = $true
        Issues   = @()
        Warnings = @()
    }

    # Check required ContextForge fields
    $requiredFields = @('InstanceId', 'Timestamp', 'DeploymentPhase', 'ToolName', 'IntegrationVersion')
    foreach ($field in $requiredFields) {
        if (-not (Get-Member -InputObject $Context -Name $field -MemberType NoteProperty)) {
            $validationResults.Issues += "Missing required field: $field"
            $validationResults.IsValid = $false
        }
    }

    # Check for proper GUID format
    if ($Context.InstanceId -and $Context.InstanceId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        $validationResults.Issues += "InstanceId is not a valid GUID format"
        $validationResults.IsValid = $false
    }

    # Check timestamp validity
    if ($Context.Timestamp -and $Context.Timestamp -isnot [datetime]) {
        $validationResults.Issues += "Timestamp is not a valid DateTime object"
        $validationResults.IsValid = $false
    }

    # Performance warnings
    if ($Context.PerformanceMetrics -and $Context.PerformanceMetrics.LoggingOverhead -gt 100) {
        $validationResults.Warnings += "High logging overhead detected: $($Context.PerformanceMetrics.LoggingOverhead)ms"
    }

    return $validationResults
}

<#
.SYNOPSIS
    Exports context data for cross-tool consumption.

.DESCRIPTION
    Exports context and performance data in standardized format for consumption
    by other PowerCompany tools and ContextForge workflows.

.PARAMETER Context
    The context object to export.

.PARAMETER OutputPath
    Path where to save the exported context data.

.PARAMETER Format
    Export format: JSON, XML, or Hashtable (default: JSON).

.EXAMPLE
    Export-ContextForgeData -Context $context -OutputPath ".\context-export.json"
#>
function Export-ContextForgeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'XML', 'Hashtable')]
        [string]$Format = 'JSON'
    )

    # Create exportable data structure
    $exportData = @{
        ExportTimestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        ExportVersion     = "1.0.0"
        ContextData       = @{
            InstanceId         = $Context.InstanceId
            ToolName           = $Context.ToolName
            ScriptName         = $Context.ScriptName
            StartTime          = $Context.StartTime
            DeploymentPhase    = $Context.DeploymentPhase
            Environment        = $Context.Environment
            CrossToolData      = $Context.CrossToolData
            PerformanceMetrics = $Context.PerformanceMetrics
        }
        ValidationResults = Test-ContextForgeCompatibility -Context $Context
    }

    if ($Format -eq 'Hashtable') {
        return $exportData
    }

    # Convert to requested format
    $exportString = switch ($Format) {
        'JSON' { $exportData | ConvertTo-Json -Depth 10 }
        'XML' { $exportData | ConvertTo-Xml -As String -NoTypeInformation }
        default { $exportData | ConvertTo-Json -Depth 10 }
    }

    # Save to file if path specified
    if ($OutputPath) {
        try {
            $exportString | Set-Content -Path $OutputPath -Encoding UTF8
            Write-Verbose "Context data exported to: $OutputPath"
        } catch {
            Write-Error "Failed to export context data to $OutputPath : $($_.Exception.Message)"
        }
    }

    return $exportString
}

#endregion Utility Functions

# Export functions for module consumption
Export-ModuleMember -Function @(
    'Get-OrElse',
    'Get-ContextForgeConfig',
    'New-ContextForgeContext',
    'Update-CrossToolContext',
    'Add-PerformanceMetric',
    'Get-PerformanceSummary',
    'Test-ContextForgeCompatibility',
    'Export-ContextForgeData'
)
