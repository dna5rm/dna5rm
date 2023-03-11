#!/bin/env -S bash

pkgs=(
    Jinja2
    matplotlib mplfinance
    numpy
    openai
    pandas pip-search prompt_toolkit
    speedtest-cli snmpclitools
    telegram
    uploadserver
    xmltodict
    yamllint yfinance youtube-dl
)

django_pkgs=(
    asgiref
    Django django-crispy-forms django-mathfilters
    gunicorn
    sqlparse
    timeago
)

RPi_pkgs=(
    RPi.GPIO
    enviroplus
    smbus
)

arch_android=(
    cryptography==3.4.7
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
    pip install $@ 2>> "${HOME}/$(basename ${0%.*}).log"
}

pip install --upgrade pip setuptools && {

    arch_pkgs=arch_$(uname -o | tr -cd '[a-zA-Z0-9_\-]' | awk '{print tolower($0)}')[@]
    [[ ! -z "${!arch_pkgs}" ]] && {
        echo
        pkg_install ${!arch_pkgs}
    }

    pkg_install ${pkgs[@]}
    #pkg_install ${django_pkgs[@]}

    # Raspberry Pi
    [[ -f "/etc/rpi-issue" ]] && {
        pkg_install ${RPi_pkgs[@]}
    }
}
