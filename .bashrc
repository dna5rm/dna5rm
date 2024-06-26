# Do nothing if non-interactive!
[[ $- != *i* ]] && { return; }

# Create a user tmp directory.
if [[ -z "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    readonly TMPDIR="$(mktemp -d)"
    export TMPDIR
elif [[ ! -z "${TMPDIR}" ]] && [[ ! -d "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    mkdir -m 700 -p "${TMPDIR}"
fi

# User Variables.
readonly TMOUT=900
export gpg_method="symmetric"
export ANSIBLE_LOG_FILE="${TMPDIR}/ansible.$(date +%Y%m%d_%H%M%S).log)"
export EDITOR=nano
export PYTHONHTTPSVERIFY=0
export RCPATH="$(dirname $(readlink -f "${HOME}/.bashrc"))"

# Extra/Custom Variables.
[[ -f "${HOME}/.env" ]] && { . "${HOME}/.env"; }

# Update local $PATH
for p in bin .local/bin .local/opt go/bin .cargo/bin; do
    [[ -d "${HOME}/${p}" ]] && { PATH=${PATH}:"${HOME}/${p}"; }
done

# Python virtual environment.
python_ver="$(python3 -c 'from sys import version_info as ver; print(ver.major,ver.minor,ver.micro, sep="_")')"
[[ -d "${HOME}/Projects/venv${python_ver}" ]] && {
    source "${HOME}/Projects/venv${python_ver}/bin/activate"
} || {
    echo "Building Python virtual environment: ~/Projects/venv${python_ver}"
    mkdir -p "${HOME}/Projects/venv${python_ver}"
    python3 -m venv "${HOME}/Projects/venv${python_ver}"
    source "${HOME}/Projects/venv${python_ver}/bin/activate"

    # Build out the environment packages.
    [[ -x "${RCPATH%/*}/env_python.sh" ]] && {
        "${RCPATH%/*}/env_python.sh"
        find "${HOME}/env_python.log" -type f -size 0 -exec rm {} \;
    }
}

# Load aliases and functions.
[[ -d "${RCPATH}/profile.d" ]] && {
    for i in ${HOME}/.bash_aliases ${RCPATH}/profile.d/*.sh; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done
}

cmd_avail=() ## Check for common tools and profile.d functions.
for cmd_check in ansible-vault argon2 contains_element crypt ct curl dialog figlet git gpg jq openssl rsync shred tput yq; do
    type ${cmd_check} >/dev/null 2>&1 && {
         cmd_avail+=( ${cmd_check} )
    } || {
        echo "\`${cmd_check}\` not found!"
    }
done; unset cmd_check

# Get vault password file for ansible-vault.
echo ansible-vault argon2 yq | contains_element ${cmd_avail[@]} > /dev/null 2>&1 && {

    [[ ! -f "${HOME}/.vault" ]] && {
        read -rs -t 15 -p "Vault Passphrase: " passphrase
        install -m 400 -D <(argon2 "$(printf "%-8s" ${USER:-$(whoami)})" -i -l 128 -r -v 13 <<< "${passphrase:-${HOSTNAME,,}}") "${TMPDIR}/.vault"
        unset passphrase && echo
    } || { ln -sf "${HOME}/.vault" "${TMPDIR}/.vault"; }

    # Create a vault if it does not exist.
    [[ ! -f "${HOME}/.${USER:-loginrc}.vault" ]] && {
        ansible-vault create "${HOME}/.${USER:-loginrc}.vault" --vault-password-file "${TMPDIR}/.vault"
    }

    # extract sensitive credentials.
    vault > /dev/null 2>&1 && {
        # ssh private key & agent.
        install -m 400 <(yq -r '.["'''${USER:-$(whoami)}'''"]["private_key_content"]' <(vault)) "${TMPDIR}/id_rsa"
        eval $(ssh-agent) && [[ -s "${TMPDIR}/id_rsa" ]] && { timeout 1s ssh-add -k "${TMPDIR}/id_rsa" || alias id_rsa="ssh-add -k \"${TMPDIR}/id_rsa\""; }
        echo

        # .cloginrc for rancid.
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 400 "${TMPDIR}/.cloginrc"
        ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(printf "%q\t%q" $(yq -r '.["'''${USER:-$(whoami)}'''"]|[.tacacs,.tacacs]|@tsv' <(vault)))
        add method      *       ssh telnet
	EOF
    }
}

##################
# Run fun stuff. #
##################

[[ ! -z ${cmd_avail[@]} ]] && {

    # Display the hostname at login.
    [[ -d "${HOME}/.fonts/figlet" ]] && {
        uname -n | figlet -d "${HOME}/.fonts/figlet" -w $(tput cols) -f rectangles
    }

    # Provide a random quote from author.
    [[ -x "${RCPATH}/quote.sh" ]] && { "${RCPATH}/quote.sh"; }

} || {
    echo "[${HOSTNAME}] System unconfigured or profile.d not loaded!"
} && cd "${HOME}"
