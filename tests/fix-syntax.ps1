# Fix all the syntax issues in SmartLogging.Configuration.Tests.ps1
$filePath = "SmartLogging.Configuration.Tests.ps1"
$content = Get-Content $filePath -Raw

# Replace all instances of "}        It " with "}

        It "
$fixedContent = $content -replace '}[ ]*It "', "}`n`n        It `""

# Write back to file
Set-Content -Path $filePath -Value $fixedContent -NoNewline

Write-Host "Fixed all syntax issues in $filePath"
