#!/bin/env -S bash

pkgs=(
    Jinja2
    matplotlib mplfinance
    numpy
    openai
    pandas pip-search
    speedtest-cli snmpclitools
    telegram
    xmltodict
    yamllint yfinance youtube-dl
)

arch_gnulinux=(
    ansible ansible-pylibssh asn1crypto
    bcrypt
    cffi cryptography
    f5-sdk
    idna
    jsnapy junos-eznc jxmlease
    MarkupSafe
    ncclient netaddr
    pan-python pan-os-python pandevice paramiko pyasn1 pycparser PyNaCl PyYAML
    scp six
)

function pkg_install ()
{
    printf "Installing [%s]\n" $@ && echo
    pip install $@
}

pip install --upgrade pip && {

    pkg_install ${pkgs[@]}

    arch_pkgs=arch_$(uname -o | tr -cd '[a-zA-Z0-9_\-]' | awk '{print tolower($0)}')[@]
    [[ ! -z "${!arch_pkgs}" ]] && {
        echo
        pkg_install ${!arch_pkgs}
    }

}
