#!/bin/bash
## Initialize home from a dna5rm clone. Password is a speed bump against accidental runs.
## Do not pipe into bash (read -s needs a TTY). Prefer jsDelivr — GitHub raw CDN is often stale.
##   bash -c "$(curl -fsSL https://cdn.jsdelivr.net/gh/dna5rm/dna5rm@master/install-home.sh)"

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
    base64 -w0 <(printf '%s' "${*}" | "${OPENSSL:-openssl}" enc -aes-256-cbc -e -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}")
}

function Unprotect-String() {
    [[ -n "${*}" && -n "${password}" ]] || return 1
    base64 -d <<< "${*}" | "${OPENSSL:-openssl}" enc -aes-256-cbc -d -md sha512 -pbkdf2 -iter 100000 -salt -k "${password}"
}

function Link-If() {
    local src="${1}" dest="${2}"
    [[ -e "${src}" ]] || { echo "skip (missing): ${src}" >&2; return 0; }
    Run-Command "ln -sfTv \"${src}\" \"${dest}\""
}

function is_termux() {
    command -v termux-info >/dev/null 2>&1
}

function have_openssl() {
    [[ -n "${PREFIX}" && -x "${PREFIX}/bin/openssl" ]] && return 0
    command -v openssl >/dev/null 2>&1
}

# Color is optional. Fresh Termux has no tput until ncurses-utils.
function tput-safe() {
    command -v tput >/dev/null 2>&1 || return 0
    tput "$@"
}

# Gate needs the openssl CLI. Termux splits it: openssl = libs, openssl-tool = bin/openssl.
function Ensure-Termux-Gate-Tools() {
    is_termux || return 0
    PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    export PREFIX PATH="${PREFIX}/bin:${PATH}"
    hash -r 2>/dev/null || true
    have_openssl && return 0
    echo "Termux: installing openssl-tool for the password gate" >&2
    Run-Command "pkg install -y openssl openssl-tool" || true
    hash -r 2>/dev/null || true
}

# Termux: pkg list from former env_termux.sh. tur-repo first (python3.11).
function Install-Termux-Pkgs() {
    is_termux || return 0
    local pkgs=(
        ncurses-utils tur-repo
        ca-certificates clang coreutils curl ffmpeg git libffi make python3.11
        openssh openssl openssl-tool pkg-config ripgrep rust
        argon2 asciidoctor
        bat bc binutils bmon build-essential
        clamav dialog dnsutils
        exiftool expect fdupes file
        glow gnupg golang graphviz
        htop imagemagick ipcalc jq
        libandroid-spawn libmaxminddb-tools libxml2 libxslt libzmq lsd
        mandoc moreutils neofetch neovim nmap nodejs-lts
        ossp-uuid pandoc pdfgrep proot-distro pup
        rsync screen steghide
        termux-api tidy tmux toilet wget whois
    )
    echo "Termux: installing packages..." >&2
    Run-Command "pkg install -y tur-repo"
    Run-Command "pkg install -y ${pkgs[*]}"
}

function Pin-Termux-Python() {
    is_termux || return 0
    command -v python3.11 >/dev/null 2>&1 || {
        echo "python3.11 missing after pkg install" >&2
        return 1
    }
    if [[ -f "${HOME}/.env" ]] && grep -qE '^[[:space:]]*(export[[:space:]]+)?PYTHON=' "${HOME}/.env"; then
        echo "\$HOME/.env already pins PYTHON" >&2
    else
        printf '\nexport PYTHON=python3.11\n' >> "${HOME}/.env"
        echo "wrote export PYTHON=python3.11 to \$HOME/.env (host overlay, not the repo)" >&2
    fi
}

tput-safe setaf 3 >&2
printf '\n>>> Linux Environment Bootstrap <<<\n\n' >&2
tput-safe sgr0 >&2

# Gate first. No clones, links, or full pkg installs until this passes.
# Pipe-to-bash has no TTY — refuse so read cannot eat the script or skip the bump.
if [[ ! -c /dev/tty ]]; then
    echo "need a TTY for the password prompt. do not pipe into bash." >&2
    echo "  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/dna5rm/dna5rm/master/install-home.sh)\"" >&2
    exit 1
fi
Ensure-Termux-Gate-Tools
have_openssl || {
    echo "openssl required for the password gate. install it yourself, then re-run (this script will not on non-Termux)." >&2
    exit 1
}
if [[ -n "${PREFIX}" && -x "${PREFIX}/bin/openssl" ]]; then
    OPENSSL="${PREFIX}/bin/openssl"
else
    OPENSSL="$(command -v openssl)"
fi

printf '\nBootstrap password (input hidden):\nPassword: ' >/dev/tty
read -s password </dev/tty
printf '\n' >/dev/tty
[[ -n "${password}" ]] || { echo "empty password" >&2; exit 1; }

PROTECTED="$(Unprotect-String "${PROTECTED}")" || exit 1

[[ "${PROTECTED}" == "${password}" ]] || {
    tput-safe setaf 8
    echo -e "\nPROTECT=\"$(Protect-String "${password}")\"\n"
    tput-safe sgr0
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

if is_termux; then
    Install-Termux-Pkgs
    Pin-Termux-Python
    # Login bash prefers ~/.bash_profile over ~/.profile. Ensure one exists.
    if [[ ! -e "${HOME}/.bash_profile" ]]; then
        printf '%s\n' '[ -f "$HOME/.profile" ] && . "$HOME/.profile"' > "${HOME}/.bash_profile"
        echo "wrote ~/.bash_profile -> .profile" >&2
    fi
    echo "Termux: next login uses python3.11 venv (bashrc + \$HOME/.env PYTHON=)." >&2
fi

echo "done. next login: venv + profile.d + session.sh." >&2
