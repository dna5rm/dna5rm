function Assert-ContainsElement () {
    # read input
    [[ -t 0 ]] && {
        local args=( ${@:2} )
        local query=( ${1} )
    } || {
        local args=( ${@} )
        local query=( $(</dev/stdin) )
    }

    [[ -z "${args[@]}" ]] && {
        # Make sure here-doc EOF is tab indented!
        sed "s/^[ \t]*//" <<-EOF; return 2
        # ${FUNCNAME[0]}: Asert if an array contains an element.

        ## Command Syntax
        > ArgIn: \`${FUNCNAME[0]} \${element} \${array}\`
        > StdIn: \`echo \${elements} | ${FUNCNAME[0]} \${array}\`

        | \$? | Exit Code Meaning       |
        | -- | --                      |
        |  0 | Contains element.       |
        |  1 | Does not have element.  |
        |  2 | Missing arguments.      |

	EOF
    } || {
        # loop query & unset i.
        local q && for q in ${query[@]}; do unset i
            # check against each args element.
            local e && for e in ${args[@]}; do
                # break if match or increment i.
                [[ "${e}" != "${q}" ]] && local i=$(( ${i:-0}+1 )) || break;
            done
            # return if i matches arg count.
            test "${#args[@]}" != "${i}" || return ${?}
        done
    }
}

function Assert-StrIsDns() {
    [ ${#} -eq 0 ] && { printf "%s: Missing Domain Name\n" "${FUNCNAME[0]}" >&2; return 2; }
    python3 -c "from fqdn import FQDN; import sys; sys.exit(0 if FQDN('${1}').is_valid else 1)" 2>/dev/null
    return ${?}
}

function Assert-StrIsEmail() {
    # Check if a string is an email address.
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 2
    local regex="^([A-Za-z]+[A-Za-z0-9]*\+?((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*)*)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"
    [[ "${1}" =~ ${regex} ]] && return 0 || return 1
}

# Export Functions
export -f Assert-ContainsElement
export -f Assert-StrIsDns
export -f Assert-StrIsEmail
