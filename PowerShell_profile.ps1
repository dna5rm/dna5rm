<# $PROFILE - Startup script for PowerShell environment #>

# Determine the script directory
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ensure the script directory path is valid
if ($ScriptPath -ne $null -and (Test-Path -Path $ScriptPath)) {
    # Gather all files to load
    $files = @(
        "$ScriptPath\PowerShell_env.ps1",
        "$ScriptPath\PowerShell_aliases.ps1"
    )

    # Loop through each file
    foreach ($file in $files) {
        if (Test-Path -Path $file -PathType Leaf) {
            # Check if we're in interactive mode
            if ($Host.Name -eq 'ConsoleHost') {
                # Source the file normally in interactive mode
                . $file
                Write-Host "Loaded: $file" -ForegroundColor Green
            } else {
                # Source the file in non-interactive mode, redirecting output to null
                . $file > $null
            }
        } else {
            Write-Warning "File not found: $file"
        }
    }
} else {
    Write-Warning "Script directory not found or invalid: $ScriptPath"
}

# Define path for custom modules relative to the script directory
$CustomModulesPath = Join-Path $ScriptPath "PowerShell_modules"

# Ensure the directory exists
if (-not (Test-Path $CustomModulesPath)) {
    New-Item -ItemType Directory -Path $CustomModulesPath -Force | Out-Null
}

# Add custom modules directory to PSModulePath
if (-not ($env:PSModulePath -split ';' -contains $CustomModulesPath)) {
    $env:PSModulePath += ";$CustomModulesPath"
}

# Import all modules and scripts in the custom modules directory
Get-ChildItem -Path $CustomModulesPath -Recurse -File | ForEach-Object {
    try {
        if ($_.Extension -eq ".psm1") {
            Import-Module $_.FullName -ErrorAction Stop
            Write-Host "Loaded module: $($_.Name)" -ForegroundColor Green
        } elseif ($_.Extension -eq ".ps1") {
            . $_.FullName
            Write-Host "Loaded script: $($_.Name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to load module or script at $($_.FullName): $($_.Exception.Message)"
    }
}

# Ensure ssh-agent service is running
if (-not (Get-Service ssh-agent -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"})) {
    try {
        Start-Service ssh-agent
        Write-Host "ssh-agent service started." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to start ssh-agent service: $($_.Exception.Message)"
    }
}

# Add SSH key
try {
        $keyPath = Join-Path $env:USERPROFILE ".ssh\id_rsa"

        if (Test-Path $keyPath) {
            $sshAddCommand = "ssh-add $keyPath"
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c echo $passphrase | $sshAddCommand" -NoNewWindow -Wait -PassThru

            if ($process.ExitCode -eq 0) {
                Write-Host "SSH key added successfully." -ForegroundColor Green
            } else {
                Write-Warning "Failed to add SSH key. Check the passphrase or key configuration."
            }
        } else {
            Write-Warning "SSH key file not found: $keyPath"
        }
} catch {
    Write-Warning "Failed to add SSH key: $($_.Exception.Message)"
}

# Network-dependent setup: Only perform updates if connected to a network
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface }
if ($activeAdapters) {
    # Update Script Repository
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            if (Test-Path "$ScriptPath\.git") {
                $mainBranch = git -C "$ScriptPath" rev-parse --abbrev-ref origin/HEAD | Split-Path -Leaf
                git -C "$ScriptPath" checkout $mainBranch
                git -C "$ScriptPath" pull --force origin $mainBranch --recurse-submodules=on-demand
                Write-Host "Script repository updated." -ForegroundColor Green
            } else {
                Write-Host "$ScriptPath is not a git repository. Skipping update." -ForegroundColor Yellow
            }
        } catch {
            Write-Warning ("Failed to update script repository: {0}" -f $_.Exception.Message)
        }
    } else {
        Write-Warning "Git is not installed or available. Skipping repository updates."
    }
} else {
    Write-Warning "No active network adapters detected. Skipping network-dependent operations."
}

# Final message
Write-Host "PowerShell script loaded successfully." -ForegroundColor Green
