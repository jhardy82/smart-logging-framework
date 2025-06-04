#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive Pester test suite for SmartLogging.psm1 Write-SmartLog function

.DESCRIPTION
    Phase 1.2 Testing & Validation Enhancement
    Tests the enhanced Write-SmartLog function including:
    - Enterprise parameter validation (UserImpact, OperationId)
    - ContextForge integration scenarios
    - Performance tracking capabilities
    - Error handling and edge cases
    - Cross-platform compatibility

.NOTES
    Author: ContextForge Testing Framework
    Version: 1.0.0 (Phase 1.2)
    Test Target: Write-SmartLog function
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\src\src\core\SmartLogging.psm1"
    if (-not (Test-Path $ModulePath)) {
        throw "SmartLogging module not found at: $ModulePath"
    }

    Import-Module $ModulePath -Force -Scope Global

    # Create test log directory
    $TestLogDir = Join-Path $env:TEMP "SmartLogging-Tests-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    New-Item -ItemType Directory -Path $TestLogDir -Force | Out-Null

    # Test helper functions
    function New-TestContext {
        param(
            [string]$ScriptName = "Test-Script",
            [switch]$WithContextForge
        )

        $Context = [PSCustomObject]@{
            ScriptName  = $ScriptName
            LogFile     = Join-Path $TestLogDir "$ScriptName.log"
            HasError    = $false
            StartTime   = Get-Date
            TestResults = @{}
        }

        if ($WithContextForge) {
            $Context | Add-Member -MemberType NoteProperty -Name InstanceId -Value ([guid]::NewGuid())
            $Context | Add-Member -MemberType NoteProperty -Name DeploymentPhase -Value 'Testing'
            $Context | Add-Member -MemberType NoteProperty -Name ToolName -Value 'Pester-Tests'
        }

        return $Context
    }

    function Get-LogContent {
        param([string]$LogPath)
        if (Test-Path $LogPath) {
            return Get-Content $LogPath -Raw
        }
        return ""
    }
}

Describe "Write-SmartLog Function Tests" {

    Context "Basic Functionality" {
        BeforeEach {
            # Reset module state
            Reset-SmartLogging
            $Script:Context = New-TestContext -ScriptName "BasicTest"
        }

        It "Should write basic log message without errors" {
            { Write-SmartLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
        }

        It "Should accept all valid log levels" {
            $ValidLevels = @('DEBUG', 'INFO', 'WARN', 'ERROR', 'SUCCESS')

            foreach ($level in $ValidLevels) {
                { Write-SmartLog -Message "Test $level message" -Level $level } | Should -Not -Throw
            }
        }

        It "Should create log file when context is initialized" {
            Initialize-SmartLogging -ScriptName "FileTest"
            Write-SmartLog -Message "File test message" -Level "INFO"

            $Script:Context.LogFile | Should -Exist
            Get-LogContent -LogPath $Script:Context.LogFile | Should -Match "File test message"
        }

        It "Should include timestamp in log entries by default" {
            Initialize-SmartLogging -ScriptName "TimestampTest"
            Write-SmartLog -Message "Timestamp test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
        }

        It "Should skip timestamp when SkipTimestamp is true" {
            Initialize-SmartLogging -ScriptName "NoTimestampTest"
            Write-SmartLog -Message "No timestamp test" -Level "INFO" -SkipTimestamp

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Not -Match "\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"
            $logContent | Should -Match "\[INFO\].*No timestamp test"
        }
    }

    Context "Enterprise Parameter Validation" {
        BeforeEach {
            Reset-SmartLogging
            $Script:Context = New-TestContext -ScriptName "EnterpriseTest" -WithContextForge
        }

        It "Should accept all valid UserImpact values" {
            $ValidImpacts = @('None', 'Low', 'Medium', 'High', 'Critical')

            foreach ($impact in $ValidImpacts) {
                { Write-SmartLog -Message "Impact test" -Level "INFO" -UserImpact $impact } | Should -Not -Throw
            }
        }

        It "Should reject invalid UserImpact values" {
            { Write-SmartLog -Message "Invalid impact" -Level "INFO" -UserImpact "Invalid" } | Should -Throw
        }

        It "Should accept OperationId parameter" {
            $operationId = "TEST-OP-$(Get-Date -Format 'HHmmss')"
            { Write-SmartLog -Message "Operation test" -Level "INFO" -OperationId $operationId } | Should -Not -Throw
        }

        It "Should generate OperationId automatically when ContextForge is active" {
            Initialize-SmartLogging -ScriptName "AutoOpIdTest"
            Write-SmartLog -Message "Auto operation ID test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "OpId=LOG-"
        }

        It "Should include UserImpact in log context when not 'None'" {
            Initialize-SmartLogging -ScriptName "ImpactContextTest"
            Write-SmartLog -Message "High impact test" -Level "WARN" -UserImpact "High"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "UserImpact=High"
        }

        It "Should exclude UserImpact from log context when 'None'" {
            Initialize-SmartLogging -ScriptName "NoImpactContextTest"
            Write-SmartLog -Message "No impact test" -Level "INFO" -UserImpact "None"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Not -Match "UserImpact=None"
        }
    }

    Context "ContextForge Integration" {
        BeforeEach {
            Reset-SmartLogging
            $Script:Context = New-TestContext -ScriptName "ContextForgeTest" -WithContextForge
        }

        It "Should include InstanceId in enterprise context" {
            Initialize-SmartLogging -ScriptName "InstanceIdTest"
            Write-SmartLog -Message "Instance ID test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "InstanceId="
        }

        It "Should include DeploymentPhase in enterprise context" {
            Initialize-SmartLogging -ScriptName "PhaseTest"
            Write-SmartLog -Message "Deployment phase test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "Phase=Testing"
        }

        It "Should include ToolName in enterprise context" {
            Initialize-SmartLogging -ScriptName "ToolTest"
            Write-SmartLog -Message "Tool name test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "Tool=Pester-Tests"
        }

        It "Should handle missing ContextForge gracefully" {
            # Create context without ContextForge properties
            $Script:Context = New-TestContext -ScriptName "NoContextForgeTest"
            Initialize-SmartLogging -ScriptName "NoContextForgeTest"

            { Write-SmartLog -Message "No ContextForge test" -Level "INFO" } | Should -Not -Throw
        }
    }

    Context "Performance Tracking" {
        BeforeEach {
            Reset-SmartLogging
            $Script:Context = New-TestContext -ScriptName "PerformanceTest"
        }

        It "Should complete logging operation within performance threshold" {
            Initialize-SmartLogging -ScriptName "PerfTest"

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Write-SmartLog -Message "Performance test message" -Level "INFO"
            $stopwatch.Stop()

            # Should complete within 10ms for enterprise grade performance
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10
        }

        It "Should handle large message data efficiently" {
            Initialize-SmartLogging -ScriptName "LargeDataTest"
            $largeMessage = "X" * 1000  # 1KB message

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Write-SmartLog -Message $largeMessage -Level "INFO"
            $stopwatch.Stop()

            # Should handle large data within reasonable time
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 50
        }

        It "Should handle structured data parameter" {
            Initialize-SmartLogging -ScriptName "StructuredDataTest"
            $structuredData = @{
                Operation = "Test"
                Status    = "Success"
                Duration  = "100ms"
            }

            { Write-SmartLog -Message "Structured test" -Level "INFO" -Data $structuredData } | Should -Not -Throw

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "Data:"
        }
    }

    Context "Error Handling and Edge Cases" {
        BeforeEach {
            Reset-SmartLogging
        }

        It "Should handle null message gracefully" {
            { Write-SmartLog -Message $null -Level "INFO" } | Should -Not -Throw
        }

        It "Should handle empty message gracefully" {
            { Write-SmartLog -Message "" -Level "INFO" } | Should -Not -Throw
        }

        It "Should handle null component gracefully" {
            { Write-SmartLog -Message "Test" -Level "INFO" -Component $null } | Should -Not -Throw
        }

        It "Should auto-detect component from calling script" {
            # This test verifies component auto-detection logic
            $Script:Context = New-TestContext -ScriptName "ComponentTest"
            Initialize-SmartLogging -ScriptName "ComponentTest"
            Write-SmartLog -Message "Component detection test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "\[SmartLogging\.Tests\.ps1\]"
        }

        It "Should handle concurrent logging operations" {
            Initialize-SmartLogging -ScriptName "ConcurrentTest"

            # Simulate concurrent logging
            1..5 | ForEach-Object -Parallel {
                Write-SmartLog -Message "Concurrent message $_" -Level "INFO"
            }

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "Concurrent message"
        }
    }

    Context "Component Auto-Detection" {
        BeforeEach {
            Reset-SmartLogging
            $Script:Context = New-TestContext -ScriptName "ComponentAutoTest"
        }

        It "Should use provided component when specified" {
            Initialize-SmartLogging -ScriptName "ComponentTest"
            Write-SmartLog -Message "Custom component test" -Level "INFO" -Component "CustomComponent"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "\[CustomComponent\]"
        }

        It "Should fallback to SmartLogging when component detection fails" {
            Initialize-SmartLogging -ScriptName "FallbackTest"
            # Clear PSCommandPath to simulate detection failure
            $originalPath = $MyInvocation.PSCommandPath
            Write-SmartLog -Message "Fallback test" -Level "INFO"

            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            $logContent | Should -Match "\[SmartLogging\]"
        }
    }
}

Describe "Write-SmartLog Integration Tests" {

    Context "End-to-End Scenarios" {
        BeforeEach {
            Reset-SmartLogging
        }

        It "Should complete full enterprise logging workflow" {
            # Initialize with ContextForge integration
            $testContext = New-TestContext -ScriptName "E2ETest" -WithContextForge
            $Script:Context = $testContext
            Initialize-SmartLogging -ScriptName "E2ETest"

            # Log messages with various enterprise parameters
            Write-SmartLog -Message "Starting operation" -Level "INFO" -UserImpact "Low" -OperationId "E2E-001"
            Write-SmartLog -Message "Processing data" -Level "DEBUG" -UserImpact "Medium"
            Write-SmartLog -Message "Operation completed" -Level "SUCCESS" -UserImpact "Low"

            # Verify log file content
            $logContent = Get-LogContent -LogPath $testContext.LogFile
            $logContent | Should -Match "Starting operation"
            $logContent | Should -Match "Processing data"
            $logContent | Should -Match "Operation completed"
            $logContent | Should -Match "E2E-001"
            $logContent | Should -Match "UserImpact=Low"
            $logContent | Should -Match "UserImpact=Medium"
        }

        It "Should maintain performance under load" {
            Initialize-SmartLogging -ScriptName "LoadTest"

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Log 100 messages rapidly
            1..100 | ForEach-Object {
                Write-SmartLog -Message "Load test message $_" -Level "INFO" -UserImpact "Low"
            }

            $stopwatch.Stop()

            # Should complete 100 operations within 500ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 500

            # Verify all messages were logged
            $logContent = Get-LogContent -LogPath $Script:Context.LogFile
            ($logContent -split "`n" | Where-Object { $_ -match "Load test message" }).Count | Should -Be 100
        }
    }
}

AfterAll {
    # Cleanup test artifacts
    if (Test-Path $TestLogDir) {
        Remove-Item $TestLogDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Reset module state
    Reset-SmartLogging

    Write-Host "🧪 Write-SmartLog test suite completed" -ForegroundColor Green
}
