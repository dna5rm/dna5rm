#!/bin/bash
## This script initializes my home directory.
## A password is asked for solely to prevent accidental execution.

PROTECTED="U2FsdGVkX1+Lv1gKnydwejkzn+wch0ddqqhpaj2SdTU="

function Run-Command() {
    # Display and run a command for a user.
    [[ "${#@}" -ge 1 ]] && {
        local command && for command in "${@}"; do
            printf "$(tput sgr0)>>> $(tput setaf 2)%s$(tput sgr0)\n" "${command}"
            # Check if the chromaterm exists
            if command -v ct &> /dev/null
            then eval "${command}" | ct
            else eval "${command}"
            fi
        done
    } || {
        echo "No commands to execute..."
    }
}

function Protect-String() {
    [[  -n "${@}" && -n "${password}" ]] && {
        base64 -w0 <(printf "${@}" | openssl enc -aes-256-cbc -e -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}")
    } || {
        exit 1;
    }
}

function Unprotect-String() {
    [[  -n "${@}" && -n "${password}" ]] && {
        base64 -d <<< "${@}" | openssl enc -aes-256-cbc -d -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}"
    } || {
        exit 1;
    }
}

# Display Script Banner
tput setaf 3
cat <<EOF

>>> Linux Environment Bootstrap <<<

EOF
tput sgr0

# Ask for unprotect password
read -s -i "" -p "Password: " password && echo
PROTECTED="$(Unprotect-String ${PROTECTED})"

# password & protected string is my public profile
[[ "${PROTECTED}" == "${password}" ]] && {

    # Clone repos to ~/Projects
    commands=(
        "mkdir -p \"${HOME}/Projects\""
        "git clone https://github.com/${PROTECTED}/${PROTECTED}.git \"${HOME}/Projects/${PROTECTED}\""
        "git clone https://github.com/${PROTECTED}/linux-scripts.git \"${HOME}/Projects/linux_scripts\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.ansible.cfg\" \"${HOME}/.ansible.cfg\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.ansible-navigator.yaml\" \"${HOME}/.ansible-navigator.yaml\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.profile\" \"${HOME}/.profile\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.bash_logout\" \"${HOME}/.bash_logout\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.bashrc\" \"${HOME}/.bashrc\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.dialogrc\" \"${HOME}/.dialogrc\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.screenrc\" \"${HOME}/.screenrc\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.sqliterc\" \"${HOME}/.sqliterc\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.tmux.conf\" \"${HOME}/.tmux.conf\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.vimrc\" \"${HOME}/.vimrc\""
        "ln -sfTv \"${HOME}/Projects/linux-scripts\" \"${HOME}/bin\""
        "install -m 644 -D \"${HOME}/Projects/${PROTECTED}/.ssh/config\" \"${HOME}/.ssh/config\""
        "mkdir -p \"${HOME}/.gnupg\""
        "ln -sfTv \"${HOME}/Projects/${PROTECTED}/.gnupg/gpg.conf\" \"${HOME}/.gnupg/gpg.conf\""
        "mkdir -p \"${HOME}/.local/bin\""
        "mkdir -p \"${HOME}/.local/lib\""
        "mkdir -p \"${HOME}/.local/share\""
        "mkdir -p \"${HOME}/.local/src\""
    ) && Run-Command "${commands[@]}"

} || {
    tput setaf 8
    echo -e "\nPROTECT=\"$(Protect-String "${password}")\"\n"
    tput sgr0
}
