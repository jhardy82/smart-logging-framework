#Requires -Version 5.1

<#
.SYNOPSIS
    Debug script to test SmartLogging log file writing mechanism
.DESCRIPTION
    Investigates why log files aren't being written by the SmartLogging module
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

Write-Host "=== SmartLogging Log File Writing Debug ===" -ForegroundColor Cyan

# Import the module
$ModulePath = Join-Path $PSScriptRoot "src\src\core\SmartLogging.psm1"
Write-Host "1. Importing module: $ModulePath" -ForegroundColor Yellow

if (-not (Test-Path $ModulePath)) {
    Write-Host "   ✗ Module not found at: $ModulePath" -ForegroundColor Red
    exit 1
}

Import-Module $ModulePath -Force
Write-Host "   ✓ Module imported successfully" -ForegroundColor Green

# Test 1: Initialize logging
Write-Host "`n2. Testing Initialize-SmartLogging..." -ForegroundColor Yellow
try {
    $result = Initialize-SmartLogging -ScriptName "DebugTest"
    Write-Host "   ✓ Initialize-SmartLogging completed" -ForegroundColor Green
    Write-Host "   Log file path: $($result.LogFile)" -ForegroundColor Cyan
    Write-Host "   Directory exists: $(Test-Path (Split-Path $result.LogFile -Parent))" -ForegroundColor Cyan
} catch {
    Write-Host "   ✗ Initialize-SmartLogging failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check module context
Write-Host "`n3. Checking module context..." -ForegroundColor Yellow
$contextTest = Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue
if ($contextTest) {
    Write-Host "   ✓ Script Context exists" -ForegroundColor Green
    Write-Host "   Context LogFile: $($contextTest.Value.LogFile)" -ForegroundColor Cyan
} else {
    Write-Host "   ✗ Script Context not found" -ForegroundColor Red
}

# Test 3: Manual file creation to verify permissions
Write-Host "`n4. Testing manual file creation..." -ForegroundColor Yellow
$testFile = Join-Path (Split-Path $result.LogFile -Parent) "manual-test.log"
try {
    "Test content $(Get-Date)" | Out-File -FilePath $testFile -Encoding UTF8
    if (Test-Path $testFile) {
        Write-Host "   ✓ Manual file creation successful" -ForegroundColor Green
        Write-Host "   Manual test file: $testFile" -ForegroundColor Cyan
        Remove-Item $testFile -Force
    } else {
        Write-Host "   ✗ Manual file was not created" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Manual file creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Test Add-Content directly
Write-Host "`n5. Testing Add-Content directly..." -ForegroundColor Yellow
try {
    $directTestContent = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff") [INFO] Direct Add-Content test"
    Add-Content -Path $result.LogFile -Value $directTestContent -ErrorAction Stop

    if (Test-Path $result.LogFile) {
        $content = Get-Content $result.LogFile -Raw
        if ($content -and $content.Contains("Direct Add-Content test")) {
            Write-Host "   ✓ Direct Add-Content successful" -ForegroundColor Green
            Write-Host "   Content preview: $($content.Trim())" -ForegroundColor Gray
        } else {
            Write-Host "   ✗ Direct Add-Content: file exists but content missing" -ForegroundColor Red
            Write-Host "   Content: '$content'" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✗ Direct Add-Content: file not created" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Direct Add-Content failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Test Write-SmartLog with debug output
Write-Host "`n6. Testing Write-SmartLog with debug tracing..." -ForegroundColor Yellow

# Enable verbose preference temporarily if requested
$originalVerbose = $VerbosePreference
if ($Verbose) {
    $VerbosePreference = 'Continue'
}

try {
    Write-SmartLog -Message "Debug trace test message" -Level "INFO"
    Write-Host "   ✓ Write-SmartLog completed without errors" -ForegroundColor Green

    # Check if log file exists and has content
    if (Test-Path $result.LogFile) {
        $content = Get-Content $result.LogFile -Raw
        if ($content -and $content.Contains("Debug trace test message")) {
            Write-Host "   ✓ Write-SmartLog: file created and content found" -ForegroundColor Green
            Write-Host "   Log content preview:" -ForegroundColor Cyan
            $content -split "`n" | Select-Object -First 5 | ForEach-Object {
                Write-Host "     $_" -ForegroundColor Gray
            }
        } else {
            Write-Host "   ✗ Write-SmartLog: file exists but no content found" -ForegroundColor Red
            Write-Host "   Raw content: '$content'" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ✗ Write-SmartLog: log file not created" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Write-SmartLog failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    $VerbosePreference = $originalVerbose
}

# Test 6: Check logging configuration
Write-Host "`n7. Checking logging configuration..." -ForegroundColor Yellow
$configTest = Get-Variable -Name LoggingConfig -Scope Script -ErrorAction SilentlyContinue
if ($configTest) {
    Write-Host "   ✓ LoggingConfig exists" -ForegroundColor Green
    Write-Host "   UseInteractiveOutput: $($configTest.Value.UseInteractiveOutput)" -ForegroundColor Cyan
    Write-Host "   SuppressVerbose: $($configTest.Value.SuppressVerbose)" -ForegroundColor Cyan
    Write-Host "   EnableLogRotation: $($configTest.Value.EnableLogRotation)" -ForegroundColor Cyan
} else {
    Write-Host "   ✗ LoggingConfig not found" -ForegroundColor Red
}

Write-Host "`n=== Debug Complete ===" -ForegroundColor Cyan
