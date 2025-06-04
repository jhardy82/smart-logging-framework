#Requires -Version 5.1

# Simple debug test to identify log file creation issue
Write-Host "=== SmartLogging Debug Test ===" -ForegroundColor Green

# Import the module
$ModulePath = ".\src\src\core\SmartLogging.psm1"
Write-Host "Importing module: $ModulePath"
Import-Module $ModulePath -Force

# Step 1: Test Initialize-SmartLogging
Write-Host "`n1. Testing Initialize-SmartLogging..." -ForegroundColor Yellow
try {
    $result = Initialize-SmartLogging -ScriptName "DebugTest"
    Write-Host "   ✓ Initialize-SmartLogging completed successfully" -ForegroundColor Green
    Write-Host "   LogFile: $($result.LogFile)" -ForegroundColor Cyan

    # Check if directory exists
    $logDir = Split-Path $result.LogFile -Parent
    Write-Host "   Log Directory: $logDir" -ForegroundColor Cyan
    Write-Host "   Directory exists: $(Test-Path $logDir)" -ForegroundColor $(if (Test-Path $logDir) { 'Green' } else { 'Red' })
} catch {
    Write-Host "   ✗ Initialize-SmartLogging failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Test Write-SmartLog
Write-Host "`n2. Testing Write-SmartLog..." -ForegroundColor Yellow
try {
    Write-SmartLog -Message "Debug test message" -Level "INFO"
    Write-Host "   ✓ Write-SmartLog completed successfully" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Write-SmartLog failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Check if log file was created
Write-Host "`n3. Checking log file creation..." -ForegroundColor Yellow
if (Test-Path $result.LogFile) {
    Write-Host "   ✓ Log file exists: $($result.LogFile)" -ForegroundColor Green
    $content = Get-Content $result.LogFile -Raw
    if ($content) {
        Write-Host "   ✓ Log file has content" -ForegroundColor Green
        Write-Host "   Content preview:" -ForegroundColor Cyan
        $content -split "`n" | Select-Object -First 3 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        Write-Host "   ✗ Log file is empty" -ForegroundColor Red
    }
} else {
    Write-Host "   ✗ Log file was not created: $($result.LogFile)" -ForegroundColor Red
}

# Step 4: Manual file creation test
Write-Host "`n4. Testing manual file creation..." -ForegroundColor Yellow
$testFile = Join-Path $logDir "manual-test.log"
try {
    "Test content" | Out-File -FilePath $testFile -Encoding UTF8
    if (Test-Path $testFile) {
        Write-Host "   ✓ Manual file creation successful" -ForegroundColor Green
        Remove-Item $testFile -Force
    } else {
        Write-Host "   ✗ Manual file creation failed" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Manual file creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Test Add-Content directly
Write-Host "`n5. Testing Add-Content directly..." -ForegroundColor Yellow
$testFile2 = Join-Path $logDir "addcontent-test.log"
try {
    Add-Content -Path $testFile2 -Value "Direct Add-Content test" -ErrorAction Stop
    if (Test-Path $testFile2) {
        Write-Host "   ✓ Add-Content successful" -ForegroundColor Green
        $addContentResult = Get-Content $testFile2
        Write-Host "   Content: $addContentResult" -ForegroundColor Cyan
        Remove-Item $testFile2 -Force
    } else {
        Write-Host "   ✗ Add-Content did not create file" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Add-Content failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Debug Test Complete ===" -ForegroundColor Green
