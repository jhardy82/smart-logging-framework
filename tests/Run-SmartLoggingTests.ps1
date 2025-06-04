#Requires -Version 5.1

<#
.SYNOPSIS
    SmartLogging Test Runner - Comprehensive test execution and reporting
.DESCRIPTION
    Automated test runner for the SmartLogging module test suite. Executes all test categories,
    generates comprehensive reports, and provides CI/CD integration support.

    Part of ContextForge Phase 1.2 - Testing & Validation Enhancement
.PARAMETER TestType
    Type of tests to run: All, Unit, Integration, Performance, Security, Configuration
.PARAMETER OutputFormat
    Output format: Console, NUnitXml, JUnitXml, HTML, All
.PARAMETER ReportPath
    Path where test reports should be saved
.PARAMETER CI
    Run in CI mode with appropriate output formatting and exit codes
.PARAMETER Coverage
    Generate code coverage reports (requires PSCodeCoverage module)
.PARAMETER Parallel
    Run tests in parallel where possible (requires Pester 5.3+)
.EXAMPLE
    .\Run-SmartLoggingTests.ps1 -TestType All -OutputFormat All -ReportPath ".\TestResults"
.EXAMPLE
    .\Run-SmartLoggingTests.ps1 -CI -Coverage
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Unit", "Integration", "Performance", "Security", "Configuration")]
    [string]$TestType = "All",

    [ValidateSet("Console", "NUnitXml", "JUnitXml", "HTML", "All")]
    [string]$OutputFormat = "Console",

    [string]$ReportPath = ".\TestResults",

    [switch]$CI,

    [switch]$Coverage,

    [switch]$Parallel
)

#region Configuration and Setup

$ErrorActionPreference = 'Stop'

# Test configuration
$TestConfig = @{
    ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\src\src\core\SmartLogging.psm1"
    TestsPath = $PSScriptRoot
    ReportPath = $ReportPath
    Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    StartTime = Get-Date
}

# Ensure required modules are available
$RequiredModules = @('Pester')
if ($Coverage) {
    $RequiredModules += 'PSCodeCoverage'
}

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        throw "Required module '$Module' is not installed. Install with: Install-Module $Module"
    }
}

# Create report directory
if (-not (Test-Path $TestConfig.ReportPath)) {
    New-Item -Path $TestConfig.ReportPath -ItemType Directory -Force | Out-Null
}

#endregion

#region Helper Functions

function Write-TestHeader {
    param([string]$Title)

    $Border = "=" * 60
    Write-Host "`n$Border" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "$Border`n" -ForegroundColor Cyan
}

function Write-TestInfo {
    param([string]$Message)
    Write-Host "INFO: $Message" -ForegroundColor Green
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Write-TestError {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Get-TestFiles {
    param([string]$TestType)

    $TestFiles = @()
    $TestsPath = $TestConfig.TestsPath

    switch ($TestType) {
        "All" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
        "Unit" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*Write-SmartLog*.Tests.ps1" | Select-Object -ExpandProperty FullName
            $TestFiles += Get-ChildItem -Path $TestsPath -Filter "*Initialize-SmartLogging*.Tests.ps1" | Select-Object -ExpandProperty FullName
            $TestFiles += Get-ChildItem -Path $TestsPath -Filter "*Get-SmartLogSummary*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
        "Integration" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*Integration*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
        "Performance" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*Performance*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
        "Security" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*Security*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
        "Configuration" {
            $TestFiles = Get-ChildItem -Path $TestsPath -Filter "*Configuration*.Tests.ps1" | Select-Object -ExpandProperty FullName
        }
    }

    return $TestFiles | Where-Object { Test-Path $_ }
}

function New-SmartLoggingPesterConfiguration {
    param(
        [string[]]$TestFiles,
        [string]$OutputFormat,
        [string]$ReportPath,
        [string]$Timestamp,
        [bool]$Coverage,
        [bool]$Parallel,
        [bool]$CI
    )

    $Config = New-PesterConfiguration

    # Run configuration
    $Config.Run.Path = $TestFiles
    $Config.Run.PassThru = $true

    if ($Parallel -and $TestFiles.Count -gt 1) {
        $Config.Run.Parallel = $true
        $Config.Run.PassThru = $true
    }

    # Output configuration
    $Config.Output.Verbosity = if ($CI) { 'Normal' } else { 'Detailed' }

    # Test result configuration
    if ($OutputFormat -in @('NUnitXml', 'All')) {
        $Config.TestResult.Enabled = $true
        $Config.TestResult.OutputFormat = 'NUnitXml'
        $Config.TestResult.OutputPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-TestResults-$Timestamp.xml"
    }

    if ($OutputFormat -in @('JUnitXml', 'All')) {
        $Config.TestResult.Enabled = $true
        $Config.TestResult.OutputFormat = 'JUnitXml'
        $Config.TestResult.OutputPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-TestResults-JUnit-$Timestamp.xml"
    }

    # Code coverage configuration
    if ($Coverage) {
        $Config.CodeCoverage.Enabled = $true
        $Config.CodeCoverage.Path = $TestConfig.ModulePath
        $Config.CodeCoverage.OutputFormat = 'JaCoCo'
        $Config.CodeCoverage.OutputPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-Coverage-$Timestamp.xml"
    }

    return $Config
}

function Format-TestSummary {
    param([object]$TestResult)

    $Summary = [PSCustomObject]@{
        TestType = $TestType
        TotalTests = $TestResult.TotalCount
        PassedTests = $TestResult.PassedCount
        FailedTests = $TestResult.FailedCount
        SkippedTests = $TestResult.SkippedCount
        PendingTests = $TestResult.PendingCount
        Duration = $TestResult.Duration
        Success = $TestResult.Result -eq 'Passed'
        ExecutionTime = (Get-Date) - $TestConfig.StartTime
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    return $Summary
}

function Write-TestSummary {
    param([object]$Summary)

    Write-TestHeader "Test Execution Summary"
    Write-Host "Test Type: " -NoNewline; Write-Host $Summary.TestType -ForegroundColor Cyan
    Write-Host "Total Tests: " -NoNewline; Write-Host $Summary.TotalTests -ForegroundColor White
    Write-Host "Passed: " -NoNewline; Write-Host $Summary.PassedTests -ForegroundColor Green
    Write-Host "Failed: " -NoNewline; Write-Host $Summary.FailedTests -ForegroundColor $(if ($Summary.FailedTests -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Skipped: " -NoNewline; Write-Host $Summary.SkippedTests -ForegroundColor Yellow
    Write-Host "Pending: " -NoNewline; Write-Host $Summary.PendingTests -ForegroundColor Yellow
    Write-Host "Duration: " -NoNewline; Write-Host "$($Summary.Duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
    Write-Host "Overall Result: " -NoNewline
    if ($Summary.Success) {
        Write-Host 'PASSED' -ForegroundColor Green
    } else {
        Write-Host 'FAILED' -ForegroundColor Red
    }
    Write-Host "Execution Time: " -NoNewline; Write-Host "$($Summary.ExecutionTime.TotalSeconds.ToString('F2')) seconds" -ForegroundColor White
    Write-Host ""
}

function Export-TestSummary {
    param(
        [object]$Summary,
        [string]$ReportPath,
        [string]$Timestamp
    )

    # Export to JSON
    $JsonPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-Summary-$Timestamp.json"
    $Summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $JsonPath -Encoding UTF8
    Write-TestInfo "Summary exported to: $JsonPath"

    # Export to CSV
    $CsvPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-Summary-$Timestamp.csv"
    $Summary | Export-Csv -Path $CsvPath -NoTypeInformation
    Write-TestInfo "Summary exported to: $CsvPath"

    # Create HTML report if requested
    if ($OutputFormat -in @('HTML', 'All')) {
        $HtmlPath = Join-Path -Path $ReportPath -ChildPath "SmartLogging-Report-$Timestamp.html"
        New-HTMLReport -Summary $Summary -OutputPath $HtmlPath
        Write-TestInfo "HTML report generated: $HtmlPath"
    }
}

function New-HTMLReport {
    param(
        [object]$Summary,
        [string]$OutputPath
    )

    $HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>SmartLogging Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
        .success { color: green; font-weight: bold; }
        .failure { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .metric { margin: 5px 0; }
        .timestamp { color: gray; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SmartLogging Module Test Report</h1>
        <p class="timestamp">Generated: $($Summary.Timestamp)</p>
    </div>

    <h2>Test Summary</h2>
    <div class="metric">Test Type: <strong>$($Summary.TestType)</strong></div>
    <div class="metric">Total Tests: <strong>$($Summary.TotalTests)</strong></div>
    <div class="metric">Passed: <span class="success">$($Summary.PassedTests)</span></div>
    <div class="metric">Failed: <span class="$(if ($Summary.FailedTests -gt 0) { 'failure' } else { 'success' })">$($Summary.FailedTests)</span></div>
    <div class="metric">Skipped: <span class="warning">$($Summary.SkippedTests)</span></div>
    <div class="metric">Pending: <span class="warning">$($Summary.PendingTests)</span></div>
    <div class="metric">Duration: <strong>$($Summary.Duration.TotalSeconds.ToString('F2')) seconds</strong></div>
    <div class="metric">Overall Result: <span class="$(if ($Summary.Success) { 'success' } else { 'failure' })">$(if ($Summary.Success) { 'PASSED' } else { 'FAILED' })</span></div>

    <h2>Performance Metrics</h2>
    <div class="metric">Total Execution Time: <strong>$($Summary.ExecutionTime.TotalSeconds.ToString('F2')) seconds</strong></div>

    <h2>Test Coverage</h2>
    <p><em>Code coverage data available in separate coverage report.</em></p>

    <footer style="margin-top: 50px; padding-top: 20px; border-top: 1px solid #ccc;">
        <p class="timestamp">Report generated by SmartLogging Test Runner - ContextForge Phase 1.2</p>
    </footer>
</body>
</html>
"@

    $HtmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
}

#endregion

#region Main Execution

try {
    Write-TestHeader "SmartLogging Module Test Runner"
    Write-TestInfo "ContextForge Phase 1.2 - Testing & Validation Enhancement"
    Write-TestInfo "Starting test execution at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Verify module exists
    if (-not (Test-Path $TestConfig.ModulePath)) {
        throw "SmartLogging module not found at: $($TestConfig.ModulePath)"
    }
    Write-TestInfo "Module found: $($TestConfig.ModulePath)"

    # Get test files
    $TestFiles = Get-TestFiles -TestType $TestType
    if ($TestFiles.Count -eq 0) {
        throw "No test files found for test type: $TestType"
    }
    Write-TestInfo "Found $($TestFiles.Count) test file(s) for type: $TestType"

    # Import Pester
    Import-Module Pester -Force -MinimumVersion 5.0.0
    Write-TestInfo "Pester module imported (Version: $((Get-Module Pester).Version))"    # Configure Pester
    $PesterConfig = New-SmartLoggingPesterConfiguration -TestFiles $TestFiles -OutputFormat $OutputFormat -ReportPath $TestConfig.ReportPath -Timestamp $TestConfig.Timestamp -Coverage $Coverage -Parallel $Parallel -CI $CI

    # Run tests
    Write-TestHeader "Executing Tests"
    $TestResult = Invoke-Pester -Configuration $PesterConfig

    # Generate summary
    $Summary = Format-TestSummary -TestResult $TestResult

    # Display summary
    Write-TestSummary -Summary $Summary

    # Export reports
    Export-TestSummary -Summary $Summary -ReportPath $TestConfig.ReportPath -Timestamp $TestConfig.Timestamp

    # CI mode exit codes
    if ($CI) {
        $ExitCode = if ($Summary.Success) { 0 } else { 1 }
        Write-TestInfo "CI Mode: Exiting with code $ExitCode"
        exit $ExitCode
    }

    Write-TestInfo "Test execution completed successfully!"

} catch {
    Write-TestError "Test execution failed: $($_.Exception.Message)"
    Write-TestError "Stack Trace: $($_.ScriptStackTrace)"

    if ($CI) {
        exit 1
    }
    throw
}

#endregion
