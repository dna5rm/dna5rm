# Do nothing if non-interactive!
[[ $- != *i* ]] && { return; }

# Set the default shell options.
export RCPATH="$(dirname $(readlink -f "${HOME}/.bashrc"))"
readonly TMOUT=900

# Create a user tmp directory.
if [[ -z "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    readonly TMPDIR="$(mktemp -d)"
    export TMPDIR
elif [[ ! -z "${TMPDIR}" ]] && [[ ! -d "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    mkdir -m 700 -p "${TMPDIR}"
fi && echo -e "Temp Directory: ${TMPDIR}\n"

# Update the PATH variable.
for p in bin .local/bin .local/opt go/bin .cargo/bin; do
    [[ -d "${HOME}/${p}" ]] && { PATH="${HOME}/${p}":${PATH}; }
done

# Setup user shell environment.
[[ -d "${RCPATH}/profile.d" ]] && {
    # Load profile.d scripts.
    for i in ${RCPATH}/profile.d/*.sh ${RCPATH}/.aliases ${RCPATH}/.env; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done

    # Generate or display a SSH private key if missing.
    [[ ! -f "${HOME}/.ssh/id_rsa" ]] && {
        Run-Command "ssh-keygen -t rsa -b 4096 -N \"\" -C \"${USER:-$(whoami)}@$(domainname -y 2> /dev/null || echo "(none)")\" -f \"${HOME}/.ssh/id_rsa\""
    } || {
        Run-Command "ssh-keygen -lvf \"${HOME}/.ssh/id_rsa\""
    }; echo

    # Load ssh key fingerprint as ssh_hash.
    type Get-SshKeyFingerprint >/dev/null 2>&1 && {
        export ssh_hash=( `Get-SshKeyFingerprint` )
        [[ -z "${USER}" ]] && {
            # Set $USER if not already set.
            export USER="${ssh_hash[1]%@*}"
        }
    }

    # Load ssh key into ssh-agent if ssh_hash is set.
    [[ -n "${ssh_hash[*]}" ]] && {
        eval $(ssh-agent) && {
            timeout 1s ssh-add -k "${HOME}/.ssh/id_rsa" || alias id_rsa="ssh-add -k \"${HOME}/.ssh/id_rsa\""
            install -m 400 -D <(Get-Hash "${ssh_hash[0]}") "${TMPDIR}/.vault"
        }; echo

        ssh-add -l &>/dev/null
        # Freshen ~/Projects folder if stale. 604800
        [[ ( "${?}" == 0 ) ]] && {
            [[ ( -d "${HOME}/Projects" && $(( $(date +%s) - $(stat -c %Y "${HOME}/Projects") )) -gt "604800" ) ]] && {
                # Update all in ~/Projects with git.
                for repo in $(find "${HOME}/Projects/"* -maxdepth 0 -type d -not -path "*/venv*"); do
                    [[ -d "${repo}/.git" ]] && {
                        Run-Command "git -C \"${repo}\" pull"
                        [[ -n "$(git -C "${repo}" submodule status)" ]] && {
                            Run-Command "git -C \"${repo}\" pull --recurse-submodules"
                        }
                    }
                done; touch "${HOME}/Projects"
            } || {
                # Update RCPATH with git.
                Run-Command "git -C \"${RCPATH}\" checkout master"
                Run-Command "git -C \"${RCPATH}\" pull -f"
            }; echo
        }
    }

    # Local python virtual environment.
    python_ver="$(python3 -c 'from sys import version_info as ver; print(ver.major,ver.minor,ver.micro, sep="_")')"
    [[ -d "${HOME}/.local/venv${python_ver}" ]] && {
        echo "Loading Python virtual environment: ~/.local/venv${python_ver}"
        Run-Command "source \"${HOME}/.local/venv${python_ver}/bin/activate\""
    } || {
        echo "Building Python virtual environment: ~/.local/venv${python_ver}"
        Run-Command "mkdir -p \"${HOME}/.local/venv${python_ver}\""
        Run-Command "python3 -m venv \"${HOME}/.local/venv${python_ver}\""
        Run-Command "source \"${HOME}/.local/venv${python_ver}/bin/activate\""

        # Install base python modules.
        [[ -x "${RCPATH}/env_python.sh" ]] && {
            Run-Command "${RCPATH}/env_python.sh"
        }
    }; echo

    # Extract sensitive credentials.
    command -v Get-Vault &> /dev/null && [[ -e "${HOME}/.${USER:-$(whoami)}.vault" ]] && {
        # Create a .cloginrc for rancid.
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 600 "${TMPDIR}/.cloginrc"
        ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(printf "%q\t%q" $(yq -r '.["'''${USER:-$(whoami)}'''"]|[.tacacs,.tacacs]|@tsv' <(Get-Vault)))
        add method      *       ssh telnet
	EOF
    } || {
        echo -e "\n[${HOSTNAME}] Run the \"$(tput setaf 2 2> /dev/null)Initialize-Vault$(tput sgr0 2> /dev/null)\" shell function to create a vault."
    }
} || {
    echo -e "\n[${HOSTNAME}] System unconfigured or profile.d not loaded!\n"
}

##################
# Run fun stuff. #
##################

# Load user environment.
for i in ${HOME}/.bash_aliases ${HOME}/.env; do
    [[ -r "${i}" ]] && {
        [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
    }
done

# Provide a random quote from author.
[[ -x "${RCPATH}/quote.sh" ]] && {
    tput setaf 8 2> /dev/null
    awk 'BEGIN{print "  +-"}//{print "  | ",$0}END{print "  +-\n"}' <("${RCPATH}/quote.sh")
    tput sgr0 2> /dev/null
}

# Display the hostname at login.
[[ -d "${RCPATH}/.fonts/figlet" ]] && {
    [[ -s "$(command -v toilet)" ]] && {
        uname -n | toilet -d "${RCPATH}/.fonts/figlet" -f smbraille --metal
    } || {
        tput setaf 4 2> /dev/null
        if command -v figlet &> /dev/null; then
            uname -n | figlet -d "${RCPATH}/.fonts/figlet" -f smbraille
        else
            echo ">>> $(uname -n) <<<"
        fi; tput sgr0 2> /dev/null
    }; echo
}
