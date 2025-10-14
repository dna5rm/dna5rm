# Do nothing if non-interactive!
[[ $- != *i* ]] && { return; }

# Set the default shell options.
export RCPATH="$(dirname $(readlink -f "${HOME}/.bashrc"))"
readonly TMOUT=900

# Set USER Var if does not exist
[[ -z "${USER}" ]] && {
    USER="$(awk -F'.' 'END { if (NF > 1) print $(NF-1) }' <(ls ~/.*.vault 2> /dev/null))"
} || {
    USER="$(whoami)"
}

# Create a user tmp directory.
if [[ -z "${TMPDIR}" ]]; then
    # Prune any previously created tmp directories +7 days.
    [[ -d "/tmp" ]] && {
        find /tmp -maxdepth 1 -name tmp.* -type d -user ${USER:-$(whoami)} -mtime +7 -exec rm -rf {} +
    }
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    readonly TMPDIR="$(mktemp -d)"
    export TMPDIR
elif [[ ! -z "${TMPDIR}" ]] && [[ ! -d "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT LOGOUT
    mkdir -m 700 -p "${TMPDIR}"
fi && echo -e "Temp Directory: ${TMPDIR}\n"


# Update the PATH variable.
for p in bin .local/bin .local/opt go/bin .cargo/bin; do
    [[ -d "${HOME}/${p}" ]] && { PATH="${HOME}/${p}":${PATH}; }
done

# Setup RCPATH environment.
[[ -d "${RCPATH}/profile.d" ]] && {

    [[ -e "${RCPATH}/profile.d/Run-Command.sh" ]] && { . "${RCPATH}/profile.d/Run-Command.sh"; }

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

    # Load profile.d scripts.
    for i in ${RCPATH}/profile.d/*.sh ${RCPATH}/.aliases ${RCPATH}/.env; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done

    # SSH - START BLOCK (logging in via SSH)
#   [[ ! -z "${SSH_CONNECTION}" ]] && {

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

#   }
    # SSH - END BLOCK

    # Unvault sensitive credentials.
    if type Get-Vault >/dev/null 2>&1; then
    if [[ -e "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]]; then
        # Load .env within the vault into the user environment.
        yq -r '.env | to_entries[]' <(vault) &> /dev/null && {
            eval "$(yq -r '.env | to_entries[] | "export " + .key + "=" + (.value|tostring|@sh)' 2> /dev/null <(vault))"
        } || {
            tput setaf 8 2> /dev/null
            echo -e "### No vaulted environmental variables found. ###"
            # awk '//{print "#",$0}' <(yq -y -n '{"env":{"ENV_VAR":"Example Variable"}}')
            tput sgr0 2> /dev/null; echo
        }

    # Create a .cloginrc in $TMPDIR for rancid.
	[[ ! -z "${TACACS}" ]] && {
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 600 "${TMPDIR}/.cloginrc"
        ## Generated from \${TACACS} variable :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(printf "%q %q" "${TACACS}" "${TACACS}")
        add method      *       ssh telnet
	EOF
    } || {
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 600 "${TMPDIR}/.cloginrc"
        ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(printf "%q\t%q" $(yq -r '.["'''${USER:-$(whoami)}'''"]|[.tacacs,.tacacs]|@tsv' <(Get-Vault)))
        add method      *       ssh telnet
	EOF
    }
    elif [[ -n "${ssh_hash[*]}" ]]; then
        echo -e "\n[${HOSTNAME}] Run the \"$(tput setaf 2 2> /dev/null)Initialize-Vault$(tput sgr0 2> /dev/null)\" shell function to create a vault.\n"
    fi; fi

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
