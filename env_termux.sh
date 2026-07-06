#!/bin/env -S bash

pkgs=( ncurses-utils tur-repo )
pkgs+=( ca-certificates clang curl ffmpeg git libffi make python3.11 openssh openssl pkg-config ripgrep rust )

pkgs+=( argon2 asciidoctor )
pkgs+=( bat bc binutils bmon build-essential )
pkgs+=( clamav )
pkgs+=( dialog dnsutils )
pkgs+=( exiftool expect )
pkgs+=( fdupes ffmpeg file )
pkgs+=( glow gnupg golang graphviz )
pkgs+=( htop )
pkgs+=( imagemagick ipcalc )
pkgs+=( jq )
pkgs+=( libandroid-spawn libmaxminddb-tools libxml2 libxslt libzmq lsd )
pkgs+=( mandoc moreutils )
pkgs+=( ncurses-utils neofetch neovim nmap nodejs-lts )
pkgs+=( ossp-uuid )
pkgs+=( pandoc pdfgrep proot-distro pup )
pkgs+=( rsync )
pkgs+=( screen steghide )
pkgs+=( termux-api tidy tmux toilet )
pkgs+=( wget whois )

# Functions
. profile.d/Run-Command.sh

pipe_check() {
  input=$(cat)
  [[ -z "$input" ]] && {
    echo "${MSG:-Done. }"
  } || {
    echo "${input}"
  }
}

# Function Validation
command -v "Run-Command" >/dev/null 2>&1 || {
    echo "${0} - Run-Command function failed to load..."
    exit 0
}

# Configure Termux
command -v "termux-info" >/dev/null 2>&1 && {

  # Install Packages
  [[ ! -z "${pkgs}" ]] && {
    for pkg in ${pkgs[@]}; do
      awk '/^APT-Manual-Installed/{print $NF}' <(apt -o Apt::Cmd::Disable-Script-Warning=true show ${pkg}) \
      | grep ^"yes"$ > /dev/null \
        && ( true ) \
        || ( 
          printf "\n# Install Missing Package [%s]\n" ${pkg}
          Run-Command "yes | apt install ${pkg}"
        )
    done 2> /dev/null | MSG="Termux packages already installed..." pipe_check
  }

  # Python3.11 Virtual Env
  PY_VENV="$(awk '{ gsub(/\./, "_"); print "venv"$NF}' <(python3.11 --version))"
  [[ ! -d "${HOME}/.local" ]] && Run-Command "mkdir \"${HOME}/.local\""
  [[ ! -d "${HOME}/.local/${PY_VENV}" ]] && Run-Command "python3.11 -m venv ~/.local/${PY_VENV}"

}
