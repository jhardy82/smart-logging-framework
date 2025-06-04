#Requires -Version 5.1

<#
.SYNOPSIS
    Diagnostic script to troubleshoot log file creation issues in SmartLogging
.DESCRIPTION
    This script diagnoses potential root causes for log file creation failures:
    - Tests direct file creation in the target directory
    - Checks module initialization
    - Verifies context and log file paths are properly set
    - Tests direct file writing with various methods
.NOTES
    Created: 2025-06-03
#>

Write-Host "=== SmartLogging Log Creation Diagnostic ===" -ForegroundColor Cyan

# 1. Test basic file system operations
Write-Host "`n[1] Testing basic file system operations:" -ForegroundColor Yellow
$testPath = "C:\temp\SmartLogging-Diagnostic"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$testFilePath = Join-Path -Path $testPath -ChildPath "test-$timestamp.log"

Write-Host "  Creating test directory: $testPath"
try {
    if (Test-Path $testPath) {
        Remove-Item -Path $testPath -Recurse -Force -ErrorAction Stop
    }
    $null = New-Item -Path $testPath -ItemType Directory -Force -ErrorAction Stop
    Write-Host "  ✓ Directory creation successful" -ForegroundColor Green
} catch {
    Write-Host "  ✕ Error creating directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    This indicates potential permission issues" -ForegroundColor Yellow
}

# 2. Test basic file creation
Write-Host "`n[2] Testing direct file creation:" -ForegroundColor Yellow
try {
    $null = New-Item -Path $testFilePath -ItemType File -Force -ErrorAction Stop
    Write-Host "  ✓ File creation successful: $testFilePath" -ForegroundColor Green

    # Test append
    "Test content $(Get-Date)" | Out-File -FilePath $testFilePath -Append
    Write-Host "  ✓ File write operation successful" -ForegroundColor Green

    # Check content
    $content = Get-Content -Path $testFilePath -Raw
    Write-Host "  ✓ File content verified: $content" -ForegroundColor Green
} catch {
    Write-Host "  ✕ Error creating/writing file: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Import the module and test initialization
Write-Host "`n[3] Testing module initialization:" -ForegroundColor Yellow
$ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "src\src\core\SmartLogging.psm1"
try {
    # Remove module if already loaded
    if (Get-Module SmartLogging) {
        Remove-Module SmartLogging -Force
        Write-Host "  ✓ Existing module removed" -ForegroundColor Green
    }

    # Import module
    Import-Module $ModulePath -Force
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✕ Error importing module: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# 4. Test SmartLogging initialization
Write-Host "`n[4] Testing SmartLogging initialization:" -ForegroundColor Yellow
$logPath = $testPath
$scriptName = "LogDiagnostic.ps1"

try {
    $initResult = Initialize-SmartLogging -ScriptName $scriptName -LogPath $logPath -Verbose
    Write-Host "  ✓ Initialize-SmartLogging completed" -ForegroundColor Green

    # Check script context
    $script:Context = Get-Variable -Name "Context" -Scope Script -ErrorAction SilentlyContinue
    Write-Host "  Context object available: $(if($script:Context){'Yes'}else{'No'})" -ForegroundColor $(if ($script:Context) { 'Green' }else { 'Red' })

    if ($script:Context) {
        Write-Host "  Context LogFile: $($script:Context.LogFile)" -ForegroundColor Yellow
        Write-Host "  Context LogPath: $($script:Context.LogPath)" -ForegroundColor Yellow
    }

    # Check logging config
    $config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
    Write-Host "  LoggingConfig available: $(if($config){'Yes'}else{'No'})" -ForegroundColor $(if ($config) { 'Green' }else { 'Red' })

    if ($config) {
        Write-Host "  Config structure:" -ForegroundColor Yellow
        $config.Value | Format-List | Out-String | Write-Host
    }
} catch {
    Write-Host "  ✕ Error initializing SmartLogging: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test log writing
Write-Host "`n[5] Testing log writing:" -ForegroundColor Yellow
try {
    $writeResult = Write-SmartLog -Message "Diagnostic test message" -Level Info
    Write-Host "  ✓ Write-SmartLog completed" -ForegroundColor Green

    # Check if log file exists after writing
    if ($script:Context -and $script:Context.LogFile) {
        $logExists = Test-Path $script:Context.LogFile
        Write-Host "  Log file exists: $(if($logExists){'Yes'}else{'No'})" -ForegroundColor $(if ($logExists) { 'Green' }else { 'Red' })

        if ($logExists) {
            $logContent = Get-Content -Path $script:Context.LogFile -Raw
            Write-Host "  Log content preview:" -ForegroundColor Yellow
            Write-Host $logContent -ForegroundColor White
        } else {
            Write-Host "  ✕ Log file does not exist at expected path: $($script:Context.LogFile)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  ✕ Error writing log: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Test direct output methods
Write-Host "`n[6] Testing direct output methods:" -ForegroundColor Yellow
$directLogPath = Join-Path -Path $testPath -ChildPath "direct-test.log"

# Test Out-File
try {
    "Test with Out-File $(Get-Date)" | Out-File -FilePath $directLogPath -Append
    Write-Host "  ✓ Out-File successful" -ForegroundColor Green
} catch {
    Write-Host "  ✕ Out-File failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Add-Content
try {
    Add-Content -Path $directLogPath -Value "Test with Add-Content $(Get-Date)" -ErrorAction Stop
    Write-Host "  ✓ Add-Content successful" -ForegroundColor Green
} catch {
    Write-Host "  ✕ Add-Content failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test [System.IO.File]::AppendAllText
try {
    [System.IO.File]::AppendAllText($directLogPath, "Test with [System.IO.File]::AppendAllText $(Get-Date)`r`n")
    Write-Host "  ✓ [System.IO.File]::AppendAllText successful" -ForegroundColor Green
} catch {
    Write-Host "  ✕ [System.IO.File]::AppendAllText failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
Write-Host "Check for any red '✕' errors above that may indicate the source of log file creation issues."
