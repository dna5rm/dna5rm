#!/bin/bash
## Initialize home from a dna5rm clone. Password is a speed bump against accidental runs.
## Do not pipe into bash (read -s needs a TTY).
## jsDelivr @master caches ~7d — it still served ln -sfTv after GitHub had ln -sfn.
## Use GitHub raw, or jsDelivr pinned to a commit SHA, not @master.
##   bash -c "$(curl -fsSL https://raw.githubusercontent.com/dna5rm/dna5rm/master/install-home.sh)"

PROTECTED="U2FsdGVkX1+Lv1gKnydwejkzn+wch0ddqqhpaj2SdTU="

function run_command() {
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
    [[ -e "${src}" ]] || { echo "skip (missing): ${src}" >&2; return 1; }
    # -sfn: portable (busybox + GNU). Do not use -T; fresh Termux ln is busybox until coreutils.
    hash -r 2>/dev/null || true
    run_command "ln -sfn \"${src}\" \"${dest}\"" || return 1
    [[ -L "${dest}" ]] || { echo "link failed: ${dest}" >&2; return 1; }
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
    run_command "pkg install -y openssl openssl-tool" || true
    hash -r 2>/dev/null || true
}

# Termux apt python-cryptography is built for stock CPython 3.13.
# Vault/ansible live in the 3.11 venv (pip cryptography==46.0.7).
# Pin-Priority -1 + hold so pkg/apt cannot install or upgrade the distro module.
function Block-Termux-Pkg-Python-Cryptography() {
    is_termux || return 0
    PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
    local prefdir="${PREFIX}/etc/apt/preferences.d"
    local pref="${prefdir}/no-python-cryptography"
    mkdir -p "${prefdir}"
    cat > "${pref}" <<'EOF'
Explanation: distro python-cryptography is CPython 3.13; dna5rm vault uses 3.11 venv
Package: python-cryptography
Pin: version *
Pin-Priority: -1
EOF
    echo "wrote apt pin -1 for python-cryptography (${pref})" >&2
    if dpkg -s python-cryptography >/dev/null 2>&1; then
        echo "Termux: removing installed python-cryptography (wrong interpreter)" >&2
        run_command "pkg uninstall -y python-cryptography" || true
    fi
    apt-mark hold python-cryptography >/dev/null 2>&1 || true
}

# Termux: tur-repo first, refresh index, then bulk pkgs, then python3.11.
# python3.11 is TUR-only. Installing it in the same apt transaction as tur-repo
# (or before pkg update) uses a stale Packages file and 404s 3.11.16.
function Install-Termux-Pkgs() {
    is_termux || return 0
    local pkgs=(
        ncurses-utils
        ca-certificates clang coreutils curl ffmpeg git libffi make
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
    run_command "pkg install -y tur-repo"
    run_command "pkg update -y"
    Block-Termux-Pkg-Python-Cryptography
    run_command "pkg install -y ${pkgs[*]}"
    echo "Termux: python3.11 from TUR" >&2
    run_command "pkg install -y python3.11"
    Block-Termux-Pkg-Python-Cryptography
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

# Host overlay, not the repo. ansible-core pulls cryptography; pip 50.x
# ships an abi3 wheel that dlopens on Termux 3.11 then fails
# (PyExc_Warning). 46.0.7 builds a real android_30 arm64 wheel.
# pykeepass pulls argon2-cffi-bindings; PyPI linux_aarch64 abi3 wheels
# are glibc and segfault on Termux (import argon2 -> 139). Pin 21.2.0
# and no-binary so pip builds against bionic.
function Pin-Termux-Pip-Cryptography() {
    is_termux || return 0
    local pipdir="${HOME}/.pip"
    local constraints="${pipdir}/constraints.txt"
    local conf="${pipdir}/pip.conf"
    mkdir -p "${pipdir}"
    if [[ -f "${constraints}" ]] && grep -qE '^[[:space:]]*cryptography==46\\.0\\.7[[:space:]]*$' "${constraints}"; then
        echo "\$HOME/.pip already pins cryptography==46.0.7" >&2
    else
        if [[ -f "${constraints}" ]] && grep -qE '^[[:space:]]*cryptography==' "${constraints}"; then
            # replace any other cryptography pin; keep other lines
            local tmp
            tmp="$(mktemp "${pipdir}/constraints.XXXXXX")" || return 1
            grep -vE '^[[:space:]]*cryptography==' "${constraints}" > "${tmp}" || true
            printf 'cryptography==46.0.7\n' >> "${tmp}"
            mv "${tmp}" "${constraints}"
        else
            printf 'cryptography==46.0.7\n' >> "${constraints}"
        fi
        echo "wrote cryptography==46.0.7 to \$HOME/.pip/constraints.txt" >&2
    fi
    if [[ -f "${constraints}" ]] && grep -qE '^[[:space:]]*argon2-cffi-bindings==21\\.2\\.0[[:space:]]*$' "${constraints}"; then
        echo "\$HOME/.pip already pins argon2-cffi-bindings==21.2.0" >&2
    else
        if [[ -f "${constraints}" ]] && grep -qE '^[[:space:]]*argon2-cffi-bindings==' "${constraints}"; then
            local tmp
            tmp="$(mktemp "${pipdir}/constraints.XXXXXX")" || return 1
            grep -vE '^[[:space:]]*argon2-cffi-bindings==' "${constraints}" > "${tmp}" || true
            printf 'argon2-cffi-bindings==21.2.0\n' >> "${tmp}"
            mv "${tmp}" "${constraints}"
        else
            printf 'argon2-cffi-bindings==21.2.0\n' >> "${constraints}"
        fi
        echo "wrote argon2-cffi-bindings==21.2.0 to \$HOME/.pip/constraints.txt" >&2
    fi
    if [[ -f "${conf}" ]] && grep -qE '^[[:space:]]*constraint[[:space:]]*=' "${conf}"; then
        echo "\$HOME/.pip/pip.conf already has constraint=" >&2
    else
        if [[ ! -f "${conf}" ]] || ! grep -qE '^[[:space:]]*\[global\]' "${conf}"; then
            printf '[global]\nconstraint = %s\n' "${constraints}" >> "${conf}"
        else
            printf 'constraint = %s\n' "${constraints}" >> "${conf}"
        fi
        echo "wrote constraint= to \$HOME/.pip/pip.conf (blocks cryptography 50.x)" >&2
    fi
    if [[ -f "${conf}" ]] && grep -qE '^[[:space:]]*no-binary[[:space:]]*=' "${conf}"; then
        echo "\$HOME/.pip/pip.conf already has no-binary=" >&2
    else
        printf 'no-binary = argon2-cffi-bindings\n' >> "${conf}"
        echo "wrote no-binary=argon2-cffi-bindings to \$HOME/.pip/pip.conf" >&2
    fi
}

tput-safe setaf 3 >&2
printf '\n>>> Linux Environment Bootstrap <<<\n\n' >&2
tput-safe sgr0 >&2

# Gate first. No clones, links, or full pkg installs until this passes.
# Pipe-to-bash has no TTY — refuse so read cannot eat the script or skip the bump.
if [[ ! -c /dev/tty ]]; then
    echo "need a TTY for the password prompt. do not pipe into bash." >&2
    echo "  bash -c \"\$(curl -fsSL https://cdn.jsdelivr.net/gh/dna5rm/dna5rm@master/install-home.sh)\"" >&2
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

# Termux: pkgs (git, coreutils, ca-certificates) before clone or ln.
# Clone-first on a wiped phone: no git → empty repo → skip (missing) .bashrc.
if is_termux; then
    Install-Termux-Pkgs
    hash -r 2>/dev/null || true
    Pin-Termux-Python
    Pin-Termux-Pip-Cryptography
fi

run_command "mkdir -p \"${HOME}/Projects\""

if [[ -d "${repo}/.git" ]]; then
    echo "already cloned: ${repo} — pulling" >&2
    run_command "git -C \"${repo}\" pull --ff-only" || exit 1
else
    run_command "git clone \"https://github.com/${PROTECTED}/${PROTECTED}.git\" \"${repo}\"" || exit 1
fi
[[ -f "${repo}/.bashrc" ]] || { echo "clone missing ${repo}/.bashrc" >&2; exit 1; }

if [[ -d "${scripts}/.git" ]]; then
    echo "already cloned: ${scripts}" >&2
else
    run_command "git clone \"https://github.com/${PROTECTED}/linux-scripts.git\" \"${scripts}\"" || exit 1
fi

Link-If "${repo}/.profile" "${HOME}/.profile" || exit 1
Link-If "${repo}/.bash_logout" "${HOME}/.bash_logout" || exit 1
Link-If "${repo}/.bashrc" "${HOME}/.bashrc" || exit 1
Link-If "${repo}/.dialogrc" "${HOME}/.dialogrc" || true
Link-If "${repo}/.screenrc" "${HOME}/.screenrc" || true
Link-If "${repo}/.sqliterc" "${HOME}/.sqliterc" || true
Link-If "${repo}/.tmux.conf" "${HOME}/.tmux.conf" || true
Link-If "${repo}/.vimrc" "${HOME}/.vimrc" || exit 1
[[ -d "${scripts}" ]] && { Link-If "${scripts}" "${HOME}/bin" || exit 1; }

run_command "mkdir -p \"${HOME}/.ssh\" \"${HOME}/.gnupg\" \"${HOME}/.local/bin\" \"${HOME}/.local/lib\" \"${HOME}/.local/share\" \"${HOME}/.local/src\" \"${HOME}/.bash_completion.d\""
[[ -f "${repo}/.ssh/config" ]] && run_command "install -m 644 -D \"${repo}/.ssh/config\" \"${HOME}/.ssh/config\""
Link-If "${repo}/.gnupg/gpg.conf" "${HOME}/.gnupg/gpg.conf" || true

for _need in .profile .bashrc .vimrc; do
    [[ -L "${HOME}/${_need}" ]] || { echo "profile not linked: ${HOME}/${_need}" >&2; exit 1; }
done
unset _need

if is_termux; then
    # Login bash prefers ~/.bash_profile over ~/.profile. Ensure one exists.
    if [[ ! -e "${HOME}/.bash_profile" ]]; then
        printf '%s\n' '[ -f "$HOME/.profile" ] && . "$HOME/.profile"' > "${HOME}/.bash_profile"
        echo "wrote ~/.bash_profile -> .profile" >&2
    fi
    echo "Termux: next login uses python3.11 venv (bashrc + \$HOME/.env PYTHON=)." >&2
fi

echo "done. next login: venv + profile.d + session.sh." >&2
