# Do nothing if non-interactive!
[[ $- != *i* ]] && { return; }

# Set the default shell options.
readonly RCPATH="$(dirname $(readlink -f "${HOME}/.bashrc"))"
readonly TMOUT=900

# Create a user tmp directory.
if [[ -z "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    readonly TMPDIR="$(mktemp -d)"
    export TMPDIR
elif [[ ! -z "${TMPDIR}" ]] && [[ ! -d "${TMPDIR}" ]]; then
    trap 'rm -rf -- "${TMPDIR}"' EXIT
    mkdir -m 700 -p "${TMPDIR}"
fi

# Update the PATH variable.
for p in bin .local/bin .local/opt go/bin .cargo/bin; do
    [[ -d "${HOME}/${p}" ]] && { PATH=${PATH}:"${HOME}/${p}"; }
done

# Local python virtual environment.
python_ver="$(python3 -c 'from sys import version_info as ver; print(ver.major,ver.minor,ver.micro, sep="_")')"
[[ -d "${HOME}/.local/venv${python_ver}" ]] && {
    source "${HOME}/.local/venv${python_ver}/bin/activate"
} || {
    echo "Building Python virtual environment: ~/.local/venv${python_ver}"
    mkdir -p "${HOME}/.local/venv${python_ver}"
    python3 -m venv "${HOME}/.local/venv${python_ver}"
    source "${HOME}/.local/venv${python_ver}/bin/activate"
}

# Setup user shell environment.
[[ -d "${RCPATH}/profile.d" ]] && {
    # Load profile.d scripts.
    for i in ${RCPATH}/profile.d/*.sh ${RCPATH}/.aliases ${RCPATH}/.env; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done

    # Report if any commands are missing.
    for i in $(awk -F'[)(]' '/Command_List=/{printf $(NF-1)}' ${RCPATH}/profile.d/*.sh | tr ' ' '\n' | sort -u | tr '\n' ' '); do
        type ${i} >/dev/null 2>&1 || { echo "[${HOSTNAME}] Command ${i} not found!"; }
    done

    # Load ssh key fingerprint as ssh_hash.
    type Get-SshKeyFingerprint >/dev/null 2>&1 && export ssh_hash=( `Get-SshKeyFingerprint` )

    # Load ssh key into ssh-agent if ssh_hash is set.
    [[ -n "${ssh_hash[*]}" ]] && {
        eval $(ssh-agent) && {
            timeout 1s ssh-add -k "${HOME}/.ssh/id_rsa" || alias id_rsa="ssh-add -k \"${HOME}/.ssh/id_rsa\""
        }; echo
    }

    # Extract sensitive credentials.
    type Get-Vault >/dev/null 2>&1 && {
        # Create a .cloginrc for rancid.
        sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 400 "${TMPDIR}/.cloginrc"
        ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
        add user        *       ${USER:-$(whoami)}
        add password    *       $(printf "%q\t%q" $(yq -r '.["'''${USER:-$(whoami)}'''"]|[.tacacs,.tacacs]|@tsv' <(Get-Vault)))
        add method      *       ssh telnet
	EOF
    }
} || {
    echo -e "\n[${HOSTNAME}] System unconfigured or profile.d not loaded!\n"
}

##################
# Run fun stuff. #
##################

# Display the hostname at login.
[[ -d "${RCPATH}/.fonts/figlet" ]] && {
    uname -n | figlet -d "${RCPATH}/.fonts/figlet" -w $(tput cols) -f rectangles
    echo
}

# Provide a random quote from an author.
[[ -x "${RCPATH}/quote.sh" ]] && { "${RCPATH}/quote.sh"; }
