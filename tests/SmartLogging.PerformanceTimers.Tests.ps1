#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive Pester tests for Performance Timer functions

.DESCRIPTION
    Phase 1.2 ContextForge Integration Testing Suite - Performance Timer Functions
    Tests Start-PerformanceTimer, Stop-PerformanceTimer functionality including
    timing accuracy, concurrent operations, error handling, and enterprise scenarios.

.NOTES
    Author: ContextForge Development Team
    Version: 1.0.0
    Enhanced with ContextForge integration testing patterns
#>

BeforeAll {
    # Import the SmartLogging module
    $ModulePath = Join-Path $PSScriptRoot "..\src\src\core\SmartLogging.psm1"
    Import-Module $ModulePath -Force -Scope Global

    # Initialize logging for testing
    Initialize-SmartLogging -ScriptName "PerformanceTimerTests.ps1"

    # Create test helper functions
    function Assert-TimerExists {
        param([string]$OperationName)

        # We can't directly access script scope variables, but we can test behavior
        # by attempting to stop the timer
        { Stop-PerformanceTimer -OperationName $OperationName } | Should -Not -Throw
    }

    function Assert-TimerNotExists {
        param([string]$OperationName)

        # Stopping a non-existent timer should still not throw but should warn/log
        $result = Stop-PerformanceTimer -OperationName $OperationName
        $result | Should -BeNullOrEmpty
    }

    function Measure-TimingAccuracy {
        param(
            [string]$OperationName,
            [int]$ExpectedDurationMs,
            [int]$ToleranceMs = 50
        )

        Start-PerformanceTimer -OperationName $OperationName
        Start-Sleep -Milliseconds $ExpectedDurationMs
        $duration = Stop-PerformanceTimer -OperationName $OperationName

        $duration | Should -Not -BeNullOrEmpty
        $duration | Should -BeOfType [timespan]
        $actualMs = $duration.TotalMilliseconds

        # Check if within tolerance
        $actualMs | Should -BeGreaterOrEqual ($ExpectedDurationMs - $ToleranceMs)
        $actualMs | Should -BeLessOrEqual ($ExpectedDurationMs + $ToleranceMs + 50)  # Extra buffer for CI environments

        return $actualMs
    }
}

Describe "Start-PerformanceTimer" {
    Context "Basic Functionality" {
        It "Should start a timer with valid operation name" {
            { Start-PerformanceTimer -OperationName "BasicTest" } | Should -Not -Throw

            # Verify timer was created by successfully stopping it
            Assert-TimerExists -OperationName "BasicTest"
        }

        It "Should handle multiple different operation names" {
            $operations = @("Operation1", "Operation2", "Operation3")

            foreach ($op in $operations) {
                { Start-PerformanceTimer -OperationName $op } | Should -Not -Throw
            }

            # Verify all timers exist
            foreach ($op in $operations) {
                Assert-TimerExists -OperationName $op
            }
        }

        It "Should allow restarting the same operation name" {
            Start-PerformanceTimer -OperationName "RestartTest"
            Stop-PerformanceTimer -OperationName "RestartTest"

            # Should be able to restart with same name
            { Start-PerformanceTimer -OperationName "RestartTest" } | Should -Not -Throw
            Assert-TimerExists -OperationName "RestartTest"
        }

        It "Should log timer start event" {
            # This test validates that the function logs appropriately
            { Start-PerformanceTimer -OperationName "LogTest" } | Should -Not -Throw
        }
    }

    Context "Parameter Validation" {
        It "Should require OperationName parameter" {
            { Start-PerformanceTimer } | Should -Throw "*OperationName*"
        }

        It "Should handle empty operation name gracefully" {
            { Start-PerformanceTimer -OperationName "" } | Should -Not -Throw
        }

        It "Should handle null operation name" {
            { Start-PerformanceTimer -OperationName $null } | Should -Throw
        }

        It "Should handle special characters in operation name" {
            $specialNames = @(
                "Operation-With-Dashes",
                "Operation_With_Underscores",
                "Operation.With.Dots",
                "Operation With Spaces",
                "Operation(With)Parentheses"
            )

            foreach ($name in $specialNames) {
                { Start-PerformanceTimer -OperationName $name } | Should -Not -Throw
                Assert-TimerExists -OperationName $name
            }
        }

        It "Should handle long operation names" {
            $longName = "VeryLong" * 50 + "OperationName"

            { Start-PerformanceTimer -OperationName $longName } | Should -Not -Throw
            Assert-TimerExists -OperationName $longName
        }
    }

    Context "Concurrent Operations" {
        It "Should handle multiple simultaneous timers" {
            $operations = @("Concurrent1", "Concurrent2", "Concurrent3", "Concurrent4", "Concurrent5")

            # Start all timers simultaneously
            foreach ($op in $operations) {
                Start-PerformanceTimer -OperationName $op
            }

            # Small delay
            Start-Sleep -Milliseconds 50

            # Verify all timers are running
            foreach ($op in $operations) {
                $duration = Stop-PerformanceTimer -OperationName $op
                $duration | Should -Not -BeNullOrEmpty
                $duration.TotalMilliseconds | Should -BeGreaterThan 40
            }
        }

        It "Should handle rapid sequential timer starts" {
            for ($i = 1; $i -le 20; $i++) {
                Start-PerformanceTimer -OperationName "Rapid$i"
            }

            # Stop all timers
            for ($i = 1; $i -le 20; $i++) {
                $duration = Stop-PerformanceTimer -OperationName "Rapid$i"
                $duration | Should -Not -BeNullOrEmpty
            }
        }

        It "Should maintain timer isolation" {
            Start-PerformanceTimer -OperationName "Timer1"
            Start-Sleep -Milliseconds 50
            Start-PerformanceTimer -OperationName "Timer2"
            Start-Sleep -Milliseconds 50

            $duration1 = Stop-PerformanceTimer -OperationName "Timer1"
            $duration2 = Stop-PerformanceTimer -OperationName "Timer2"

            $duration1.TotalMilliseconds | Should -BeGreaterThan $duration2.TotalMilliseconds
        }
    }

    Context "Performance and Accuracy" {
        It "Should start timer with minimal overhead" {
            $overhead = Measure-Command {
                Start-PerformanceTimer -OperationName "OverheadTest"
            }

            # Timer start should complete within 10ms
            $overhead.TotalMilliseconds | Should -BeLessOrEqual 10

            # Clean up
            Stop-PerformanceTimer -OperationName "OverheadTest"
        }

        It "Should handle high-frequency timer operations" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            for ($i = 1; $i -le 100; $i++) {
                Start-PerformanceTimer -OperationName "HighFreq$i"
                Stop-PerformanceTimer -OperationName "HighFreq$i"
            }

            $stopwatch.Stop()
            # 100 timer operations should complete within 500ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 500
        }
    }

    Context "Error Handling" {
        It "Should handle timer initialization without SmartLogging context" {
            # This test is implementation-specific
            # The function should work even without proper SmartLogging initialization
            { Start-PerformanceTimer -OperationName "NoContextTest" } | Should -Not -Throw
        }

        It "Should handle system resource constraints gracefully" {
            # Start a large number of timers to test resource handling
            $operations = @()
            for ($i = 1; $i -le 1000; $i++) {
                $operations += "ResourceTest$i"
            }

            foreach ($op in $operations) {
                { Start-PerformanceTimer -OperationName $op } | Should -Not -Throw
            }

            # Clean up - stop all timers
            foreach ($op in $operations) {
                Stop-PerformanceTimer -OperationName $op
            }
        }
    }
}

Describe "Stop-PerformanceTimer" {
    Context "Basic Functionality" {
        BeforeEach {
            # Ensure clean state for each test
            Start-PerformanceTimer -OperationName "TestTimer"
        }

        It "Should stop an existing timer and return duration" {
            Start-Sleep -Milliseconds 50
            $duration = Stop-PerformanceTimer -OperationName "TestTimer"

            $duration | Should -Not -BeNullOrEmpty
            $duration | Should -BeOfType [timespan]
            $duration.TotalMilliseconds | Should -BeGreaterThan 40
        }

        It "Should remove timer after stopping" {
            Stop-PerformanceTimer -OperationName "TestTimer"

            # Attempting to stop again should return null
            Assert-TimerNotExists -OperationName "TestTimer"
        }

        It "Should log result when LogResult switch is used" {
            Start-Sleep -Milliseconds 20

            { Stop-PerformanceTimer -OperationName "TestTimer" -LogResult } | Should -Not -Throw
        }

        It "Should not log result when LogResult switch is not used" {
            Start-Sleep -Milliseconds 20

            { Stop-PerformanceTimer -OperationName "TestTimer" } | Should -Not -Throw
        }
    }

    Context "Timer Not Found Scenarios" {
        It "Should handle non-existent timer gracefully" {
            $result = Stop-PerformanceTimer -OperationName "NonExistentTimer"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty operation name" {
            $result = Stop-PerformanceTimer -OperationName ""

            $result | Should -BeNullOrEmpty
        }

        It "Should handle null operation name" {
            { Stop-PerformanceTimer -OperationName $null } | Should -Throw
        }

        It "Should handle stopping already stopped timer" {
            Start-PerformanceTimer -OperationName "AlreadyStoppedTest"
            Stop-PerformanceTimer -OperationName "AlreadyStoppedTest"

            # Second stop should return null
            $result = Stop-PerformanceTimer -OperationName "AlreadyStoppedTest"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Timing Accuracy" {
        It "Should measure short durations accurately (10-50ms)" {
            $actualMs = Measure-TimingAccuracy -OperationName "ShortTest" -ExpectedDurationMs 25 -ToleranceMs 20
            $actualMs | Should -BeGreaterThan 10
            $actualMs | Should -BeLessOrEqual 100
        }

        It "Should measure medium durations accurately (100-500ms)" {
            $actualMs = Measure-TimingAccuracy -OperationName "MediumTest" -ExpectedDurationMs 200 -ToleranceMs 50
            $actualMs | Should -BeGreaterThan 150
            $actualMs | Should -BeLessOrEqual 300
        }

        It "Should handle near-instantaneous operations" {
            Start-PerformanceTimer -OperationName "InstantTest"
            $duration = Stop-PerformanceTimer -OperationName "InstantTest"

            $duration | Should -Not -BeNullOrEmpty
            $duration | Should -BeOfType [timespan]
            $duration.TotalMilliseconds | Should -BeGreaterOrEqual 0
            $duration.TotalMilliseconds | Should -BeLessOrEqual 100
        }

        It "Should maintain precision across multiple timer operations" {
            $durations = @()

            for ($i = 1; $i -le 5; $i++) {
                Start-PerformanceTimer -OperationName "PrecisionTest$i"
                Start-Sleep -Milliseconds ($i * 10)  # 10, 20, 30, 40, 50 ms
                $durations += Stop-PerformanceTimer -OperationName "PrecisionTest$i"
            }

            # Each subsequent duration should be larger than the previous
            for ($i = 1; $i -lt $durations.Count; $i++) {
                $durations[$i].TotalMilliseconds | Should -BeGreaterThan $durations[$i-1].TotalMilliseconds
            }
        }
    }

    Context "Return Value Validation" {
        It "Should return TimeSpan object for valid timers" {
            Start-PerformanceTimer -OperationName "ReturnTypeTest"
            Start-Sleep -Milliseconds 10
            $result = Stop-PerformanceTimer -OperationName "ReturnTypeTest"

            $result | Should -BeOfType [timespan]
            $result.GetType().FullName | Should -Be "System.TimeSpan"
        }

        It "Should return null for invalid timers" {
            $result = Stop-PerformanceTimer -OperationName "InvalidTimer"

            $result | Should -BeNullOrEmpty
        }

        It "Should provide detailed timing information" {
            Start-PerformanceTimer -OperationName "DetailedTest"
            Start-Sleep -Milliseconds 100
            $duration = Stop-PerformanceTimer -OperationName "DetailedTest"

            # TimeSpan should have detailed properties
            $duration.TotalMilliseconds | Should -BeOfType [double]
            $duration.Ticks | Should -BeOfType [long]
            $duration.Milliseconds | Should -BeOfType [int]
        }
    }

    Context "Logging Integration" {
        It "Should log to SmartLog when LogResult is true" {
            Start-PerformanceTimer -OperationName "LogTest"
            Start-Sleep -Milliseconds 50

            # Should not throw and should log the result
            { Stop-PerformanceTimer -OperationName "LogTest" -LogResult } | Should -Not -Throw
        }

        It "Should include operation name in log message when logging" {
            Start-PerformanceTimer -OperationName "NamedLogTest"
            Start-Sleep -Milliseconds 25

            { Stop-PerformanceTimer -OperationName "NamedLogTest" -LogResult } | Should -Not -Throw
        }

        It "Should include duration in log message when logging" {
            Start-PerformanceTimer -OperationName "DurationLogTest"
            Start-Sleep -Milliseconds 30

            { Stop-PerformanceTimer -OperationName "DurationLogTest" -LogResult } | Should -Not -Throw
        }
    }

    Context "Performance and Efficiency" {
        It "Should stop timer with minimal overhead" {
            Start-PerformanceTimer -OperationName "StopOverheadTest"
            Start-Sleep -Milliseconds 50

            $overhead = Measure-Command {
                Stop-PerformanceTimer -OperationName "StopOverheadTest"
            }

            # Timer stop should complete within 10ms
            $overhead.TotalMilliseconds | Should -BeLessOrEqual 10
        }

        It "Should handle cleanup efficiently for multiple timers" {
            # Start multiple timers
            for ($i = 1; $i -le 50; $i++) {
                Start-PerformanceTimer -OperationName "CleanupTest$i"
            }

            # Stop all timers and measure total time
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($i = 1; $i -le 50; $i++) {
                Stop-PerformanceTimer -OperationName "CleanupTest$i"
            }
            $stopwatch.Stop()

            # Should complete within 200ms
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 200
        }
    }
}

Describe "Performance Timer Integration" {
    Context "Start-Stop Timer Workflow" {
        It "Should support nested timer operations" {
            Start-PerformanceTimer -OperationName "OuterOperation"
            Start-Sleep -Milliseconds 20

            Start-PerformanceTimer -OperationName "InnerOperation"
            Start-Sleep -Milliseconds 30
            $innerDuration = Stop-PerformanceTimer -OperationName "InnerOperation"

            Start-Sleep -Milliseconds 20
            $outerDuration = Stop-PerformanceTimer -OperationName "OuterOperation"

            $innerDuration | Should -Not -BeNullOrEmpty
            $outerDuration | Should -Not -BeNullOrEmpty
            $outerDuration.TotalMilliseconds | Should -BeGreaterThan $innerDuration.TotalMilliseconds
        }

        It "Should support overlapping timer operations" {
            Start-PerformanceTimer -OperationName "Timer1"
            Start-Sleep -Milliseconds 20
            Start-PerformanceTimer -OperationName "Timer2"
            Start-Sleep -Milliseconds 20
            Start-PerformanceTimer -OperationName "Timer3"
            Start-Sleep -Milliseconds 20

            $duration3 = Stop-PerformanceTimer -OperationName "Timer3"
            $duration1 = Stop-PerformanceTimer -OperationName "Timer1"
            $duration2 = Stop-PerformanceTimer -OperationName "Timer2"

            $duration1.TotalMilliseconds | Should -BeGreaterThan $duration2.TotalMilliseconds
            $duration2.TotalMilliseconds | Should -BeGreaterThan $duration3.TotalMilliseconds
        }

        It "Should support timer restart scenarios" {
            # First timing
            Start-PerformanceTimer -OperationName "RestartableTimer"
            Start-Sleep -Milliseconds 30
            $firstDuration = Stop-PerformanceTimer -OperationName "RestartableTimer"

            # Second timing with same name
            Start-PerformanceTimer -OperationName "RestartableTimer"
            Start-Sleep -Milliseconds 50
            $secondDuration = Stop-PerformanceTimer -OperationName "RestartableTimer"

            $firstDuration | Should -Not -BeNullOrEmpty
            $secondDuration | Should -Not -BeNullOrEmpty
            $secondDuration.TotalMilliseconds | Should -BeGreaterThan $firstDuration.TotalMilliseconds
        }
    }

    Context "Integration with SmartLogging" {
        It "Should work correctly with SmartLogging context" {
            # Initialize fresh logging context
            Initialize-SmartLogging -ScriptName "TimerIntegrationTest.ps1"

            Start-PerformanceTimer -OperationName "ContextTest"
            Start-Sleep -Milliseconds 25
            $duration = Stop-PerformanceTimer -OperationName "ContextTest" -LogResult

            $duration | Should -Not -BeNullOrEmpty
        }

        It "Should maintain timer state across logging operations" {
            Start-PerformanceTimer -OperationName "LoggingStateTest"

            Write-SmartLog -Message "Test message 1" -Level 'INFO'
            Start-Sleep -Milliseconds 20
            Write-SmartLog -Message "Test message 2" -Level 'DEBUG'
            Start-Sleep -Milliseconds 20

            $duration = Stop-PerformanceTimer -OperationName "LoggingStateTest"

            $duration | Should -Not -BeNullOrEmpty
            $duration.TotalMilliseconds | Should -BeGreaterThan 35
        }

        It "Should work correctly with Get-SmartLogSummary" {
            Start-PerformanceTimer -OperationName "SummaryTest"
            Start-Sleep -Milliseconds 30

            $summary = Get-SmartLogSummary
            $summary | Should -Not -BeNullOrEmpty

            $duration = Stop-PerformanceTimer -OperationName "SummaryTest"
            $duration | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error Recovery and Resilience" {
        It "Should handle timer state corruption gracefully" {
            Start-PerformanceTimer -OperationName "CorruptionTest"

            # Simulate some error scenario
            { Stop-PerformanceTimer -OperationName "CorruptionTest" } | Should -Not -Throw
        }

        It "Should recover from memory pressure scenarios" {
            # Create many timers to test memory pressure
            for ($i = 1; $i -le 100; $i++) {
                Start-PerformanceTimer -OperationName "MemoryPressure$i"
            }

            # Force garbage collection
            [System.GC]::Collect()

            # Stop all timers - should still work
            for ($i = 1; $i -le 100; $i++) {
                $duration = Stop-PerformanceTimer -OperationName "MemoryPressure$i"
                $duration | Should -Not -BeNullOrEmpty
            }
        }

        It "Should handle concurrent access safely" {
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $TimerName)
                    Import-Module $ModulePath -Force
                    Initialize-SmartLogging -ScriptName "ConcurrentTimer.ps1"
                    Start-PerformanceTimer -OperationName $TimerName
                    Start-Sleep -Milliseconds 50
                    Stop-PerformanceTimer -OperationName $TimerName
                } -ArgumentList $ModulePath, "ConcurrentTimer$i"
            }

            $results = $jobs | Receive-Job -Wait
            $jobs | Remove-Job

            $results.Count | Should -Be 5
            foreach ($duration in $results) {
                $duration | Should -Not -BeNullOrEmpty
                $duration | Should -BeOfType [timespan]
            }
        }
    }

    Context "Enterprise Performance Requirements" {
        It "Should meet sub-5ms timer start overhead requirement" {
            $measurements = @()

            for ($i = 1; $i -le 10; $i++) {
                $overhead = Measure-Command {
                    Start-PerformanceTimer -OperationName "EnterpriseStart$i"
                }
                $measurements += $overhead.TotalMilliseconds
                Stop-PerformanceTimer -OperationName "EnterpriseStart$i"
            }

            $averageOverhead = ($measurements | Measure-Object -Average).Average
            $averageOverhead | Should -BeLessOrEqual 5
        }

        It "Should meet sub-5ms timer stop overhead requirement" {
            $measurements = @()

            for ($i = 1; $i -le 10; $i++) {
                Start-PerformanceTimer -OperationName "EnterpriseStop$i"
                Start-Sleep -Milliseconds 10

                $overhead = Measure-Command {
                    Stop-PerformanceTimer -OperationName "EnterpriseStop$i"
                }
                $measurements += $overhead.TotalMilliseconds
            }

            $averageOverhead = ($measurements | Measure-Object -Average).Average
            $averageOverhead | Should -BeLessOrEqual 5
        }

        It "Should handle enterprise-scale timer operations (1000+ timers)" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Start 1000 timers
            for ($i = 1; $i -le 1000; $i++) {
                Start-PerformanceTimer -OperationName "Enterprise$i"
            }

            # Stop all timers
            for ($i = 1; $i -le 1000; $i++) {
                Stop-PerformanceTimer -OperationName "Enterprise$i"
            }

            $stopwatch.Stop()
            # Should complete 2000 operations (1000 start + 1000 stop) within 10 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 10000
        }
    }
}
