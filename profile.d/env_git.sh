# Git Functions
if command -v git &> /dev/null; then

    # Pull to repo.
    function git_pull () {
        if [[ -n "$(git status 2> /dev/null)" ]]; then
            Run-Command "git pull"
            [[ -n "$(git submodule status)" ]] && {
                Run-Command "git pull --recurse-submodules"
                Run-Command "git submodule update --remote --merge"
                Run-Command "git submodule foreach git checkout master"
            }
        fi
    }

    # Push to repo.
    function git_push () {
        if [[ -n "$(git status 2> /dev/null)" ]]; then
            Run-Command "git status"
            Run-Command "git add --all"
            Run-Command "git commit -m \"$(date +%Y-%m-%d" "%H:%M:%S)\""
            Run-Command "git push -u origin $(awk '/^*/{print $NF}' <(git branch 2> /dev/null)) --recurse-submodules=on-demand"
            Run-Command "git submodule foreach git checkout master"
        fi
    }

    function git_diff ()
    {
        [[ "${0}" != -*"bash" ]] && {
            local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
        } || {
            local script="${FUNCNAME[0]}"
        }

        local test_cmds=( dialog git tput Run-Command )
        local test_result=()
        mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

        [[ "${#test_result[@]}" != 0 || ! -f "${1}" ]] && {
            echo "${script} - requirement failure!"
            [[ "${#test_result[@]}" != 0 ]] && {
                for missing in "${test_result[@]}"; do
                    echo "> command \"${missing}\" is missing."
                done
            }
            return 1
        } || {
            local file=$(readlink -f "${1}")
            local repo_root=$(git -C "$(dirname "${file}")" rev-parse --show-toplevel 2>/dev/null)

            [[ ! -d "${repo_root}" ]] && {
                echo "${script}: File \"$(basename ${file})\" is not in a git repository"
                return 1
            } || {
                local git_commit="$(dialog --stdout --title " Historical Diff " --menu "$(basename "${repo_root}"): ${file/${repo_root}/}" 20 0 18 --file <(awk -F'|' '{printf "%s \"%s\"\n", $1,$2}' <(git -C "${repo_root}" log --pretty=format:"%h|%s (%cr - %an)" -- "${file}")))"
                Run-Command "git -C \"${repo_root}\" diff --shortstat ${git_commit} \"${file}\""
                echo

                [[ "${2,,}" == *"vim"* ]] && {
                    Run-Command "git -C \"${repo_root}\" difftool --tool=vimdiff --no-prompt ${git_commit} \"${file}\"" 2> /dev/null
                } || {
                    Run-Command "git -C \"${repo_root}\" difftool --no-prompt --extcmd='diff -y' ${git_commit} \"${file}\""
                }
            }
        }
    }

    # Pull all project repos.
    function proj_pull ()
    {
        # Verify function requirements
        for req in git ssh-add; do
            type ${req} >/dev/null 2>&1 || {
                # Skip basename if shell function
                [[ "${0}" != "-bash" ]] && {
                    echo >&2 "$(basename "${0}"):${FUNCNAME[0]} - cmd/function \"${req}\" is required!"
                } || {
                    echo >&2 "${FUNCNAME[0]} - cmd/function \"${req}\" is required!"
                }
                return 1
            }
        done

        # This script is used to update all user projects.
        if  [[ -d "${HOME}/Projects" ]] && \
            [[ $(ssh-add -L) != "The agent has no identities." ]]; then
            _PWD="$(pwd)"
            # Pull all project directories.
            for repo in $(find "${HOME}/Projects/"* -maxdepth 0 -type d -not -path "*/venv*"); do
                [[ -d "${repo}/.git" ]] && {
                    echo "Updating $(basename ${repo})..."
                    Run-Command "git -C \"${repo}\" pull"
                    [[ -n "$(git -C "${repo}" submodule status)" ]] && {
                        Run-Command "git -C \"${repo}\" pull --recurse-submodules"
                        Run-Command "git -C \"${repo}\" submodule update --remote --merge"
                        Run-Command "git -C \"${repo}\" submodule foreach git checkout master"
                    }
                }
            done
            cd "${_PWD}" && unset _PWD
        else
            [[ ! -d "${HOME}/Projects" ]] && echo "Projects directory not found."
            [[ $(ssh-add -L) == "The agent has no identities." ]] && echo "No SSH key found."
        fi
    }

    # Status of all project repos.
    function proj_status ()
    {
        # Report unpushed changes to any project.
        for repo in $(find "${HOME}/Projects/"* -maxdepth 0 -type d -not -path "*/venv*"); do
            [[ -d "${repo}/.git" ]] && {
                cd "${repo}" && [[ ! $(git status --porcelain | wc -l) -eq "0" ]] && {
                    echo "Changes detected in $(basename ${repo})..."
                }
            }
        done
        cd "${HOME}"
    }

    # Export Functions
    export -f git_pull
    export -f git_push
fi
