# openssl AES-256-CBC encrypt/decrypt. Stock openssl enc only (no AEAD).
# File: one ASCII header line, then openssl Salted__ blob.
#   CRYPT/1 aes-256-cbc pbkdf2 sha512 600000
# Unheadered / old Salted__ files are refused.
# crypt [-k|--keep] [-p passphrase] [--prompt] file [file…]
# Default passphrase: whoami@hostname. .enc decrypts; else encrypts.

_CRYPT_HDR="CRYPT/1 aes-256-cbc pbkdf2 sha512 600000"
_CRYPT_CIPHER="aes-256-cbc"
_CRYPT_MD="sha512"
_CRYPT_ITER="600000"

function _crypt_shred() {
    local f="${1}"
    if command -v shred >/dev/null 2>&1; then
        shred --force --zero --iterations 3 "${f}" 2>/dev/null || true
    fi
    rm -f "${f}"
}

function crypt () {
    local keep=0 prompt=0 passphrase="" file out tmp hdr cipher kdf md iter func_error=""
    local -a files=()

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -k|--keep) keep=1; shift ;;
            --prompt) prompt=1; shift ;;
            -p|--pass)
                [[ -n "${2}" ]] || { echo >&2 "${FUNCNAME[0]}: ${1} needs a passphrase"; return 1; }
                passphrase="${2}"; shift 2
                ;;
            -h|--help)
                sed "s/^[ 	]*//" <<-EOF
				${FUNCNAME[0]} [-k|--keep] [-p passphrase] [--prompt] file [file…]
				  crypt file.txt
				  crypt -p "my passphrase" file.txt
				  crypt --prompt file.txt
				  crypt file.txt.enc
				  Default pass: whoami@hostname. .enc decrypts; else encrypts and shreds.
				  Header: ${_CRYPT_HDR}
				  -k / --keep   keep the source file (do not shred)
				  -p / --pass   passphrase (then every arg is a file)
				  --prompt      read passphrase from tty (hidden; better than -p)
				EOF
                return 0
                ;;
            --) shift; files+=( "$@" ); break ;;
            -*) echo >&2 "${FUNCNAME[0]}: unknown option ${1}"; return 1 ;;
            *) break ;;
        esac
    done

    if ! command -v openssl >/dev/null 2>&1; then
        func_error="openssl executable not found."
    elif [[ $# -eq 0 && ${#files[@]} -eq 0 ]]; then
        func_error="Missing files input."
    fi
    [[ -n "${func_error}" ]] && { echo >&2 "${FUNCNAME[0]} - ${func_error}"; return 1; }

    if [[ ${prompt} -eq 1 ]]; then
        printf "Passphrase: " >/dev/tty
        read -s passphrase </dev/tty
        printf "\n" >/dev/tty
        [[ -n "${passphrase}" ]] || { echo >&2 "${FUNCNAME[0]} - empty passphrase"; return 1; }
    fi

    files+=( "$@" )
    if [[ -z "${passphrase}" && ${#files[@]} -gt 0 && ! -f "${files[0]}" ]]; then
        passphrase="${files[0]}"
        files=( "${files[@]:1}" )
    fi
    [[ -z "${passphrase}" ]] && passphrase="$(whoami)@$(hostname 2>/dev/null || echo unknown)"
    [[ ${#files[@]} -gt 0 ]] || { echo >&2 "${FUNCNAME[0]} - Missing files input."; return 1; }

    for file in "${files[@]}"; do
        [[ -f "${file}" ]] || {
            printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Input is not a file!"
            return 1
        }
        if [[ "${file##*.}" != "enc" ]]; then
            out="${file}.enc"
            tmp="$(mktemp "${TMPDIR:-/tmp}/crypt.XXXXXX")"
            openssl enc -"${_CRYPT_CIPHER}" -e -md "${_CRYPT_MD}" -pbkdf2 -iter "${_CRYPT_ITER}" -salt \
                -in "${file}" -out "${tmp}" -pass stdin <<<"${passphrase}" && {
                { printf '%s\n' "${_CRYPT_HDR}"; cat "${tmp}"; } > "${out}"
                rm -f "${tmp}"
                [[ ${keep} -eq 1 ]] || _crypt_shred "${file}"
                printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Successfully encrypted!"
            } || { rm -f "${tmp}" "${out}"; return 1; }
        else
            out="${file%.enc}"
            hdr="$(head -n 1 "${file}")"
            [[ "${hdr}" == CRYPT/1\ * ]] || {
                echo >&2 "${FUNCNAME[0]}: ${file}: missing CRYPT/1 header (old Salted__ files are unsupported)"
                return 1
            }
            read -r _tag cipher kdf md iter <<< "${hdr}"
            [[ "${_tag}" == "CRYPT/1" && "${cipher}" == "aes-256-cbc" && "${kdf}" == "pbkdf2" && "${md}" == "sha512" && "${iter}" =~ ^[0-9]+$ ]] || {
                echo >&2 "${FUNCNAME[0]}: ${file}: bad CRYPT/1 header"
                return 1
            }
            tmp="$(mktemp "${TMPDIR:-/tmp}/crypt.XXXXXX")"
            tail -n +2 "${file}" > "${tmp}"
            openssl enc -"${cipher}" -d -md "${md}" -pbkdf2 -iter "${iter}" \
                -in "${tmp}" -out "${out}" -pass stdin <<<"${passphrase}" && {
                rm -f "${tmp}"
                [[ ${keep} -eq 1 ]] || _crypt_shred "${file}"
                printf "[%s:%s] %s\n" "${FUNCNAME[0]}" "$(basename "${file}")" "Successfully decrypted!"
            } || { rm -f "${tmp}" "${out}"; return 1; }
        fi
    done
}
export -f crypt _crypt_shred
