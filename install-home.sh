#!/bin/bash
## Initialize home from a dna5rm clone. Password is a speed bump against accidental runs.

PROTECTED="U2FsdGVkX1+Lv1gKnydwejkzn+wch0ddqqhpaj2SdTU="

function Run-Command() {
    [[ "${#@}" -ge 1 ]] || { echo "No commands to execute..."; return 1; }
    local command _rc=0
    for command in "${@}"; do
        printf '>>> %s\n' "${command}" >&2
        eval "${command}"
        _rc=$?
        [[ ${_rc} -eq 0 ]] || return ${_rc}
    done
    return 0
}

function Protect-String() {
    [[ -n "${*}" && -n "${password}" ]] || return 1
    base64 -w0 <(printf '%s' "${*}" | openssl enc -aes-256-cbc -e -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}")
}

function Unprotect-String() {
    [[ -n "${*}" && -n "${password}" ]] || return 1
    base64 -d <<< "${*}" | openssl enc -aes-256-cbc -d -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}"
}

function Link-If() {
    local src="${1}" dest="${2}"
    [[ -e "${src}" ]] || { echo "skip (missing): ${src}" >&2; return 0; }
    Run-Command "ln -sfTv \"${src}\" \"${dest}\""
}

tput setaf 3 >&2
printf '\n>>> Linux Environment Bootstrap <<<\n\n' >&2
tput sgr0 >&2

read -s -p "Password: " password && echo

PROTECTED="$(Unprotect-String "${PROTECTED}")" || exit 1

[[ "${PROTECTED}" == "${password}" ]] || {
    tput setaf 8
    echo -e "\nPROTECT=\"$(Protect-String "${password}")\"\n"
    tput sgr0
    exit 1
}

repo="${HOME}/Projects/${PROTECTED}"
scripts="${HOME}/Projects/linux-scripts"

Run-Command "mkdir -p \"${HOME}/Projects\""

if [[ -d "${repo}/.git" ]]; then
    echo "already cloned: ${repo}" >&2
else
    Run-Command "git clone \"https://github.com/${PROTECTED}/${PROTECTED}.git\" \"${repo}\""
fi

if [[ -d "${scripts}/.git" ]]; then
    echo "already cloned: ${scripts}" >&2
else
    Run-Command "git clone \"https://github.com/${PROTECTED}/linux-scripts.git\" \"${scripts}\""
fi

Link-If "${repo}/.profile" "${HOME}/.profile"
Link-If "${repo}/.bash_logout" "${HOME}/.bash_logout"
Link-If "${repo}/.bashrc" "${HOME}/.bashrc"
Link-If "${repo}/.dialogrc" "${HOME}/.dialogrc"
Link-If "${repo}/.screenrc" "${HOME}/.screenrc"
Link-If "${repo}/.sqliterc" "${HOME}/.sqliterc"
Link-If "${repo}/.tmux.conf" "${HOME}/.tmux.conf"
Link-If "${repo}/.vimrc" "${HOME}/.vimrc"
[[ -d "${scripts}" ]] && Link-If "${scripts}" "${HOME}/bin"

Run-Command "mkdir -p \"${HOME}/.ssh\" \"${HOME}/.gnupg\" \"${HOME}/.local/bin\" \"${HOME}/.local/lib\" \"${HOME}/.local/share\" \"${HOME}/.local/src\" \"${HOME}/.bash_completion.d\""
[[ -f "${repo}/.ssh/config" ]] && Run-Command "install -m 644 -D \"${repo}/.ssh/config\" \"${HOME}/.ssh/config\""
Link-If "${repo}/.gnupg/gpg.conf" "${HOME}/.gnupg/gpg.conf"

echo "done. next login: venv + profile.d + session.sh. optional: \$HOME/.env for PYTHON / VENV_NAME" >&2
