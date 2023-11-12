# Do nothing if non-interactive!
[[ $- != *i* ]] && { return; }

# Create a user tmp directory.
[[ -z "${TMPDIR}" ]] && {
    readonly TMPDIR="$(mktemp -d)"
    trap 'rm -rf -- "${TMPDIR}"' EXIT
}

# User Variables.
readonly TMOUT=900
export gpg_method="symmetric"
export ANSIBLE_LOG_FILE="${TMPDIR}/ansible.$(date +%Y%m%d_%H%M%S).log)"
export EDITOR=nano
export PYTHONHTTPSVERIFY=0
export RCPATH="$(dirname $(readlink -f "${HOME}/.bashrc"))"
export TMPDIR

# Extra/Custom Variables.
[[ -f "${HOME}/.vars" ]] && { . "${HOME}/.vars"; }

# Update local $PATH
for p in bin opt .cargo/bin; do
    [[ -d "${HOME}/${p}" ]] && { PATH=${PATH}:"${HOME}/${p}"; }
done

# Load aliases and functions.
[[ -d "${RCPATH}/profile.d" ]] && {
    for i in ${HOME}/.bash_aliases ${RCPATH}/profile.d/*.sh; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done
}

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

cmd_avail=() ## Check for common tools and profile.d functions.
for cmd_check in ansible-vault argon2 contains_element crypt ct curl dialog git gpg jq openssl rsync shred tput toilet yq; do
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
        install -m 400 <(yq -r '.'''${USER:-$(whoami)}'''[]|select(.private_key_content != null).private_key_content' <(vault)) "${TMPDIR}/id_rsa"
        eval $(ssh-agent) && [[ -s "${TMPDIR}/id_rsa" ]] && { timeout 1s ssh-add -k "${TMPDIR}/id_rsa"; }
        echo

        # .cloginrc for rancid.
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc"
        ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(yq -r '.'''${USER:-$(whoami)}'''[]|select(.tacacs != null)|[.tacacs,.tacacs]|@tsv' <(vault))
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
        uname -n | toilet -d "${HOME}/.fonts/figlet" -f elite --filter metal
    }

    # Provide a random quote from author.
    [[ -x "${RCPATH}/quote.sh" ]] && { "${RCPATH}/quote.sh"; }

} || {
    echo "[${HOSTNAME}] System unconfigured or profile.d not loaded!"
}
