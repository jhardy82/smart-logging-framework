#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI interface for the Universal Smart Logging Framework

.DESCRIPTION
    Command-line interface for initializing, testing, and managing the Smart Logging Framework.
    Provides enterprise-grade logging utilities for PowerShell scripts and applications.

.PARAMETER Action
    The action to perform: Initialize, Test, Clean, Compress, Summary

.PARAMETER ScriptName
    Name of the script to initialize logging for

.PARAMETER LogType
    Type of log: Main, Error, Performance, Transcript

.PARAMETER LogPath
    Custom log file path

.PARAMETER MaxAgeDays
    Maximum age of logs to keep (for Clean action)

.PARAMETER LogDirectory
    Directory containing logs to manage

.PARAMETER Level
    Log level for test messages: DEBUG, INFO, WARN, ERROR, SUCCESS

.PARAMETER Message
    Custom test message

.PARAMETER OutputFormat
    Output format: Console, JSON, Table

.PARAMETER Force
    Force operations without confirmation

.EXAMPLE
    .\Invoke-SmartLogging.ps1 -Action Initialize -ScriptName "MyScript.ps1"
    Initializes smart logging for MyScript.ps1

.EXAMPLE
    .\Invoke-SmartLogging.ps1 -Action Test -Level INFO -Message "Test message"
    Writes a test log message

.EXAMPLE
    .\Invoke-SmartLogging.ps1 -Action Clean -LogDirectory "C:\temp\logs" -MaxAgeDays 30
    Cleans logs older than 30 days

.EXAMPLE
    .\Invoke-SmartLogging.ps1 -Action Summary -OutputFormat JSON
    Displays logging summary in JSON format

.NOTES
    Author: [EMPLOYER_NAME] Modern Workplace Engineering
    Version: 3.0.0
    Requires: PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Initialize', 'Test', 'Clean', 'Compress', 'Summary', 'Reset', 'Demo')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$ScriptName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Main', 'Error', 'Performance', 'Transcript')]
    [string]$LogType = 'Main',

    [Parameter(Mandatory = $false)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [int]$MaxAgeDays = 30,

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS', 'PROGRESS')]
    [string]$Level = 'INFO',

    [Parameter(Mandatory = $false)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Console', 'JSON', 'Table')]
    [string]$OutputFormat = 'Console',

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#region Import Module
$ModulePath = Join-Path $PSScriptRoot "src" "core" "SmartLogging.psm1"
if (-not (Test-Path $ModulePath)) {
    Write-Error "Smart Logging module not found at: $ModulePath"
    exit 1
}

Import-Module $ModulePath -Force
#endregion Import Module

#region Helper Functions
function Write-ActionHeader {
    param([string]$ActionName)
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " Smart Logging Framework - $ActionName" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
}

function Format-Output {
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject,
        [string]$Format
    )
    
    switch ($Format) {
        'JSON' {
            $InputObject | ConvertTo-Json -Depth 5
        }
        'Table' {
            $InputObject | Format-Table -AutoSize
        }
        default {
            $InputObject | Format-List
        }
    }
}

function Test-LoggingConfiguration {
    Write-Host "🔍 Testing Logging Configuration..." -ForegroundColor Green
    
    # Test environment detection
    $Config = Get-Variable -Name LoggingConfig -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($Config) {
        Write-Host "✅ Environment Detection:" -ForegroundColor Green
        Write-Host "   - Production: $($Config.IsProduction)" -ForegroundColor Cyan
        Write-Host "   - Development: $($Config.IsDevelopment)" -ForegroundColor Cyan
        Write-Host "   - CI/CD: $($Config.IsCI)" -ForegroundColor Cyan
        Write-Host "   - Log Level: $($Config.LogLevel)" -ForegroundColor Cyan
        Write-Host "   - Interactive Output: $($Config.UseInteractiveOutput)" -ForegroundColor Cyan
    }
    
    # Test log path generation
    $TestPath = Get-SmartLogPath -ScriptName "TestScript" -LogType "Test"
    Write-Host "✅ Log Path Generation: $TestPath" -ForegroundColor Green
    
    # Test directory creation
    $TestDir = Split-Path $TestPath -Parent
    if (Test-Path $TestDir) {
        Write-Host "✅ Log Directory Accessible: $TestDir" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Log Directory Not Found: $TestDir" -ForegroundColor Yellow
    }
}

function Show-Demo {
    Write-ActionHeader "Interactive Demo"
    
    Write-Host "🚀 Starting Smart Logging Framework Demo..." -ForegroundColor Green
    Write-Host ""
    
    # Initialize logging
    Write-Host "1. Initializing logging for demo script..." -ForegroundColor Yellow
    $Context = Initialize-SmartLogging -ScriptName "DemoScript.ps1" -LogType "Demo"
    
    # Test different log levels
    Write-Host "2. Testing different log levels..." -ForegroundColor Yellow
    Write-SmartLog "This is a debug message with technical details" -Level "DEBUG" -Component "Demo"
    Write-SmartLog "Process started successfully" -Level "INFO" -Component "Demo"
    Write-SmartLog "Warning: Configuration value missing, using default" -Level "WARN" -Component "Demo"
    Write-SmartLog "Error: Failed to connect to external service" -Level "ERROR" -Component "Demo"
    Write-SmartLog "Operation completed successfully!" -Level "SUCCESS" -Component "Demo"
    
    # Test structured data
    Write-Host "3. Testing structured data logging..." -ForegroundColor Yellow
    Write-SmartLog "User login event" -Level "INFO" -Component "Auth" -Data @{
        UserId = "john.doe@company.com"
        LoginTime = Get-Date
        IPAddress = "192.168.1.100"
        UserAgent = "PowerShell/7.0"
    }
    
    # Test performance tracking
    Write-Host "4. Testing performance tracking..." -ForegroundColor Yellow
    Start-PerformanceTimer -OperationName "FileProcessing"
    Start-Sleep -Milliseconds 500  # Simulate work
    $Duration = Stop-PerformanceTimer -OperationName "FileProcessing" -LogResult
    
    # Test progress tracking
    Write-Host "5. Testing progress tracking..." -ForegroundColor Yellow
    Write-Progress-Start -Activity "Processing Files" -Status "Starting..."
    for ($i = 1; $i -le 3; $i++) {
        Write-Progress-Update -Activity "Processing Files" -Status "Processing file $i of 3" -PercentComplete ($i * 33)
        Start-Sleep -Milliseconds 200
    }
    Write-Progress-Complete -Activity "Processing Files"
    
    # Test section management
    Write-Host "6. Testing section management..." -ForegroundColor Yellow
    Write-Section-Start -Title "Data Processing Section" -Icon "🔄"
    Write-SmartLog "Processing data..." -Level "INFO" -Component "DataProcessor"
    Write-Section-End -Title "Data Processing Section" -Status "COMPLETED" -Duration (New-TimeSpan -Seconds 2)
    
    # Test error context
    Write-Host "7. Testing error context..." -ForegroundColor Yellow
    try {
        throw "Simulated error for demonstration"
    } catch {
        Write-Error-Context -ErrorRecord $_ -Context "Demo Error Handling" -AdditionalInfo @{
            DemoMode = $true
            Timestamp = Get-Date
        }
    }
    
    # Show summary
    Write-Host "8. Generating execution summary..." -ForegroundColor Yellow
    $Summary = Get-SmartLogSummary
    
    Write-Host ""
    Write-Host "📋 Demo Summary:" -ForegroundColor Green
    Write-Host "   - Script: $($Summary.ScriptName)" -ForegroundColor Cyan
    Write-Host "   - Duration: $($Summary.Duration.TotalSeconds) seconds" -ForegroundColor Cyan
    Write-Host "   - Log File: $($Summary.LogFile)" -ForegroundColor Cyan
    Write-Host "   - Environment: $(if($Summary.Environment.IsProduction){'Production'}elseif($Summary.Environment.IsDevelopment){'Development'}else{'Unknown'})" -ForegroundColor Cyan
    
    if (Test-Path $Summary.LogFile) {
        $LogSize = [Math]::Round((Get-Item $Summary.LogFile).Length / 1KB, 2)
        Write-Host "   - Log Size: $LogSize KB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📄 Recent Log Entries:" -ForegroundColor Green
        Get-Content $Summary.LogFile -Tail 5 | ForEach-Object {
            Write-Host "   $_" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "✅ Demo completed! Check the log file for detailed output." -ForegroundColor Green
}
#endregion Helper Functions

#region Main Action Logic
try {
    switch ($Action) {
        'Initialize' {
            Write-ActionHeader "Initialize Logging"
            
            if (-not $ScriptName) {
                $ScriptName = Read-Host "Enter script name"
            }
            
            $Context = if ($LogPath) {
                Initialize-SmartLogging -ScriptName $ScriptName -LogType $LogType -LogPath $LogPath
            } else {
                Initialize-SmartLogging -ScriptName $ScriptName -LogType $LogType
            }
            
            Write-Host "✅ Smart Logging initialized successfully!" -ForegroundColor Green
            $Context | Format-Output -Format $OutputFormat
        }
        
        'Test' {
            Write-ActionHeader "Test Logging"
            
            if (-not (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue)) {
                Write-Host "Initializing logging for test..." -ForegroundColor Yellow
                Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType "Test"
            }
            
            Test-LoggingConfiguration
            
            $TestMessage = if ($Message) { $Message } else { "Test message from Smart Logging CLI" }
            Write-SmartLog -Message $TestMessage -Level $Level -Component "CLI-Test"
            
            Write-Host "✅ Test log entry written successfully!" -ForegroundColor Green
        }
        
        'Clean' {
            Write-ActionHeader "Clean Old Logs"
            
            $TargetDirectory = if ($LogDirectory) { $LogDirectory } else { 
                if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'C:\temp\logs' } else { '/tmp/logs' }
            }
            
            if (-not (Test-Path $TargetDirectory)) {
                Write-Warning "Log directory not found: $TargetDirectory"
                exit 1
            }
            
            Write-Host "🧹 Cleaning logs older than $MaxAgeDays days from: $TargetDirectory" -ForegroundColor Yellow
            
            if (-not $Force) {
                $Confirm = Read-Host "Continue? (y/N)"
                if ($Confirm -ne 'y' -and $Confirm -ne 'Y') {
                    Write-Host "Operation cancelled." -ForegroundColor Yellow
                    exit 0
                }
            }
            
            Clear-OldLogs -LogDirectory $TargetDirectory
            Write-Host "✅ Log cleanup completed!" -ForegroundColor Green
        }
        
        'Compress' {
            Write-ActionHeader "Compress Logs"
            
            if (-not $LogPath) {
                Write-Error "LogPath parameter is required for Compress action"
                exit 1
            }
            
            if (-not (Test-Path $LogPath)) {
                Write-Error "Log file not found: $LogPath"
                exit 1
            }
            
            Write-Host "🗜️ Compressing log file: $LogPath" -ForegroundColor Yellow
            Compress-LogFile -LogPath $LogPath -RemoveOriginal (-not $Force)
            Write-Host "✅ Log compression completed!" -ForegroundColor Green
        }
        
        'Summary' {
            Write-ActionHeader "Logging Summary"
            
            $Summary = Get-SmartLogSummary
            if ($Summary) {
                $Summary | Format-Output -Format $OutputFormat
            } else {
                Write-Host "No active logging session found. Use 'Initialize' action first." -ForegroundColor Yellow
            }
        }
        
        'Reset' {
            Write-ActionHeader "Reset Logging"
            
            Reset-SmartLogging
            Write-Host "✅ Smart Logging context reset successfully!" -ForegroundColor Green
        }
        
        'Demo' {
            Show-Demo
        }
    }
    
} catch {
    Write-Error "Failed to execute action '$Action': $($_.Exception.Message)"
    Write-Error-Context -ErrorRecord $_ -Context "CLI Action Execution"
    exit 1
}
#endregion Main Action Logic

Write-Host ""
