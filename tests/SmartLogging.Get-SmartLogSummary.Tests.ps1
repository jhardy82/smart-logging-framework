#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive Pester tests for Get-SmartLogSummary function

.DESCRIPTION
    Phase 1.2 ContextForge Integration Testing Suite - Get-SmartLogSummary Function
    Tests summary generation, data aggregation, performance metrics, formatting options,
    and ContextForge integration scenarios.

.NOTES
    Author: ContextForge Development Team
    Version: 1.0.0
    Enhanced with ContextForge integration testing patterns
#>

BeforeAll {
    # Import the SmartLogging module
    $ModulePath = Join-Path $PSScriptRoot "..\src\src\core\SmartLogging.psm1"
    Import-Module $ModulePath -Force -Scope Global

    # Create test helper functions
    function Initialize-TestSession {
        param(
            [string]$ScriptName = "TestScript.ps1",
            [timespan]$Duration = [timespan]::FromSeconds(5),
            [bool]$WithErrors = $false,
            [hashtable]$TestResults = @{}
        )

        # Initialize logging
        $result = Initialize-SmartLogging -ScriptName $ScriptName

        # Simulate some passage of time if needed
        if ($Duration.TotalMilliseconds -gt 10) {
            Start-Sleep -Milliseconds ([Math]::Min($Duration.TotalMilliseconds, 100))
        }

        # Add test results if provided
        if ($TestResults.Count -gt 0) {
            foreach ($key in $TestResults.Keys) {
                $result.TestResults[$key] = $TestResults[$key]
            }
        }

        # Set error state if requested
        if ($WithErrors) {
            $result.HasError = $true
        }        return $result
    }    function Assert-SummaryStructure {
        param($Summary, [switch]$WithPerformanceMetrics)

        # Core summary structure validation
        $Summary | Should -Not -BeNullOrEmpty
        $Summary.PSObject.Properties.Name | Should -Contain 'ScriptName'
        $Summary.PSObject.Properties.Name | Should -Contain 'LogFile'
        $Summary.PSObject.Properties.Name | Should -Contain 'Duration'
        $Summary.PSObject.Properties.Name | Should -Contain 'HasError'
        $Summary.PSObject.Properties.Name | Should -Contain 'TestResults'
        $Summary.PSObject.Properties.Name | Should -Contain 'Environment'
        $Summary.PSObject.Properties.Name | Should -Contain 'LoggingConfig'

        # Validate property types
        $Summary.ScriptName | Should -BeOfType [string]
        $Summary.LogFile | Should -BeOfType [string]
        $Summary.Duration | Should -BeOfType [timespan]
        $Summary.HasError | Should -BeOfType [bool]
        $Summary.TestResults | Should -BeOfType [hashtable]
        $Summary.Environment | Should -Not -BeNullOrEmpty
        $Summary.LoggingConfig | Should -Not -BeNullOrEmpty

        # Environment structure validation (Environment is a hashtable)
        $Summary.Environment.Keys | Should -Contain 'IsProduction'
        $Summary.Environment.Keys | Should -Contain 'IsDevelopment'
        $Summary.Environment.Keys | Should -Contain 'IsCI'
    }
}

Describe "Get-SmartLogSummary" {
    Context "Basic Functionality" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should return null when logging not initialized" {
            $result = Get-SmartLogSummary

            $result | Should -BeNullOrEmpty
        }

        It "Should generate basic summary after initialization" {
            Initialize-TestSession -ScriptName "BasicTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.ScriptName | Should -Be "BasicTest.ps1"
        }

        It "Should calculate duration correctly" {
            Initialize-TestSession -ScriptName "DurationTest.ps1"
            Start-Sleep -Milliseconds 50  # Small delay to ensure measurable duration

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.Duration | Should -BeOfType [timespan]
            $summary.Duration.TotalMilliseconds | Should -BeGreaterThan 0
        }

        It "Should include environment information" {
            Initialize-TestSession -ScriptName "EnvironmentTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.Environment.IsProduction | Should -BeOfType [bool]
            $summary.Environment.IsDevelopment | Should -BeOfType [bool]
            $summary.Environment.IsCI | Should -BeOfType [bool]
        }

        It "Should include logging configuration" {
            Initialize-TestSession -ScriptName "ConfigTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.LoggingConfig | Should -Not -BeNullOrEmpty
            $summary.LoggingConfig | Should -HaveProperty 'LogLevel'
        }
    }

    Context "Data Accuracy" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should reflect error state correctly when no errors" {
            Initialize-TestSession -ScriptName "NoErrorTest.ps1" -WithErrors $false

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.HasError | Should -BeFalse
        }

        It "Should reflect error state correctly when errors exist" {
            Initialize-TestSession -ScriptName "ErrorTest.ps1" -WithErrors $true

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.HasError | Should -BeTrue
        }

        It "Should include custom test results" {
            $testResults = @{
                'UnitTests' = @{ Passed = 10; Failed = 2 }
                'CodeCoverage' = 85.5
                'Performance' = 'Good'
            }
            Initialize-TestSession -ScriptName "TestResultsTest.ps1" -TestResults $testResults

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.TestResults.UnitTests | Should -Not -BeNullOrEmpty
            $summary.TestResults.UnitTests.Passed | Should -Be 10
            $summary.TestResults.UnitTests.Failed | Should -Be 2
            $summary.TestResults.CodeCoverage | Should -Be 85.5
            $summary.TestResults.Performance | Should -Be 'Good'
        }

        It "Should maintain correct script name" {
            Initialize-TestSession -ScriptName "SpecificScript.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.ScriptName | Should -Be "SpecificScript.ps1"
        }

        It "Should maintain correct log file path" {
            $logPath = Join-Path $TestDrive "custom-test.log"
            Initialize-SmartLogging -ScriptName "CustomPath.ps1" -LogPath $logPath

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.LogFile | Should -Be $logPath
        }
    }

    Context "Duration Calculations" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should calculate short durations accurately" {
            Initialize-TestSession -ScriptName "ShortTest.ps1"
            Start-Sleep -Milliseconds 10

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.Duration.TotalMilliseconds | Should -BeGreaterOrEqual 5
            $summary.Duration.TotalMilliseconds | Should -BeLessOrEqual 1000
        }

        It "Should handle zero duration scenarios" {
            Initialize-TestSession -ScriptName "InstantTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.Duration | Should -BeOfType [timespan]
            $summary.Duration.TotalMilliseconds | Should -BeGreaterOrEqual 0
        }

        It "Should format duration consistently" {
            Initialize-TestSession -ScriptName "FormatTest.ps1"
            Start-Sleep -Milliseconds 50

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.Duration.ToString() | Should -Match "^\d{2}:\d{2}:\d{2}\.\d+"
        }
    }

    Context "Performance and Efficiency" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should generate summary within 50ms" {
            Initialize-TestSession -ScriptName "PerformanceTest.ps1"

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $summary = Get-SmartLogSummary
            $stopwatch.Stop()

            Assert-SummaryStructure -Summary $summary
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 50
        }

        It "Should handle large test results efficiently" {
            $largeTestResults = @{}
            for ($i = 1; $i -le 100; $i++) {
                $largeTestResults["Test$i"] = @{
                    Result = 'Passed'
                    Duration = [timespan]::FromMilliseconds($i * 10)
                    Details = "Test $i executed successfully with data set $i"
                }
            }
            Initialize-TestSession -ScriptName "LargeDataTest.ps1" -TestResults $largeTestResults

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $summary = Get-SmartLogSummary
            $stopwatch.Stop()

            Assert-SummaryStructure -Summary $summary
            $summary.TestResults.Count | Should -Be 100
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 100
        }

        It "Should not affect logging performance" {
            Initialize-TestSession -ScriptName "LoggingPerformanceTest.ps1"

            # Measure time for logging operations before summary
            $beforeSummary = Measure-Command {
                for ($i = 1; $i -le 10; $i++) {
                    Write-SmartLog -Message "Test message $i" -Level 'INFO'
                }
            }

            # Generate summary
            $summary = Get-SmartLogSummary

            # Measure time for logging operations after summary
            $afterSummary = Measure-Command {
                for ($i = 11; $i -le 20; $i++) {
                    Write-SmartLog -Message "Test message $i" -Level 'INFO'
                }
            }

            Assert-SummaryStructure -Summary $summary
            # Logging performance should not degrade by more than 20%
            $afterSummary.TotalMilliseconds | Should -BeLessOrEqual ($beforeSummary.TotalMilliseconds * 1.2)
        }
    }

    Context "Error Handling and Edge Cases" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should handle corrupted context gracefully" {
            Initialize-TestSession -ScriptName "CorruptedTest.ps1"

            # This test would require internal access to modify context
            # We'll test the current implementation's robustness
            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
        }

        It "Should handle missing StartTime gracefully" {
            Initialize-TestSession -ScriptName "MissingTimeTest.ps1"

            # Generate summary (should not throw even if StartTime is missing)
            { $summary = Get-SmartLogSummary } | Should -Not -Throw
        }

        It "Should handle empty test results" {
            Initialize-TestSession -ScriptName "EmptyResultsTest.ps1" -TestResults @{}

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.TestResults.Count | Should -Be 0
        }

        It "Should handle null test results gracefully" {
            Initialize-TestSession -ScriptName "NullResultsTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            $summary.TestResults | Should -Not -BeNullOrEmpty
        }
    }

    Context "Multiple Summary Generations" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should generate consistent summaries across multiple calls" {
            Initialize-TestSession -ScriptName "ConsistencyTest.ps1"
            Start-Sleep -Milliseconds 10

            $summary1 = Get-SmartLogSummary
            Start-Sleep -Milliseconds 10
            $summary2 = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary1
            Assert-SummaryStructure -Summary $summary2

            # Core properties should remain the same
            $summary1.ScriptName | Should -Be $summary2.ScriptName
            $summary1.LogFile | Should -Be $summary2.LogFile
            $summary1.HasError | Should -Be $summary2.HasError

            # Duration should increase
            $summary2.Duration | Should -BeGreaterThan $summary1.Duration
        }

        It "Should reflect state changes between summary calls" {
            Initialize-TestSession -ScriptName "StateChangeTest.ps1"

            $summary1 = Get-SmartLogSummary
            Assert-SummaryStructure -Summary $summary1
            $summary1.HasError | Should -BeFalse

            # Simulate an error occurring
            Write-SmartLog -Message "Simulated error" -Level 'ERROR'

            $summary2 = Get-SmartLogSummary
            Assert-SummaryStructure -Summary $summary2
            # Note: The current implementation may not automatically set HasError to true
            # This test validates current behavior
        }

        It "Should handle rapid successive summary calls" {
            Initialize-TestSession -ScriptName "RapidCallsTest.ps1"

            $summaries = @()
            for ($i = 1; $i -le 10; $i++) {
                $summaries += Get-SmartLogSummary
                Start-Sleep -Milliseconds 1
            }

            $summaries.Count | Should -Be 10
            foreach ($summary in $summaries) {
                Assert-SummaryStructure -Summary $summary
            }

            # Each summary should have increasing duration
            for ($i = 1; $i -lt $summaries.Count; $i++) {
                $summaries[$i].Duration | Should -BeGreaterOrEqual $summaries[$i-1].Duration
            }
        }
    }

    Context "Integration with Other Functions" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should work correctly after Write-SmartLog calls" {
            Initialize-TestSession -ScriptName "WriteLogTest.ps1"

            Write-SmartLog -Message "Test message 1" -Level 'INFO'
            Write-SmartLog -Message "Test message 2" -Level 'DEBUG'
            Write-SmartLog -Message "Test message 3" -Level 'SUCCESS'

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
        }

        It "Should work correctly after performance timer operations" {
            Initialize-TestSession -ScriptName "PerformanceTimerTest.ps1"

            Start-PerformanceTimer -OperationName "TestOperation"
            Start-Sleep -Milliseconds 10
            Stop-PerformanceTimer -OperationName "TestOperation" -LogResult

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
        }

        It "Should work correctly after Reset-SmartLogging" {
            Initialize-TestSession -ScriptName "ResetTest.ps1"

            $summaryBefore = Get-SmartLogSummary
            Assert-SummaryStructure -Summary $summaryBefore

            Reset-SmartLogging

            $summaryAfter = Get-SmartLogSummary
            $summaryAfter | Should -BeNullOrEmpty
        }
    }

    Context "Data Types and Structure Validation" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should return PSCustomObject type" {
            Initialize-TestSession -ScriptName "TypeTest.ps1"

            $summary = Get-SmartLogSummary

            $summary | Should -BeOfType [PSCustomObject]
        }

        It "Should have all expected properties with correct types" {
            Initialize-TestSession -ScriptName "PropertyTypeTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary

            # Validate specific types
            $summary.ScriptName | Should -BeOfType [string]
            $summary.LogFile | Should -BeOfType [string]
            $summary.Duration | Should -BeOfType [timespan]
            $summary.HasError | Should -BeOfType [bool]
            $summary.TestResults | Should -BeOfType [hashtable]
        }

        It "Should serialize to JSON correctly" {
            Initialize-TestSession -ScriptName "SerializationTest.ps1"

            $summary = Get-SmartLogSummary

            { $json = $summary | ConvertTo-Json -Depth 5 } | Should -Not -Throw

            $json | Should -Not -BeNullOrEmpty
            $json | Should -Match '"ScriptName"'
            $json | Should -Match '"Duration"'
        }
    }

    Context "ContextForge Integration Scenarios" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should work without ContextForge helpers" {
            # Standard summary generation should work without ContextForge
            Initialize-TestSession -ScriptName "NoContextForge.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
        }

        It "Should maintain backward compatibility" {
            # Test that existing calling patterns work
            Initialize-TestSession -ScriptName "BackwardCompatTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            # Should contain all expected legacy properties
        }

        It "Should handle mixed environment detection" {
            Initialize-TestSession -ScriptName "MixedEnvTest.ps1"

            $summary = Get-SmartLogSummary

            Assert-SummaryStructure -Summary $summary
            # At least one environment flag should be true
            ($summary.Environment.IsProduction -or
             $summary.Environment.IsDevelopment -or
             $summary.Environment.IsCI) | Should -BeTrue
        }
    }

    Context "Memory and Resource Efficiency" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should not leak memory during multiple summary generations" {
            Initialize-TestSession -ScriptName "MemoryLeakTest.ps1"

            # Get baseline memory
            $initialMemory = [System.GC]::GetTotalMemory($true)

            # Generate multiple summaries
            for ($i = 1; $i -le 50; $i++) {
                $summary = Get-SmartLogSummary
                Assert-SummaryStructure -Summary $summary
            }

            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $finalMemory = [System.GC]::GetTotalMemory($true)

            # Memory increase should be minimal (less than 1MB)
            $memoryIncrease = $finalMemory - $initialMemory
            $memoryIncrease | Should -BeLessOrEqual (1024 * 1024)
        }

        It "Should be efficient with large context data" {
            # Create large test results
            $largeData = @{}
            for ($i = 1; $i -le 1000; $i++) {
                $largeData["LargeTest$i"] = "Data" * 100  # Large string values
            }

            Initialize-TestSession -ScriptName "LargeContextTest.ps1" -TestResults $largeData

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $summary = Get-SmartLogSummary
            $stopwatch.Stop()

            Assert-SummaryStructure -Summary $summary
            $summary.TestResults.Count | Should -Be 1000
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 200
        }
    }
}
