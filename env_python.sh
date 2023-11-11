#!/bin/env -S bash

pkgs=(
    ansible-vault
    chromaterm
    Jinja2
    matplotlib mplfinance
    numpy
    openai
    pandas pip-search prompt_toolkit pyyaml
    speedtest-cli snmpclitools
    telegram
    uploadserver
    xmltodict
    yamllint yfinance youtube-dl yq
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
    cryptography
)

arch_gnulinux=(
    ansible-navigator asn1crypto
    bcrypt
    cffi cryptography
    f5-sdk
    idna
    jmespath jsnapy junos-eznc jxmlease
    MarkupSafe
    ncclient netaddr
    pan-python pan-os-python pandevice paramiko pyasn1 pycparser PyNaCl PyYAML
    scp sentencepiece six
    torch
)

function pkg_install ()
{
    printf "Installing [%s]\n" $@ && echo
    pip install $@ 2>> "${HOME}/$(basename ${0%.*}).log"
}

pip install --upgrade pip setuptools && {

    # Python modules - General
    pkg_install ${pkgs[@]}
    #pkg_install ${django_pkgs[@]}

    # Python modules - Arch Specific
    arch_pkgs=arch_$(uname -o | tr -cd '[a-zA-Z0-9_\-]' | awk '{print tolower($0)}')[@]
    [[ ! -z "${!arch_pkgs}" ]] && { echo; pkg_install ${!arch_pkgs}; }

    # Python modules - Rpi
    [[ -f "/etc/rpi-issue" ]] && { echo; pkg_install ${RPi_pkgs[@]}; }
}
