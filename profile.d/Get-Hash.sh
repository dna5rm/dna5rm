function Get-Hash() {
    # check if commands exist.
    local Command_List=( argon2 )
    local Command_Check=""; for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done && {
        # Return a seeded argon2 hash using ssh_hash of a string, if empty return random hash.
        argon2 "${ssh_hash[1]:-$(printf "%-8s" ${USER})}" -i -l 128 -r -v 13 <<< "${@:-$RANDOM}"
    } || return 1
}