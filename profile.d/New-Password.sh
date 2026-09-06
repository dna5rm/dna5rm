# New-Password [length] [-a]
# Default length 16. Mix: a-zA-Z0-9!@#$%^&*()
# -a : alnum only (Wi-Fi / TACACS that reject punctuation)

function New-Password() {
    local alnum=0 length=16 arg
    for arg in "${@}"; do
        case "${arg}" in
            -a|--alnum) alnum=1 ;;
            -h|--help)
                echo "New-Password [length] [-a]  # default 16; -a = alnum only"
                return 0
                ;;
            *)
                [[ "${arg}" =~ ^[0-9]+$ ]] || {
                    echo "${FUNCNAME[0]}: length must be a positive integer" >&2
                    return 2
                }
                length="${arg}"
                ;;
        esac
    done
    (( length > 0 )) || {
        echo "${FUNCNAME[0]}: length must be > 0" >&2
        return 2
    }
    local set='a-zA-Z0-9!@#$%^&*()'
    (( alnum )) && set='a-zA-Z0-9'
    LC_ALL=C tr -dc "${set}" < /dev/urandom | head -c "${length}"
    echo
}

export -f New-Password
