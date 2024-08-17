if command -v argon2 &> /dev/null && [ -n "${ssh_hash[@]}" ]; then
    # Return a seeded argon2 hash using ssh_hash of a string.
    function Get-Hash() {
        argon2 "${ssh_hash[1]:-$(printf "%-8s" ${USER})}" -i -l 128 -r -v 13 <<< "${@:-$RANDOM}"
    }
else
    # Return a sha512 hash using ssh_hash of a string.
    function Get-Hash() {
        awk '{print $1}' <(sha512sum <<< "${@:-$RANDOM}")
    }
fi

# Export Function
export -f Get-Hash
