#!/bin/env -S bash

## https://wiki.termux.com/wiki/Recover_a_broken_environment
# rm -rf /data/data/com.termux/files/usr

# Packages to install
pkgs=(
    asciidoctor
    bc binutils bmon build-essential
    clamav curl
    dialog dnsutils
    exiftool expect
    fdupes ffmpeg file
    git gnupg golang graphviz
    htop
    imagemagick ipcalc
    jq
    libmaxminddb-tools libxml2 libxslt libzmq
    man moreutils
    ncurses-utils neofetch neovim nmap nodejs-lts
    openssh ossp-uuid
    pandoc pdfgrep proot-distro pup python
    rsync rust
    screen steghide
    termux-api terraform tidy toilet
    wget whois
)

# Install X11 repo
pkgs+=("x11-repo")

# X11 packages to install
case "${pkgs[@]}" in *"x11-repo"*) \
    pkgs_x11=($(echo $(tr ' ' '\n' <<< "dosbox
        feh
        geany
        hexchat
        keepassxc
        netsurf
        obconf openbox
        polybar
        tigervnc
        wireshark-gtk
        xfce4-terminal" | sort -u)))
 ;; esac

# Verbose pkg install
function pkg_install ()
{
    printf "Installing [%s]\n" $@ && echo
    yes | pkg install $@
}

# Upgrade termux & install packages
if type "termux-info" >/dev/null 2>&1; then

    # Upgrade all Termux Packages
    yes | pkg upgrade && {
        echo

        # Install regular packages.
        [[ ! -z "${pkgs}" ]] && {
            pkg_install ${pkgs[@]}
            echo
        }

        # Install X11 packages.
        [[ ! -z "${pkgs_x11}" ]] && {
            pkg_install ${pkgs_x11[@]}
            echo
        }
    }
fi
