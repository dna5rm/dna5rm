# Small predicates for other scripts. No pip. Login is a no-op besides define.

function Assert-ContainsElement() {
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

function Assert-StrIsDns() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing Domain Name" >&2
        return 2
    }
    local re='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$'
    [[ "${1}" =~ ${re} ]]
}

function Assert-StrIsEmail() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing arguments" >&2
        return 2
    }
    local re='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    [[ "${1}" =~ ${re} ]]
}

function Assert-StrIsIpv4() {
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

function Assert-StrIsCidr() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing CIDR" >&2
        return 2
    }
    local ip="${1%/*}" pfx="${1#*/}"
    [[ "${1}" == */* && "${ip}" != "${1}" ]] || return 1
    [[ "${pfx}" =~ ^[0-9]{1,2}$ ]] || return 1
    (( 10#${pfx} <= 32 )) || return 1
    Assert-StrIsIpv4 "${ip}"
}

function Assert-Command() {
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

function Assert-File() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing path" >&2
        return 2
    }
    [[ -f "${1}" ]]
}

function Assert-Dir() {
    [[ $# -eq 1 && -n "${1}" ]] || {
        echo "${FUNCNAME[0]}: Missing path" >&2
        return 2
    }
    [[ -d "${1}" ]]
}

export -f Assert-ContainsElement Assert-StrIsDns Assert-StrIsEmail \
    Assert-StrIsIpv4 Assert-StrIsCidr Assert-Command Assert-File Assert-Dir
