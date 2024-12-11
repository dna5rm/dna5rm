<#
.SYNOPSIS
Displays system environment variables.

.DESCRIPTION
The Get-EnvInfo function lists all system environment variables and their values.
It provides options to filter variables by name and to display values in a list format.

.PARAMETER Filter
Optional. A string to filter environment variable names. Supports wildcards.

.PARAMETER AsList
Switch parameter. If used, displays output in a list format instead of a table.

.EXAMPLE
Get-EnvInfo
Displays all environment variables in a table format.

.EXAMPLE
Get-EnvInfo -Filter "*PATH*"
Displays environment variables with "PATH" in their name.

.EXAMPLE
Get-EnvInfo -AsList
Displays all environment variables in a list format.

.NOTES
This function is useful for quickly inspecting system environment variables.
#>

function Get-EnvInfo {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$Filter = "*",

        [Parameter()]
        [switch]$AsList
    )

    $envVars = Get-ChildItem Env: | Where-Object { $_.Name -like $Filter }

    if (-not $envVars) {
        Write-Warning "No environment variables match the filter: '$Filter'"
        return
    }

    $envVars = $envVars | Sort-Object Name

    if ($AsList) {
        $envVars | Format-List Name, Value
    } else {
        $envVars | Format-Table Name, Value -AutoSize -Wrap
    }
}