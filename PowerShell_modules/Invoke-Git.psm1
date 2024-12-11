<#
.SYNOPSIS
Git helper functions for pulling, pushing, cloning, and managing repositories.

.DESCRIPTION
This script defines several Git helper functions:
- Invoke-GitPull: Performs a git pull and updates submodules if they exist.
- Invoke-GitPush: Stages all changes, commits with a user-provided message (or a timestamp), and pushes to the current branch.
- Show-GitDiff: Displays a diff of a selected commit against the current version of a file.
- Update-GitProjects: Updates all git repositories in a given directory.

.NOTES
- Requires Git to be installed and available in the system path.
- Uses the Invoke-Run function if available, otherwise falls back to Invoke-Expression.
#>

if (Get-Command git -ErrorAction SilentlyContinue) {

    function Invoke-GitPull {
        try {
            if (git rev-parse --is-inside-work-tree 2>$null) {
                $mainBranch = git rev-parse --abbrev-ref origin/HEAD | Split-Path -Leaf
                Write-Host "Pulling changes for branch: $mainBranch" -ForegroundColor Cyan

                @(
                    "git checkout $mainBranch",
                    "git pull --force origin $mainBranch --recurse-submodules=on-demand"
                ) | ForEach-Object { Invoke-Run -Commands $_ }

            } else {
                Write-Warning "Not in a git repository."
            }
        } catch {
            Write-Error "Failed to pull changes: $($_.Exception.Message)"
        }
    }

    function Invoke-GitPush {
        try {
            if (git rev-parse --is-inside-work-tree 2>$null) {
                $currentBranch = git rev-parse --abbrev-ref HEAD
                $commitMessage = Read-Host "Enter a commit message (press Enter to use timestamp)"

                if ([string]::IsNullOrWhiteSpace($commitMessage)) {
                    $commitMessage = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                }

                Write-Host "Committing and pushing changes to branch: $currentBranch" -ForegroundColor Cyan
                @(
                    "git status",
                    "git add --all",
                    "git commit -m `"$commitMessage`"",
                    "git push -u origin $currentBranch --recurse-submodules=on-demand"
                ) | ForEach-Object { Invoke-Run -Commands $_ }

            } else {
                Write-Warning "Not in a git repository."
            }
        } catch {
            Write-Error "Failed to push changes: $($_.Exception.Message)"
        }
    }

    function Show-GitDiff {
        param (
            [Parameter(Mandatory = $true, Position = 0)]
            [string]$FileName
        )

        try {
            $file = Resolve-Path $FileName
            $repoRoot = git -C (Split-Path $file) rev-parse --show-toplevel 2>$null

            if (-not $repoRoot) {
                Write-Warning "File '$(Split-Path -Leaf $file)' is not in a git repository."
                return
            }

            $gitLog = git log --pretty=format:"%h|%s|%an|%cr" -- $file
            $commits = $gitLog -split "`n" | ForEach-Object {
                $parts = $_ -split "\|"
                [PSCustomObject]@{
                    Hash = $parts[0]
                    Message = $parts[1]
                    User = $parts[2]
                    Ago = $parts[3]
                }
            }

            $selection = $commits | Out-GridView -Title "Select a commit - $file" -OutputMode Single
            if ($selection) {
                Invoke-Run -Commands "git -C `"$repoRoot`" difftool --no-prompt $($selection.Hash) `"$file`""
            } else {
                Write-Host "No commit selected."
            }
        } catch {
            Write-Error "Failed to perform git diff: $($_.Exception.Message)"
        }
    }

    function Update-GitProjects {
        try {
            $projectsPath = Join-Path $HOME "Projects"

            if (Test-Path $projectsPath) {
                Get-ChildItem $projectsPath -Directory | Where-Object {
                    Test-Path (Join-Path $_.FullName ".git")
                } | ForEach-Object {
                    $gitPath = $_.FullName
                    Write-Host "Updating repository: $gitPath" -ForegroundColor Cyan

                    $mainBranch = git -C "$gitPath" rev-parse --abbrev-ref origin/HEAD | Split-Path -Leaf
                    @(
                        "git -C `"$gitPath`" checkout $mainBranch",
                        "git -C `"$gitPath`" pull --force origin $mainBranch --recurse-submodules=on-demand"
                    ) | ForEach-Object { Invoke-Run -Commands $_ }

                    (Get-Item $gitPath).LastWriteTime = Get-Date
                }
            } else {
                Write-Warning "Projects folder not found at $projectsPath."
            }
        } catch {
            Write-Error "Failed to update projects: $($_.Exception.Message)"
        }
    }

} else {
    Write-Warning "Git is not available. Git helper functions will not be loaded."
}
