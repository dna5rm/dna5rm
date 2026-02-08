# Set ENV VARS & Determine Python version (major_minor_micro)
$Host.UI.RawUI.WindowTitle = "ComfyUI"
$pyVersionOutput = & python -c "import sys; v=sys.version_info; print(f'{v.major}_{v.minor}_{v.micro}')" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to determine Python version. Ensure 'python' is in PATH."
    exit 1
}
$pyVersion = $pyVersionOutput.Trim()

# Set Prompt
#function prompt {"PS: ComfyUI>"}

# Define the venv path
#$venvRoot = "D:\" # Join-Path $env:USERPROFILE ".local"
#$venvDir = Join-Path $venvRoot ("venv" + $pyVersion)
$venvDir = "D:\ComfyUI\venv"

# Create or load the venv
if (Test-Path $venvDir) {
    Write-Host "Loading Python virtual environment: $venvDir"
} else {
    Write-Host "Building Python virtual environment: $venvDir"
    New-Item -ItemType Directory -Path $venvDir -Force | Out-Null
    & python -m venv $venvDir
}

# Activate the venv
$activateScript = Join-Path $venvDir "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    $oldPolicy = Get-ExecutionPolicy
    if ($oldPolicy -ne "RemoteSigned" -and $oldPolicy -ne "Unrestricted") {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    }
    Write-Host "Activating virtual environment..."
    . $activateScript
} else {
    Write-Error "Activation script not found: $activateScript"
    exit 1
}

# Run comfy UI
$mainScript = "D:\ComfyUI\main.py"
$pythonExe = Join-Path $venvDir "Scripts\python.exe"

if (Test-Path $pythonExe) {
    $cudaAvailableRaw = & $pythonExe -c "import torch; print(torch.cuda.is_available())" 2>$null
    $cudaAvailable = $cudaAvailableRaw.Trim() -eq "True"

    if ($cudaAvailable) {
        # CUDA is available: run full GPU version
        Write-Host "CUDA detected. Launching comfy UI with CUDA."
        & $pythonExe -W ignore::DeprecationWarning -s $mainScript --windows-standalone-build --preview-method latent2rgb --listen 0.0.0.0 --port 8188
    } else {
        # CUDA not available: run CPU-only version
        Write-Host "CUDA not available."
    }

} else {
    Write-Error "Python not found in venv: $pythonExe"
    exit 1
}

Read-Host -Prompt "Press Enter to exit"