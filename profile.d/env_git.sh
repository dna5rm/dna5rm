# Git Functions
if command -v git &> /dev/null; then

    # Push to repo.
    function git_push () {
        if [[ -n "$(git status 2> /dev/null)" ]]; then
            Run-Command "git status"
            Run-Command "git add --all"
            Run-Command "git commit -m \"$(date +%Y-%m-%d" "%H:%M:%S)\""
            Run-Command "git push -u origin $(awk '/^*/{print $NF}' <(git branch 2> /dev/null))"
        fi
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

fi
