#Requires -Version 5.1

<#
.SYNOPSIS
    Fix BeforeEach blocks in all test files to ensure proper test directory creation
.DESCRIPTION
    This script fixes test setup patterns in all SmartLogging test files to ensure directories
    are properly created before tests run and logs can be written successfully.
#>

$TestFiles = Get-ChildItem -Path "$PSScriptRoot\tests" -Filter "*.Tests.ps1"
Write-Host "Found $($TestFiles.Count) test files to update" -ForegroundColor Cyan

foreach ($file in $TestFiles) {
    Write-Host "Processing $($file.Name)..." -ForegroundColor Yellow

    $content = Get-Content -Path $file.FullName -Raw
    $modified = $false

    # Pattern 1: Fix missing directory creation
    if ($content -match 'BeforeEach\s*\{\s*Reset-SmartLoggingState') {
        $oldPattern = 'BeforeEach\s*\{\s*Reset-SmartLoggingState'
        $newContent = @'
BeforeEach {
            # Reset module state
            Reset-SmartLoggingState

            # Ensure test directory exists and is clean
            if (Test-Path $TestDataPath) {
                Get-ChildItem -Path $TestDataPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            } else {
                New-Item -Path $TestDataPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
'@
        $content = $content -replace $oldPattern, $newContent
        $modified = $true
    }

    # Pattern 2: Fix missing directory verification after initialization
    if ($content -match 'Initialize-SmartLogging.*\n\s*# Assert') {
        $oldPattern = '(Initialize-SmartLogging.*)\n(\s*# Assert)'
        $newContent = '$1

            # Verify initialization succeeded
            if (-not (Test-Path $Script:Context.LogFile -IsValid)) {
                throw "SmartLogging initialization failed to create a valid log path: $($Script:Context.LogFile)"
            }

$2'
        $content = $content -replace $oldPattern, $newContent
        $modified = $true
    }

    # Write changes if modified
    if ($modified) {
        Write-Host "  - Updated file with fixes" -ForegroundColor Green
        Set-Content -Path $file.FullName -Value $content
    } else {
        Write-Host "  - No changes needed" -ForegroundColor Gray
    }
}

Write-Host "`nTest file updates complete!" -ForegroundColor Cyan
