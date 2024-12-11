<#
.SYNOPSIS
Updates all installed Python modules and ensures pip is upgraded to the latest version.

.DESCRIPTION
The Update-PipModules function automates the process of updating all installed Python modules.
It uses `pip freeze` to list all installed modules, excluding editable installations (marked with `-e`),
and upgrades each module individually. Additionally, it ensures that pip itself is upgraded to the latest version.

.NOTES
- Requires `pip` to be installed and available in the system PATH.
- Designed to work in environments where Python and pip are properly configured.

.EXAMPLE
Update-PipModules
Updates all installed Python modules and pip.
#>

function Update-PipModules {
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Upgrading pip..." -ForegroundColor Cyan
            python -m pip install --upgrade pip

            Write-Host "Updating installed Python modules..." -ForegroundColor Cyan
            pip freeze |
                Where-Object { $_ -notmatch '^-e' } |
                ForEach-Object {
                    $moduleName = $_.split('==')[0]
                    Write-Host "Upgrading module: $moduleName" -ForegroundColor Green
                    pip install --upgrade $moduleName
                }
        } catch {
            Write-Error "An error occurred while updating Python modules: $_"
        }
    } else {
        Write-Error "ERR: pip is not installed or not in the system PATH."
    }
}
