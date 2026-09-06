# Do nothing if non-interactive!
[[ $- != *i* ]] && {
    # Non-interactive bootstrap: make Get-Vault available for Hermes sessions
    if [[ -f "${HOME}/.hermes/scripts/vault-bootstrap.sh" ]]; then
        source "${HOME}/.hermes/scripts/vault-bootstrap.sh"
    fi
    return
}

# Termux login: /etc/bash.bashrc and ~/.profile both source this. Once is enough.
[[ -n "${_DNA5RM_BASHRC}" ]] && return
_DNA5RM_BASHRC=1

# Set the default shell options.
# Termux often has no readlink -f (needs coreutils). Absolute symlink is enough.
_rcsrc="${BASH_SOURCE[0]:-${HOME}/.bashrc}"
if [[ -L "${_rcsrc}" ]]; then
    _rctgt="$(readlink "${_rcsrc}")"
    [[ "${_rctgt}" != /* ]] && _rctgt="$(cd "$(dirname "${_rcsrc}")" && pwd)/${_rctgt}"
    export RCPATH="$(cd "$(dirname "${_rctgt}")" && pwd)"
else
    export RCPATH="$(cd "$(dirname "${_rcsrc}")" && pwd)"
fi
unset _rcsrc _rctgt
TMOUT=900
shopt -s histappend 2>/dev/null
HISTCONTROL="${HISTCONTROL:-ignoreboth}"
HISTSIZE="${HISTSIZE:-5000}"
HISTFILESIZE="${HISTFILESIZE:-20000}"

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

# dna5rm/.env (in git, comments only) then $HOME/.env (host overlay, not in git).
[[ -r "${RCPATH}/.env" ]] && . "${RCPATH}/.env"
[[ -r "${HOME}/.env" ]] && . "${HOME}/.env"

# Interpreter for venv + python_ver. ~/.env may set PYTHON=python3.11
# Do not use an alias here — aliases skip non-interactive and -m venv.
if [[ -z "${PYTHON}" ]]; then
    if command -v termux-info >/dev/null 2>&1 && command -v python3.11 >/dev/null 2>&1; then
        PYTHON=python3.11
    else
        PYTHON=python3
    fi
fi
export PYTHON

# Run-Command lives here only — not in profile.d (glob must stay order-free).
function Run-Command() {
    [[ "${#@}" -ge 1 ]] || { echo "No commands to execute..."; return 1; }
    local command _rc=0 _green _reset
    _green="$(tput setaf 2 2>/dev/null)"
    _reset="$(tput sgr0 2>/dev/null)"
    for command in "${@}"; do
        printf '%s>>> %s%s\n' "${_reset}" "${_green}${command}${_reset}" "" >&2
        case "${command}" in
            source\ *|.\ *)
                eval "${command}"
                _rc=$?
                ;;
            *)
                if command -v ct >/dev/null 2>&1 && [[ -t 1 ]]; then
                    eval "${command}" | ct
                    _rc=${PIPESTATUS[0]}
                else
                    eval "${command}"
                    _rc=$?
                fi
                ;;
        esac
        [[ ${_rc} -eq 0 ]] || return ${_rc}
    done
    return 0
}
export -f Run-Command

# Setup RCPATH environment.
# Do not use `[[ dir ]] && { … } || { fail }` — session.sh's last test is often
# false on Termux (no SSH_CONNECTION) and that tripped the fail branch.
if [[ -d "${RCPATH}/profile.d" ]]; then

    python_ver="$("${PYTHON}" -c 'from sys import version_info as ver; print(ver.major,ver.minor,ver.micro, sep="_")')"
    # VENV_NAME from $HOME/.env (e.g. venv_test). Default: versioned venv${python_ver}
    VENV_HOME="${HOME}/.local/${VENV_NAME:-venv${python_ver}}"
    export python_ver VENV_HOME

    if [[ -d "${VENV_HOME}" ]]; then
        echo "Loading Python virtual environment: ${VENV_HOME}"
        Run-Command "source \"${VENV_HOME}/bin/activate\""
    else
        echo "Building Python virtual environment: ${VENV_HOME}"
        Run-Command "\"${PYTHON}\" -m venv \"${VENV_HOME}\""
        Run-Command "source \"${VENV_HOME}/bin/activate\""
    fi
    echo

    # profile.d: functions only. Order must not matter.
    for i in ${RCPATH}/profile.d/*.sh ${RCPATH}/.aliases; do
        [[ -r "${i}" ]] && {
            [[ "${-#*i}" != "$-" ]] && { . "${i}"; } || { . "${i}" >/dev/null; }
        }
    done

    # Vault decrypt + ssh-agent (needs functions from profile.d).
    [[ -r "${RCPATH}/session.sh" ]] && . "${RCPATH}/session.sh"

else
    echo -e "\n[${HOSTNAME}] System unconfigured or profile.d not loaded!\n"
fi

##################
# Run fun stuff. #
##################

# Extra aliases only. ${HOME}/.env already sourced (early) so PYTHON/PATH apply to venv.
[[ -r "${HOME}/.bash_aliases" ]] && . "${HOME}/.bash_aliases"

if [[ -d "${HOME}/.bash_completion.d" ]]; then
    for bcfile in "${HOME}/.bash_completion.d/"*; do
        [[ -f "${bcfile}" ]] && . "${bcfile}"
    done
fi

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
