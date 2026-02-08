# Set ENV VARS & Determine Python version (major_minor_micro)
$Host.UI.RawUI.WindowTitle = "AI Toolkit"
$env:PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
$env:PYTHONWARNINGS = "ignore::DeprecationWarning,ignore::FutureWarning,ignore::UserWarning"
$pyVersionOutput = & python -c "import sys; v=sys.version_info; print(f'{v.major}_{v.minor}_{v.micro}')" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to determine Python version. Ensure 'python' is in PATH."
    exit 1
}
$pyVersion = $pyVersionOutput.Trim()

# Set Prompt
#function prompt {"PS: AI-Toolkit>"}

# Define the venv path
$venvDir = "D:\AI-Toolkit\venv"

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

cd D:\AI-Toolkit\ui
npm run build_and_start