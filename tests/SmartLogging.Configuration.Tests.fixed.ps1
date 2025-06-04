#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive Pester tests for SmartLogging Configuration Management functionality
.DESCRIPTION
    This test suite validates the configuration management components of SmartLogging.psm1,
    including LoggingConfig structure, environment detection, ContextForge integration,
    and helper functions for enterprise deployment scenarios.
.NOTES
    Created as part of ContextForge Phase 1.2 - Testing & Validation Enhancement
    Tests cover configuration validation, environment detection, and ContextForge integration
#>

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\src\src\core\SmartLogging.psm1"
    Import-Module $ModulePath -Force -ErrorAction Stop

    # Test data directory
    $TestDataPath = Join-Path -Path $PSScriptRoot -ChildPath "TestData"
    if (-not (Test-Path $TestDataPath)) {
        New-Item -Path $TestDataPath -ItemType Directory -Force | Out-Null
    }

    # Helper function to reset module state
    function Reset-SmartLoggingState {
        # Remove module and re-import to reset internal state
        Remove-Module SmartLogging -Force -ErrorAction SilentlyContinue
        Import-Module $ModulePath -Force
    }

    # Helper function to create test ContextForge configuration
    function New-TestContextForgeConfig {
        param(
            [hashtable]$Overrides = @{}
        )

        $BaseConfig = @{
            AppName         = "TestApp"
            Version         = "1.0.0"
            Environment     = "Test"
            InstanceId      = [guid]::NewGuid().ToString()
            DeploymentPhase = "Development"
            ToolName        = "Pester"
        }

        foreach ($key in $Overrides.Keys) {
            $BaseConfig[$key] = $Overrides[$key]
        }

        return $BaseConfig
    }
}

Describe "SmartLogging Configuration Management" -Tag "Configuration", "Core" {

    Context "LoggingConfig Structure Validation" {
        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should create a valid LoggingConfig structure" {
            # Act
            Initialize-SmartLogging -ScriptName "ConfigTest.ps1" -LogPath $TestDataPath

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value | Should -Not -BeNullOrEmpty
            $Config.Value.IsInitialized | Should -Be $true
            $Config.Value.ScriptName | Should -Be "ConfigTest.ps1"
            $Config.Value.LogPath | Should -Be $TestDataPath
        }

        It "Should enforce required configuration parameters" {
            # Act & Assert
            { Initialize-SmartLogging -ScriptName $null -LogPath $TestDataPath } | Should -Throw "*ScriptName*"
            { Initialize-SmartLogging -ScriptName "RequiredParamTest.ps1" -LogPath $null } | Should -Throw "*LogPath*"
        }

        It "Should default to appropriate values when optional parameters are not specified" {
            # Act
            Initialize-SmartLogging -ScriptName "DefaultsTest.ps1" -LogPath $TestDataPath

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.Environment | Should -Not -BeNullOrEmpty  # Should default to current environment
            $Config.Value.IsDebug | Should -Be $false  # Should default to non-debug
        }

        It "Should properly handle optional parameters when specified" {
            # Act
            Initialize-SmartLogging -ScriptName "OptionsTest.ps1" -LogPath $TestDataPath -Environment "UnitTest" -IsDebug $true

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.Environment | Should -Be "UnitTest"
            $Config.Value.IsDebug | Should -Be $true
        }
    }

    Context "Environment Detection" {
        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should automatically detect environment if not specified" {
            # Act
            Initialize-SmartLogging -ScriptName "EnvironmentTest.ps1" -LogPath $TestDataPath

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.Environment | Should -Not -BeNullOrEmpty
            $Config.Value.Environment.Length | Should -BeGreaterThan 0
        }

        It "Should respect explicitly set environment values" {
            # Act
            Initialize-SmartLogging -ScriptName "ExplicitEnvTest.ps1" -LogPath $TestDataPath -Environment "CustomEnvironment"

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.Environment | Should -Be "CustomEnvironment"
        }
    }

    Context "ContextForge Integration" {
        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should integrate with ContextForge configuration" {
            # Arrange
            $ContextForgeConfig = New-TestContextForgeConfig -Overrides @{
                AppName     = "ConfigTestApp"
                InstanceId  = "config-test-instance"
                Environment = "Testing"
            }

            # Act
            Initialize-SmartLogging -ScriptName "ContextForgeIntegrationTest.ps1" -LogPath $TestDataPath -ContextForgeConfig $ContextForgeConfig
            Write-SmartLog -Message "ContextForge integration test" -Level Info `
                -InstanceId $ContextForgeConfig.InstanceId `
                -DeploymentPhase $ContextForgeConfig.DeploymentPhase

            # Assert - Verify log file contains ContextForge data
            $LogFiles = Get-ChildItem -Path $TestDataPath -Filter "*.log" | Sort-Object CreationTime -Descending
            $LogFiles | Should -Not -BeNullOrEmpty

            $LogContent = Get-Content -Path $LogFiles[0].FullName -Raw
            $LogContent | Should -Match "ConfigTestApp"
            $LogContent | Should -Match "config-test-instance"
            $LogContent | Should -Match "Testing"
        }

        It "Should validate ContextForge configuration structure" {
            # Arrange
            $InvalidConfig = @{
                # Missing required fields
                SomeRandomField = "value"
            }

            # Act & Assert
            { Initialize-SmartLogging -ScriptName "InvalidContextForgeTest.ps1" -LogPath $TestDataPath -ContextForgeConfig $InvalidConfig } |
            Should -Not -Throw  # Should be resilient to invalid configs
        }
    }

    Context "Helper Functions" {

        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should provide Get-OrElse functionality for configuration fallbacks" {
            # This test assumes Get-OrElse is available in the module
            # If it's internal, we test indirectly through configuration behavior

            # Arrange
            Initialize-SmartLogging -ScriptName "GetOrElseTest.ps1" -LogPath $TestDataPath

            # Act - Test with missing configuration value
            $Result = Write-SmartLog -Message "Test fallback behavior" -Level Info

            # Assert - Should complete without errors (fallback working)
            $Result | Should -Not -BeNullOrEmpty
        }

        It "Should handle configuration value expansion" {
            # Arrange
            $ConfigWithVariables = New-TestContextForgeConfig -Overrides @{
                LogPath = "%TEMP%\SmartLogging"
                AppName = "TestApp"
            }

            # Act
            Initialize-SmartLogging -ScriptName "ConfigExpansionTest.ps1" -LogPath $TestDataPath -ContextForgeConfig $ConfigWithVariables

            # Assert - Environment variables should be expanded
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.LogPath | Should -Not -Match "%"
        }

        It "Should provide safe configuration access patterns" {
            # Arrange
            Initialize-SmartLogging -ScriptName "SafeConfigTest.ps1" -LogPath $TestDataPath

            # Act - Access non-existent configuration value safely
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue

            # Assert - Should not throw when accessing non-existent keys
            { $Config.Value.NonExistentKey } | Should -Not -Throw
        }
    }

    Context "Configuration Performance" {

        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should initialize configuration within performance threshold" {
            # Arrange
            $MaxInitTime = 100  # milliseconds

            # Act
            $InitTime = Measure-Command {
                Initialize-SmartLogging -ScriptName "PerformanceTest.ps1" -LogPath $TestDataPath
            }

            # Assert
            $InitTime.TotalMilliseconds | Should -BeLessThan $MaxInitTime
        }

        It "Should provide fast configuration access" {
            # Arrange
            Initialize-SmartLogging -ScriptName "FastAccessTest.ps1" -LogPath $TestDataPath
            $MaxAccessTime = 10  # milliseconds

            # Act
            $AccessTime = Measure-Command {
                1..100 | ForEach-Object {
                    $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
                    $Value = $Config.Value.ScriptName
                }
            }

            # Assert - Average time per access should be under threshold
            $AvgAccessTime = $AccessTime.TotalMilliseconds / 100
            $AvgAccessTime | Should -BeLessThan $MaxAccessTime
        }

        It "Should be thread-safe for configuration access" {
            # Arrange
            Initialize-SmartLogging -ScriptName "ThreadSafeTest.ps1" -LogPath $TestDataPath
            $JobCount = 5

            # Act - Access from multiple runspaces
            $Jobs = 1..$JobCount | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($ModulePath, $TestDataPath, $JobId)

                    Import-Module $ModulePath -Force
                    # Attempt concurrent configuration access
                    Initialize-SmartLogging -ScriptName "ConcurrentTest_$JobId.ps1" -LogPath $TestDataPath
                    Write-SmartLog -Message "Thread safety test from job $JobId" -Level Info
                } -ArgumentList $ModulePath, $TestDataPath, $_
            }

            # Wait for jobs to complete
            $Jobs | Wait-Job | Receive-Job
            $Jobs | Remove-Job

            # Assert - Configuration should remain intact
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.IsInitialized | Should -Be $true
        }
    }

    Context "Configuration Resilience" {

        BeforeEach {
            Reset-SmartLoggingState
        }

        It "Should allow re-initialization with -Force parameter" {
            # Act
            Initialize-SmartLogging -ScriptName "InitialConfig.ps1" -LogPath $TestDataPath
            { Initialize-SmartLogging -ScriptName "ReInitTest.ps1" -LogPath $TestDataPath -Force } | Should -Not -Throw

            # Assert
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.ScriptName | Should -Be "ReInitTest.ps1"
        }

        It "Should recover from corrupt configuration state" {
            # Arrange
            Initialize-SmartLogging -ScriptName "CorruptTest.ps1" -LogPath $TestDataPath

            # Act - Simulate configuration corruption by directly manipulating
            $Config = Get-Variable -Name "LoggingConfig" -Scope Script -ErrorAction SilentlyContinue
            $Config.Value.IsInitialized = $null  # Corrupt the configuration

            # Assert - Should be able to re-initialize
            { Initialize-SmartLogging -ScriptName "CorruptionTest.ps1" -LogPath $TestDataPath -Force } | Should -Not -Throw
        }

        It "Should validate configuration parameter types" {
            # Act & Assert - Should handle type mismatches gracefully
            { Initialize-SmartLogging -ScriptName "TypeValidationTest1.ps1" -LogPath $TestDataPath -Environment 123 } | Should -Not -Throw
            { Initialize-SmartLogging -ScriptName "TypeValidationTest2.ps1" -LogPath $TestDataPath -ContextForgeConfig "not a hashtable" } | Should -Not -Throw
        }
    }

    AfterAll {
        # Cleanup test data
        if (Test-Path $TestDataPath) {
            Get-ChildItem -Path $TestDataPath -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -Path $TestDataPath -Force -ErrorAction SilentlyContinue
        }

        # Reset module state
        Remove-Module SmartLogging -Force -ErrorAction SilentlyContinue
    }
}
