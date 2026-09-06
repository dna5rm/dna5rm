# openssl AES-256-CBC encrypt/decrypt. Passphrase never on argv (-k).
# crypt [passphrase] file [file…]
# Default passphrase (no leading non-file arg): whoami@hostname
# .enc → decrypt in place (shred ciphertext). else → encrypt, shred plaintext.

function crypt () {
    local user_input=( "${@}" ) func_error="" passphrase file out
    if ! command -v openssl >/dev/null 2>&1; then
        func_error="openssl executable not found."
    elif [[ "${#user_input[@]}" -eq 0 ]]; then
        func_error="Missing files input."
    fi
    [[ -n "${func_error}" ]] && {
        [[ "${0}" != -*"bash" ]] && echo >&2 "$(basename "${0}" 2>/dev/null):${FUNCNAME[0]} - ${func_error}" || echo >&2 "${FUNCNAME[0]} - ${func_error}"
        return 1
    }

    if [[ ! -f "${user_input[0]}" ]]; then
        passphrase="${user_input[0]}"
        unset 'user_input[0]'
    else
        passphrase="$(whoami)@$(hostname 2>/dev/null || echo unknown)"
    fi
    [[ "${#user_input[@]}" -gt 0 ]] || { echo >&2 "${FUNCNAME[0]} - Missing files input."; return 1; }

    _crypt_shred() {
        local f="${1}"
        if command -v shred >/dev/null 2>&1; then
            shred --force --zero --iterations 3 "${f}" 2>/dev/null || true
        fi
        rm -f "${f}"
    }

    for file in "${user_input[@]}"; do
        [[ -f "${file}" ]] || {
            printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Input is not a file!"
            return 1
        }
        if [[ "${file##*.}" != "enc" ]]; then
            out="${file}.enc"
            openssl enc -aes-256-cbc -e -md sha512 -pbkdf2 -iter 100000 -salt \
                -in "${file}" -out "${out}" -pass stdin <<<"${passphrase}" && {
                _crypt_shred "${file}"
                printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Successfully encrypted!"
            } || { rm -f "${out}"; return 1; }
        else
            out="${file%.enc}"
            openssl enc -aes-256-cbc -d -md sha512 -pbkdf2 -iter 100000 -salt \
                -in "${file}" -out "${out}" -pass stdin <<<"${passphrase}" && {
                _crypt_shred "${file}"
                printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Successfully decrypted!"
            } || { rm -f "${out}"; return 1; }
        fi
    done
}
export -f crypt
