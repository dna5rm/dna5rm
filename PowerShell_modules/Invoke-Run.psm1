<#
.SYNOPSIS
Executes one or more commands, displaying each command before execution.

.DESCRIPTION
The Invoke-Run function takes one or more commands as input, displays each command
in green text, and then executes it. Optionally, the output can be piped through a formatting tool like 'ct'.

.PARAMETER Commands
One or more commands to execute. Each command is treated as a separate string.

.PARAMETER UseFormatter
If specified, pipes the output of each command through 'ct' (if available).

.PARAMETER DisplayVerbose
If specified, displays each command before execution.

.EXAMPLE
Invoke-Run -Commands "Get-Process", "Get-Service" -Verbose
Executes 'Get-Process' and 'Get-Service', displaying each command before execution.

.EXAMPLE
Invoke-Run -Commands "Get-Process" -UseFormatter
Executes 'Get-Process' and pipes the output through 'ct' if available.

.NOTES
This function is designed to provide clear visibility of commands being executed in scripts or interactive sessions.
#>

function Invoke-Run {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]]$Commands,

        [switch]$UseFormatter,

        [switch]$DisplayVerbose
    )

    if ($Commands.Count -eq 0) {
        Write-Host "No commands to execute..." -ForegroundColor Red
        return 1
    }

    foreach ($command in $Commands) {
        if ($DisplayVerbose.IsPresent) {
            Write-Host ">>> $command" -ForegroundColor Green
        }

        try {
            $result = Invoke-Expression $command

            if ($UseFormatter.IsPresent -and (Get-Command ct -ErrorAction SilentlyContinue)) {
                $result | ct
            } else {
                $result
            }
        } catch {
            Write-Warning "Error executing command '$command': $_"
        }
    }
}
