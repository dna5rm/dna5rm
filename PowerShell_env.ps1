<# Environmental and Shell Variables #>

# # Python 3.10
# $pythonPaths = @(
#     "$env:LOCALAPPDATA\Programs\Python\Python310",
#     "$env:LOCALAPPDATA\Programs\Python\Python310\Scripts",
#     "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
#     "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe\Scripts"
# )

# foreach ($path in $pythonPaths) {
#     if ($env:Path -notlike "*$path*") {
#         $env:Path += ";$path"
#     }
# }

# Oh My Posh
$ohMyPoshPath = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
if (Test-Path $ohMyPoshPath) {
    # Add Oh My Posh to the PATH if it's not already there
    if ($env:Path -notlike "*$ohMyPoshPath*") {
        $env:Path += ";$ohMyPoshPath"
    }

    # Initialize Oh My Posh with the specified theme
    $themeFile = "$ScriptPath\.omp.json"
    if (Test-Path $themeFile) {
        try {
            oh-my-posh init pwsh --config $themeFile | Invoke-Expression
        }
        catch {
            Write-Warning "Failed to initialize Oh My Posh: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Oh My Posh theme file not found at: $themeFile"
    }
} else {
    Write-Warning "Oh My Posh binary not found at: $ohMyPoshPath"
}
