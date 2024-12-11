<#
.SYNOPSIS
Displays system information, similar to the Unix 'uname' command.

.DESCRIPTION
The Get-SystemInfo function provides basic system information by default,
including the operating system, version, build number, computer name, and architecture.
When used with the -All parameter, it runs the more comprehensive 'systeminfo' command.

.PARAMETER All
If specified, runs the 'systeminfo' command for comprehensive system details.

.EXAMPLE
Get-SystemInfo
Returns basic system information.

.EXAMPLE
Get-SystemInfo -All
Runs the 'systeminfo' command for detailed system information.

.NOTES
This function is designed to provide a quick overview of system information,
similar to the 'uname' command in Unix-like systems.
#>

function Get-SystemInfo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('a')]
        [switch]$All
    )

    if ($All) {
        systeminfo
    } else {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor
        $bios = Get-CimInstance Win32_BIOS
        $totalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB

        [PSCustomObject]@{
            OperatingSystem  = $os.Caption
            Version          = $os.Version
            BuildNumber      = $os.BuildNumber
            ComputerName     = $env:COMPUTERNAME
            Architecture     = $env:PROCESSOR_ARCHITECTURE
            Processor        = $cpu.Name
            BIOSVersion      = ($bios.SMBIOSBIOSVersion -join " ")
            TotalMemoryGB    = "{0:N2} GB" -f $totalMemory
            Uptime           = (Get-Date) - $os.LastBootUpTime
        }
    }
}
