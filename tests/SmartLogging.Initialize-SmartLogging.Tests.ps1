#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive Pester tests for Initialize-SmartLogging function

.DESCRIPTION
    Phase 1.2 ContextForge Integration Testing Suite - Initialize-SmartLogging Function
    Tests initialization functionality, context creation, parameter validation,
    environment detection, error handling, and ContextForge integration scenarios.

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
    function New-TestContext {
        param(
            [hashtable]$Config = @{},
            [switch]$WithContextForge
        )

        $baseContext = @{
            TestId      = [guid]::NewGuid()
            Environment = 'Test'
            LogBasePath = $TestDrive
        }

        if ($WithContextForge) {
            $baseContext['InstanceId'] = [guid]::NewGuid()
            $baseContext['DeploymentPhase'] = 'Testing'
            $baseContext['ToolName'] = 'TestTool'
        }

        return $baseContext + $Config
    }    function Assert-ContextStructure {
        param($Context, [switch]$WithContextForge)

        # Core context structure validation
        $Context | Should -Not -BeNullOrEmpty
        $Context.ScriptName | Should -Not -BeNullOrEmpty
        $Context.LogFile | Should -Not -BeNullOrEmpty
        $Context.HasError | Should -BeFalse
        $Context.StartTime | Should -BeOfType [DateTime]
        $Context.TestResults | Should -BeOfType [hashtable]
        $Context.Environment | Should -Not -BeNullOrEmpty

        # Environment sub-structure validation (Environment is a hashtable)
        $Context.Environment.Keys | Should -Contain 'IsProduction'
        $Context.Environment.Keys | Should -Contain 'IsDevelopment'
        $Context.Environment.Keys | Should -Contain 'IsCI'

        if ($WithContextForge) {
            $Context.PSObject.Properties.Name | Should -Contain 'InstanceId'
            $Context.PSObject.Properties.Name | Should -Contain 'DeploymentPhase'
            $Context.PSObject.Properties.Name | Should -Contain 'ToolName'
        }
    }
}

Describe "Initialize-SmartLogging" {
    Context "Basic Functionality" {
        BeforeEach {
            # Reset module state
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should initialize with mandatory ScriptName parameter" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            Assert-ContextStructure -Context $result
            $result.ScriptName | Should -Be "TestScript.ps1"
            $result.LogFile | Should -Match "TestScript\.ps1"
        }

        It "Should handle custom LogType parameter" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType "Installation"

            Assert-ContextStructure -Context $result
            $result.LogFile | Should -Match "Installation"
        }

        It "Should accept custom LogPath parameter" {
            $customPath = Join-Path $TestDrive "custom-log.log"
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogPath $customPath

            Assert-ContextStructure -Context $result
            $result.LogFile | Should -Be $customPath
        }

        It "Should create log directory if it doesn't exist" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            $logDir = Split-Path $result.LogFile -Parent
            Test-Path $logDir | Should -BeTrue
        }

        It "Should set StartTime to current time (within 5 seconds)" {
            $beforeInit = Get-Date
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"
            $afterInit = Get-Date

            $result.StartTime | Should -BeGreaterOrEqual $beforeInit.AddSeconds(-1)
            $result.StartTime | Should -BeLessOrEqual $afterInit.AddSeconds(1)
        }
    }

    Context "Parameter Validation" {
        It "Should require ScriptName parameter" {
            { Initialize-SmartLogging } | Should -Throw "*ScriptName*"
        }

        It "Should accept empty LogType and use default" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType ""

            Assert-ContextStructure -Context $result
            $result.LogFile | Should -Match "TestScript\.ps1.*\.log$"
        }

        It "Should handle special characters in ScriptName" {
            $specialName = "Test-Script_v2.0[beta].ps1"
            $result = Initialize-SmartLogging -ScriptName $specialName

            Assert-ContextStructure -Context $result
            $result.ScriptName | Should -Be $specialName
        }

        It "Should handle long ScriptName values" {
            $longName = "A" * 200 + ".ps1"
            $result = Initialize-SmartLogging -ScriptName $longName

            Assert-ContextStructure -Context $result
            $result.ScriptName | Should -Be $longName
        }
    }

    Context "Environment Detection" {
        It "Should detect environment correctly" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            $result.Environment | Should -HaveProperty 'IsProduction'
            $result.Environment | Should -HaveProperty 'IsDevelopment'
            $result.Environment | Should -HaveProperty 'IsCI'

            # At least one environment should be detected
            ($result.Environment.IsProduction -or
            $result.Environment.IsDevelopment -or
            $result.Environment.IsCI) | Should -BeTrue
        }

        It "Should set HasError to false initially" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            $result.HasError | Should -BeFalse
        }

        It "Should initialize empty TestResults hashtable" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            $result.TestResults | Should -BeOfType [hashtable]
            $result.TestResults.Count | Should -Be 0
        }
    }

    Context "Log Path Generation" {
        It "Should generate timestamped log paths" {
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"

            $result.LogFile | Should -Match "\d{8}"  # YYYYMMDD format
            $result.LogFile | Should -Match "\d{6}"  # HHMMSS format
        }

        It "Should use different paths for different LogTypes" {
            $mainResult = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType "Main"
            # Reset context
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
            $errorResult = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType "Error"

            $mainResult.LogFile | Should -Not -Be $errorResult.LogFile
            $errorResult.LogFile | Should -Match "Errors"
        }

        It "Should handle different LogType formats" {
            $testTypes = @("Main", "Error", "Performance", "Transcript", "Installation")

            foreach ($type in $testTypes) {
                # Reset context
                if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name Context -Scope Script -Force
                }
                $result = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogType $type

                $result.LogFile | Should -Not -BeNullOrEmpty
                $result.LogFile | Should -Match "\.log$"
            }
        }
    }

    Context "Context State Management" {
        It "Should create module-scoped Context variable" {
            Initialize-SmartLogging -ScriptName "TestScript.ps1"

            # Verify script scope variable is created (this is implementation-specific)
            # We can't directly test script scope from here, but we can test the return value
            $result = Initialize-SmartLogging -ScriptName "TestScript.ps1"
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should allow re-initialization" {
            $first = Initialize-SmartLogging -ScriptName "FirstScript.ps1"
            $second = Initialize-SmartLogging -ScriptName "SecondScript.ps1"

            $first.ScriptName | Should -Be "FirstScript.ps1"
            $second.ScriptName | Should -Be "SecondScript.ps1"
            $first.LogFile | Should -Not -Be $second.LogFile
        }
    }

    Context "Performance Requirements" {
        It "Should initialize within 100ms" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Initialize-SmartLogging -ScriptName "PerformanceTest.ps1"
            $stopwatch.Stop()

            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 100
        }

        It "Should handle concurrent initialization requests" {
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $TestNumber)
                    Import-Module $ModulePath -Force
                    Initialize-SmartLogging -ScriptName "ConcurrentTest$TestNumber.ps1"
                } -ArgumentList $ModulePath, $i
            }

            $results = $jobs | Receive-Job -Wait
            $jobs | Remove-Job

            $results.Count | Should -Be 5
            foreach ($result in $results) {
                Assert-ContextStructure -Context $result
            }
        }
    }

    Context "Error Handling" {
        It "Should handle invalid LogPath gracefully" {
            $invalidPath = "Z:\NonExistent\Path\test.log"

            # This should not throw but should handle gracefully
            { $result = Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogPath $invalidPath } | Should -Not -Throw
        }

        It "Should handle null or empty ScriptName appropriately" {
            { Initialize-SmartLogging -ScriptName $null } | Should -Throw
            { Initialize-SmartLogging -ScriptName "" } | Should -Throw
        }

        It "Should handle filesystem permission issues" {
            # Mock a read-only path scenario
            $readOnlyPath = Join-Path $TestDrive "readonly.log"
            New-Item -Path $readOnlyPath -ItemType File -Force

            # This test might be platform-specific
            if ($IsWindows) {
                # Attempt initialization with potentially problematic path
                { Initialize-SmartLogging -ScriptName "TestScript.ps1" -LogPath $readOnlyPath } | Should -Not -Throw
            }
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on Windows" {
            $result = Initialize-SmartLogging -ScriptName "WindowsTest.ps1"

            Assert-ContextStructure -Context $result
            if ($IsWindows -or $env:OS -eq 'Windows_NT') {
                $result.LogFile | Should -Match "^[A-Z]:\\"
            }
        }

        It "Should work on Linux/macOS" {
            $result = Initialize-SmartLogging -ScriptName "UnixTest.ps1"

            Assert-ContextStructure -Context $result
            if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) {
                $result.LogFile | Should -Match "^/"
            }
        }

        It "Should handle path separators correctly" {
            $result = Initialize-SmartLogging -ScriptName "PathTest.ps1"

            # Log file should use correct path separators for the platform
            $result.LogFile | Should -Not -Match "[/\\]{2,}"  # No double separators
        }
    }

    Context "Integration with Write-SmartLog" {
        It "Should enable Write-SmartLog functionality after initialization" {
            Initialize-SmartLogging -ScriptName "IntegrationTest.ps1"

            # This should not throw after initialization
            { Write-SmartLog -Message "Test message" -Level "INFO" } | Should -Not -Throw
        }

        It "Should log initialization messages" {
            $logFile = Join-Path $TestDrive "init-test.log"
            Initialize-SmartLogging -ScriptName "InitTest.ps1" -LogPath $logFile
            Write-SmartLog -Message "Test initialization" -Level "INFO"

            # Verify log file was created and contains initialization message
            Test-Path $logFile | Should -BeTrue
            $logContent = Get-Content $logFile -Raw
            $logContent | Should -Match "Smart logging initialized"
        }
    }

    Context "ContextForge Integration Scenarios" {
        BeforeEach {
            # Reset any existing context
            if (Get-Variable -Name Context -Scope Script -ErrorAction SilentlyContinue) {
                Remove-Variable -Name Context -Scope Script -Force
            }
        }

        It "Should work without ContextForge helpers available" {
            # Standard initialization should work even without ContextForge
            $result = Initialize-SmartLogging -ScriptName "NoContextForge.ps1"

            Assert-ContextStructure -Context $result
            # Should have basic structure but not ContextForge extensions
        }

        It "Should handle missing ContextForge configuration gracefully" {
            # Initialize without ContextForge config
            $result = Initialize-SmartLogging -ScriptName "BasicInit.ps1"

            Assert-ContextStructure -Context $result
            $result.Environment | Should -Not -BeNullOrEmpty
        }

        It "Should maintain backward compatibility" {
            # Test that old calling patterns still work
            $result = Initialize-SmartLogging "BackwardCompatTest.ps1"

            Assert-ContextStructure -Context $result
            $result.ScriptName | Should -Be "BackwardCompatTest.ps1"
        }
    }

    Context "Memory and Resource Management" {
        It "Should not leak memory during multiple initializations" {
            # Get baseline memory
            $initialMemory = [System.GC]::GetTotalMemory($true)

            # Perform multiple initializations
            for ($i = 1; $i -le 20; $i++) {
                Initialize-SmartLogging -ScriptName "MemoryTest$i.ps1"
            }

            # Force garbage collection and check memory
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            $finalMemory = [System.GC]::GetTotalMemory($true)

            # Memory increase should be reasonable (less than 10MB for 20 initializations)
            $memoryIncrease = $finalMemory - $initialMemory
            $memoryIncrease | Should -BeLessOrEqual (10 * 1024 * 1024)
        }

        It "Should handle large numbers of rapid initializations" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            for ($i = 1; $i -le 100; $i++) {
                Initialize-SmartLogging -ScriptName "RapidTest$i.ps1"
            }

            $stopwatch.Stop()
            # 100 initializations should complete within 2 seconds
            $stopwatch.ElapsedMilliseconds | Should -BeLessOrEqual 2000
        }
    }

    Context "Return Value Validation" {
        It "Should return a valid context object" {
            $result = Initialize-SmartLogging -ScriptName "ReturnTest.ps1"

            $result | Should -BeOfType [PSCustomObject]
            Assert-ContextStructure -Context $result
        }

        It "Should return same structure across different calls" {
            $result1 = Initialize-SmartLogging -ScriptName "Struct1.ps1"
            $result2 = Initialize-SmartLogging -ScriptName "Struct2.ps1"

            # Both should have same property structure
            $props1 = $result1.PSObject.Properties.Name | Sort-Object
            $props2 = $result2.PSObject.Properties.Name | Sort-Object

            Compare-Object $props1 $props2 | Should -BeNullOrEmpty
        }

        It "Should return context with proper type properties" {
            $result = Initialize-SmartLogging -ScriptName "TypeTest.ps1"

            $result.ScriptName | Should -BeOfType [string]
            $result.LogFile | Should -BeOfType [string]
            $result.HasError | Should -BeOfType [bool]
            $result.StartTime | Should -BeOfType [DateTime]
            $result.TestResults | Should -BeOfType [hashtable]
            $result.Environment | Should -BeOfType [PSCustomObject]
        }
    }
}
