#Requires -Version 5.1

<#
.SYNOPSIS
    Tests the log file creation after fixing SmartLogging module
.DESCRIPTION
    This script verifies that the fixed SmartLogging module correctly creates log files
#>

$ErrorActionPreference = 'Stop'
Write-Host "=== SmartLogging Fix Verification Test ===" -ForegroundColor Cyan

# 1. Import the module
$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "src\src\core\SmartLogging.psm1"
Write-Host "Importing module: $ModulePath" -ForegroundColor Yellow
Import-Module $ModulePath -Force

# 2. Test different log path scenarios
Write-Host "`nTesting different log path scenarios:" -ForegroundColor Yellow

# Scenario 1: Directory path
$tempDir = Join-Path $env:TEMP "SmartLogging-Test-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "`n[1] Testing with directory path: $tempDir" -ForegroundColor Magenta
if (-not (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

try {
    $result1 = Initialize-SmartLogging -ScriptName "DirectoryTest" -LogPath $tempDir
    $logFile1 = $result1.LogFile
    Write-Host "  ✓ Initialized with directory path" -ForegroundColor Green
    Write-Host "  Log file: $logFile1" -ForegroundColor Cyan

    # Write test message
    Write-SmartLog -Message "Test with directory path" -Level INFO

    # Verify file exists and has content
    if (Test-Path $logFile1) {
        $content = Get-Content $logFile1 -Raw
        Write-Host "  ✓ Log file created successfully" -ForegroundColor Green
        Write-Host "  Content preview: $($content.Substring(0, [Math]::Min(60, $content.Length)))..." -ForegroundColor Gray
    } else {
        Write-Host "  ✕ Log file was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✕ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Scenario 2: File path
$tempFile = Join-Path $env:TEMP "SmartLogging-Test-$(Get-Date -Format 'yyyyMMddHHmmss').log"
Write-Host "`n[2] Testing with file path: $tempFile" -ForegroundColor Magenta

try {
    $result2 = Initialize-SmartLogging -ScriptName "FileTest" -LogPath $tempFile
    $logFile2 = $result2.LogFile
    Write-Host "  ✓ Initialized with file path" -ForegroundColor Green
    Write-Host "  Log file: $logFile2" -ForegroundColor Cyan

    # Write test message
    Write-SmartLog -Message "Test with file path" -Level INFO

    # Verify file exists and has content
    if (Test-Path $logFile2) {
        $content = Get-Content $logFile2 -Raw
        Write-Host "  ✓ Log file created successfully" -ForegroundColor Green
        Write-Host "  Content preview: $($content.Substring(0, [Math]::Min(60, $content.Length)))..." -ForegroundColor Gray
    } else {
        Write-Host "  ✕ Log file was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✕ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Scenario 3: Default path
Write-Host "`n[3] Testing with default path generation" -ForegroundColor Magenta

try {
    $result3 = Initialize-SmartLogging -ScriptName "DefaultPathTest"
    $logFile3 = $result3.LogFile
    Write-Host "  ✓ Initialized with default path" -ForegroundColor Green
    Write-Host "  Log file: $logFile3" -ForegroundColor Cyan

    # Write test message
    Write-SmartLog -Message "Test with default path" -Level INFO

    # Verify file exists and has content
    if (Test-Path $logFile3) {
        $content = Get-Content $logFile3 -Raw
        Write-Host "  ✓ Log file created successfully" -ForegroundColor Green
        Write-Host "  Content preview: $($content.Substring(0, [Math]::Min(60, $content.Length)))..." -ForegroundColor Gray
    } else {
        Write-Host "  ✕ Log file was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✕ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Scenario 4: Test with all parameters
Write-Host "`n[4] Testing with all parameters" -ForegroundColor Magenta

try {
    $contextForgeConfig = @{
        AppName     = "TestApp"
        Version     = "1.0.0"
        Environment = "Test"
    }

    $result4 = Initialize-SmartLogging -ScriptName "FullParamsTest" -LogType "Main" -LogPath $tempDir -Environment "Development" -ContextForgeConfig $contextForgeConfig -IsDebug $true -Force
    $logFile4 = $result4.LogFile
    Write-Host "  ✓ Initialized with all parameters" -ForegroundColor Green
    Write-Host "  Log file: $logFile4" -ForegroundColor Cyan

    # Write test message
    Write-SmartLog -Message "Test with all parameters" -Level INFO

    # Verify file exists and has content
    if (Test-Path $logFile4) {
        $content = Get-Content $logFile4 -Raw
        Write-Host "  ✓ Log file created successfully" -ForegroundColor Green
        Write-Host "  Content preview: $($content.Substring(0, [Math]::Min(60, $content.Length)))..." -ForegroundColor Gray
    } else {
        Write-Host "  ✕ Log file was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✕ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
