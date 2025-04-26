<# Shell Aliases #>

# Define an array of directories to add to the Path
$pathsToAdd = @(
    "C:\Program Files\OpenSSL-Win64\bin"
)

# Initialize a variable to hold the new paths
$newPaths = @()

# Loop through each path
foreach ($path in $pathsToAdd) {
    if (Test-Path -Path $path) {
        $newPaths += $path
    } else {
        Write-Host "Path does not exist: $path"
    }
}

# Append the valid paths to the current session's Path variable
if ($newPaths.Count -gt 0) {
    $env:Path += ";" + ($newPaths -join ";")

    # Persist the change for the current user
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $updatedPath = $currentPath + ";" + ($newPaths -join ";")
    [Environment]::SetEnvironmentVariable("Path", $updatedPath, [EnvironmentVariableTarget]::User)
} else {
    Write-Host "No valid paths were added."
}

@(
    @{
        Aliases = "jq";
        Command = "jq";
        DownloadURL = "https://jqlang.github.io/jq/download/"
    },
    @{
        Aliases = "openssl";
        Command = "openssl";
        DownloadURL = "https://slproweb.com/products/Win32OpenSSL.html"
    },
    @{
        Aliases = @("pico", "nano", "vi", "vs");
        Command = "code";
        DownloadURL = "https://code.visualstudio.com/docs/?dv=win64user"
    },
    @{
        Aliases = @("terraform", "tf");
        Command = "terraform";
        DownloadURL = "https://developer.hashicorp.com/terraform/install"
    }
) | ForEach-Object {
    # Access the Command property correctly
    $command = $_.Command
    $commandPath = Get-Command $command -ErrorAction SilentlyContinue
    if ($commandPath) {
        # Set aliases
        $aliasList = $_.Aliases -is [array] ? $_.Aliases : @($_.Aliases)
        foreach ($alias in $aliasList) {
            Set-Alias -Name $alias -Value $commandPath.Source -Scope Global
        }
        Write-Host "Aliases set for: $($aliasList -join ', ')" -ForegroundColor Green
    } elseif ($_.DownloadURL) {
        # Warn if the command is not found and suggest downloading
        $aliasNames = $_.Aliases -is [array] ? ($_.Aliases -join ", ") : $_.Aliases
        Write-Warning "Alias(es) '$aliasNames' not set. Command '$command' not found in PATH. To download, visit: $($_.DownloadURL)"
    }
}

function dockerps {
    docker ps --format "{{.ID}}|{{.Names}}|{{.CreatedAt}}|{{.Status}}|{{.Ports}}" | 
    ForEach-Object {
        $props = $_ -split "\|"
        [PSCustomObject]@{
            "CONTAINER ID" = $props[0]
            "NAMES"        = $props[1]
            "CREATED"      = $props[2]
            "STATUS"       = $props[3]
            "PORTS"        = $props[4]
        }
    } | Format-Table -AutoSize
}