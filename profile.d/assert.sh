# Small predicates for other scripts. No pip. Login is a no-op besides define.

function assert_in() {
    [[ $# -ge 2 ]] || {
        echo "${FUNCNAME[0]}: usage: ${FUNCNAME[0]} element \${array[@]}" >&2
        return 2
    }
    local needle="${1}" e
    shift
    for e in "${@}"; do
        [[ "${e}" == "${needle}" ]] && return 0
    done
    return 1
}

function assert_dns() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing Domain Name" >&2
        return 2
    }
    local re='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'
    [[ "${1}" =~ ${re} ]]
}

function assert_email() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing arguments" >&2
        return 2
    }
    local re='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    [[ "${1}" =~ ${re} ]]
}

function assert_ipv4() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing IPv4 address" >&2
        return 2
    }
    local IFS=.
    local -a o=( ${1} )
    [[ ${#o[@]} -eq 4 ]] || return 1
    local x
    for x in "${o[@]}"; do
        [[ "${x}" =~ ^[0-9]{1,3}$ ]] || return 1
        (( 10#${x} <= 255 )) || return 1
    done
    return 0
}

function assert_cidr() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing CIDR" >&2
        return 2
    }
    local ip="${1%/*}" pfx="${1#*/}"
    [[ "${1}" == */* && "${ip}" != "${1}" ]] || return 1
    [[ "${pfx}" =~ ^[0-9]{1,2}$ ]] || return 1
    (( 10#${pfx} <= 32 )) || return 1
    assert_ipv4 "${ip}"
}

function assert_cmd() {
    [[ $# -ge 1 ]] || {
        echo "${FUNCNAME[0]}: usage: ${FUNCNAME[0]} cmd [cmd…]" >&2
        return 2
    }
    local c
    for c in "${@}"; do
        type "${c}" >/dev/null 2>&1 || return 1
    done
    return 0
}

function assert_file() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing path" >&2
        return 2
    }
    [[ -f "${1}" ]]
}

function assert_dir() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing path" >&2
        return 2
    }
    [[ -d "${1}" ]]
}

export -f assert_in assert_dns assert_email \
    assert_ipv4 assert_cidr assert_cmd assert_file assert_dir
