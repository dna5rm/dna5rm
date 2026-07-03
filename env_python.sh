#!/bin/bash

# Python module installer for virtual environment bootstrap.
# Called by .bashrc -> env_python.sh after venv creation.

pkgs=(
    ansible ansible-lint ansible-navigator asn1crypto
    bcrypt
    cdiff cffi chromaterm cryptography
    f5-sdk fqdn
    idna
    j2cli Jinja2 jmespath jsnapy junos-eznc jxmlease
    MarkupSafe
    ncclient netaddr netutils numpy
    openai
    pandas pandevice pan-os-python pan-python paramiko pip-search prompt_toolkit pyasn1 pycparser pylint PyNaCl PyYAML
    scp sentencepiece six speedtest-cli snmpclitools
    telegram
    uploadserver
    yamllint yfinance
)

django_pkgs=(
    Django django-crispy-forms django-mathfilters
    asgiref gunicorn sqlparse timeago
)

rpi_pkgs=(
    RPi.GPIO enviroplus smbus
)

# Architecture-specific extras (not in pkgs above)
arch_gnulinux=(torch)

pkg_install() {
    printf "Installing [%s]\n" "$@" && echo
    pip install "$@" 2>> "${HOME}/$(basename "${0%.*}").log"
}

# Android: tokenizers needs --no-binary
if [[ "$(uname -o)" == "Android" ]]; then
    export ANDROID_API_LEVEL=$(getprop ro.build.version.sdk)
    pip install tokenizers --no-binary :all:
fi

pip install --upgrade ansible-vault pip setuptools xmltodict yq && {

    pkg_install "${pkgs[@]}"
    # pkg_install "${django_pkgs[@]}"

    # Architecture-specific packages
    arch_key="arch_$(uname -o | tr -cd '[:alnum:]-_' | awk '{print tolower($0)}')"
    if [[ -n "${!arch_key}" ]]; then
        echo
        pkg_install "${!arch_key}"
    fi

    # Raspberry Pi
    if [[ -f "/etc/rpi-issue" ]]; then
        echo
        pkg_install "${rpi_pkgs[@]}"
    fi
}
