# Git helpers. Login is a no-op besides defining functions.

if command -v git >/dev/null 2>&1; then

    function git_pull () {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
        Run-Command "git pull"
        [[ -n "$(git submodule status 2>/dev/null)" ]] && {
            Run-Command "git pull --recurse-submodules"
            Run-Command "git submodule update --init --recursive"
        }
    }

    # git_push "commit message" — no timestamp dumps, no git add --all.
    function git_push () {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
        [[ -n "${1}" ]] || { echo "usage: git_push \"message\"" >&2; return 1; }
        Run-Command "git status"
        Run-Command "git commit -am $(printf '%q' "${1}")"
        local br
        br="$(git branch --show-current)"
        Run-Command "git push -u origin ${br} --recurse-submodules=on-demand"
    }

    function git_diff () {
        [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
        local test_cmds=( dialog git tput vimdiff Run-Command ) missing="" i
        for i in "${test_cmds[@]}"; do command -v "${i}" >/dev/null 2>&1 || missing+="${i} "; done
        [[ -z "${missing}" && -f "${1}" ]] || {
            echo "${script} - requirement failure!"
            [[ -n "${missing}" ]] && echo "> missing: ${missing}"
            return 1
        }
        local file repo_root git_commit
        file=$(readlink -f "${1}")
        repo_root=$(git -C "$(dirname "${file}")" rev-parse --show-toplevel 2>/dev/null)
        [[ -d "${repo_root}" ]] || { echo "${script}: not in a git repo"; return 1; }
        git_commit="$(dialog --stdout --backtitle "${script}" --title " Historical Diff " --menu "$(basename "${repo_root}"): ${file/${repo_root}/}" 20 0 18 --file <(awk -F'|' '{printf "%s \"%s\"\n", $1,$2}' <(git -C "${repo_root}" log --pretty=format:"%h|%s (%cr - %an)" -- "${file}")))"
        [[ -n "${git_commit}" ]] || return 0
        Run-Command "git -C \"${repo_root}\" diff --shortstat ${git_commit} \"${file}\""
        echo
        if [[ "${2,,}" == *vim* ]]; then
            Run-Command "git -C \"${repo_root}\" difftool --tool=vimdiff --no-prompt ${git_commit} \"${file}\"" 2>/dev/null
        else
            Run-Command "git -C \"${repo_root}\" difftool --no-prompt --extcmd='diff -y' ${git_commit} \"${file}\""
        fi
    }

    function proj_pull () {
        type git >/dev/null 2>&1 || return 1
        [[ -d "${HOME}/Projects" ]] || { echo "Projects directory not found."; return 1; }
        local repo
        for repo in "${HOME}/Projects/"*; do
            [[ -d "${repo}/.git" ]] || continue
            echo "Updating $(basename "${repo}")..."
            Run-Command "git -C \"${repo}\" pull"
            [[ -n "$(git -C "${repo}" submodule status 2>/dev/null)" ]] && {
                Run-Command "git -C \"${repo}\" pull --recurse-submodules"
                Run-Command "git -C \"${repo}\" submodule update --init --recursive"
            }
        done
    }

    function proj_status () {
        local repo
        for repo in "${HOME}/Projects/"*; do
            [[ -d "${repo}/.git" ]] || continue
            [[ -n "$(git -C "${repo}" status --porcelain 2>/dev/null)" ]] && echo "Changes detected in $(basename "${repo}")..."
        done
    }

    export -f git_pull git_push git_diff proj_pull proj_status
fi
