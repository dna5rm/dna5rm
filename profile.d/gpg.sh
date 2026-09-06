# GnuPG helpers. Functions only; gpg at invoke, never at source.
# gpg_init / gpg_backup / gpg_restore / gpg_ls / gpg_import / gpg_export
# gpg_encrypt / gpg_decrypt / gpg_sign / gpg_verify
# gpg_encrypt_str / gpg_decrypt_str / gpg_sign_str / gpg_verify_str
# gpg_expire / gpg_rotate / gpg_revoke
# Default: public-key if a secret encryption key exists, else --symmetric.
# -s / --symmetric forces AES256 symmetric. -r / --recipient KEYID for pubkey.

function _gpg_usage() {
    sed "s/^[ \t]*//" <<-EOF
	gpg_init              homedir 700, install gpg.conf, generate Ed25519/Cv25519 if none
	gpg_backup [dir]            armor secret+public+ownertrust (default: \$HOME)
	gpg_restore [dir|file…]     import gpg_*.asc + ownertrust
	gpg_ls [-s] [query…]    public ring (default); -s secret keys
	gpg_import [file…]          public keys (file or stdin). Refuses PRIVATE KEY blocks
	gpg_export [keyid]          armor public key to stdout (default: your first secret)
	gpg_encrypt [-s] [-r KEY] path […]
	gpg_decrypt path […]
	gpg_encrypt_str [-s] [-r KEY] [text]     armor on stdout (else stdin)
	gpg_decrypt_str [armor]                plaintext on stdout (else stdin)
	gpg_sign [-c] path […]                 detached .asc (or --clearsign)
	gpg_verify path [sig]                  verify file or clearsigned
	gpg_sign_str [text]                    clearsign armor stdout
	gpg_verify_str [armor]                 verify stdin/args
	gpg_expire [keyid] [period]            default 2y; 0 = never. * = all subkeys
	gpg_rotate [keyid]                     new Cv25519 encrypt subkey (2y), expire old enc
	gpg_revoke [keyid] [--apply]           write revoke cert; --apply imports it
	  files -> name.gpg next to source; dirs -> name.tgz.gpg
	  *.gpg decrypts; *.tgz.gpg decrypts + tar -xz (cwd)
	EOF
}

function _gpg_tty() {
    local t
    t="$(tty 2>/dev/null || true)"
    if [[ -n "${t}" && "${t}" != "not a tty" ]]; then
        export GPG_TTY="${GPG_TTY:-${t}}"
    fi
}

function _gpg_ready() {
    if [[ "${1-}" == -h || "${1-}" == --help ]]; then
        _gpg_usage
        return 2
    fi
    command -v gpg >/dev/null 2>&1 || {
        echo "${FUNCNAME[1]}: gpg not installed" >&2
        return 1
    }
    _gpg_tty
}

function _gpg_homedir() {
    echo "${GNUPGHOME:-${HOME}/.gnupg}"
}

function _gpg_conf_src() {
    local p
    p="${RCPATH:-}/.gnupg/gpg.conf"
    [[ -f "${p}" ]] || p="${HOME}/Projects/dna5rm/.gnupg/gpg.conf"
    [[ -f "${p}" ]] && echo "${p}"
}

function _gpg_install_conf() {
    local dest src
    dest="$(_gpg_homedir)/gpg.conf"
    src="$(_gpg_conf_src)"
    [[ -n "${src}" ]] || {
        echo "${FUNCNAME[1]}: dna5rm gpg.conf missing" >&2
        return 1
    }
    cp -f "${src}" "${dest}"
    chmod 600 "${dest}"
}

function _gpg_has_secret() {
    gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec:'
}

function _gpg_conf_default_key() {
    local conf="${GNUPGHOME:-$HOME/.gnupg}/gpg.conf"
    [[ -r "${conf}" ]] || return 0
    awk 'tolower($1)=="default-key" {print $2; exit}' "${conf}"
}

function _gpg_preferred_key() {
    # GPG_KEY (session) then default-key in host gpg.conf. Template has neither.
    local k="${GPG_KEY:-}"
    [[ -z "${k}" ]] && k="$(_gpg_conf_default_key)"
    printf '%s' "${k}"
}

function _gpg_secret_colon() {
    if [[ -n "${1:-}" ]]; then
        gpg --list-secret-keys --with-colons -- "${1}" 2>/dev/null
    else
        gpg --list-secret-keys --with-colons 2>/dev/null
    fi
}

function _gpg_secret_colon_pref() {
    local pref listing
    pref="$(_gpg_preferred_key)"
    listing="$(_gpg_secret_colon "${pref}")"
    if [[ -z "${listing}" && -n "${pref}" ]]; then
        echo "gpg: preferred key ${pref} not in secret ring; using first secret" >&2
        listing="$(_gpg_secret_colon)"
    fi
    printf '%s' "${listing}"
}

function _gpg_primary_fpr() {
    _gpg_secret_colon_pref \
        | awk -F: '$1=="sec"{want=1} want && $1=="fpr"{print $10; exit}'
}

function _gpg_sign_fpr() {
    _gpg_secret_colon_pref \
        | awk -F: '
            $1=="ssb" && $12 ~ /s/ {need=1; next}
            need && $1=="fpr" {print $10; exit}
            $1=="sec" && $12 ~ /s/ {cand=1}
            cand && $1=="fpr" {sfpr=$10}
            END { if (sfpr) print sfpr }
        '
}

function _gpg_enc_fpr() {
    # encrypt-capable id on the preferred key, else first secret encrypt key
    _gpg_secret_colon_pref \
        | awk -F: '
            $1=="ssb" && $12 ~ /e/ {print $5; exit}
            $1=="sec" && $12 ~ /e/ {cand=$5}
            END { if (cand) print cand }
        '
}

function gpg_init() {
    _gpg_ready "$@" || return $?
    local home reply name email
    home="$(_gpg_homedir)"
    mkdir -p "${home}"
    chmod 700 "${home}"
    _gpg_install_conf || return 1

    if _gpg_has_secret; then
        echo "gpg_init: secret key already present."
        gpg_ls
        return 0
    fi

    name="${GPG_NAME:-${USER:-$(whoami)}}"
    email="${GPG_EMAIL:-}"
    if [[ -z "${email}" ]]; then
        read -r -p "User ID email: " email </dev/tty
    fi
    [[ -n "${email}" ]] || {
        echo "gpg_init: email required (or set GPG_EMAIL)" >&2
        return 1
    }

    # Passphrase via pinentry (GPG_TTY). Ed25519 cert/sign + Cv25519 encrypt, 2y.
    gpg --batch --status-fd 2 --generate-key <<EOF
Key-Type: EDDSA
Key-Curve: Ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: Cv25519
Subkey-Usage: encrypt
Name-Real: ${name}
Name-Email: ${email}
Expire-Date: 2y
%commit
EOF
    gpg_ls
}

function gpg_backup() {
    _gpg_ready "$@" || return $?
    local dir="${1:-${HOME}}"
    mkdir -p "${dir}"
    umask 0077
    gpg --armor --export-secret-keys > "${dir}/gpg_secret-key.asc"
    gpg --armor --export-secret-subkeys > "${dir}/gpg_secret-subkeys.asc"
    gpg --armor --export > "${dir}/gpg_public-key.asc"
    gpg --export-ownertrust > "${dir}/gpg_ownertrust.txt"
    chmod 600 "${dir}"/gpg_secret-*.asc "${dir}/gpg_ownertrust.txt" 2>/dev/null || true
    echo "gpg_backup: ${dir}/gpg_{secret-key,secret-subkeys,public-key}.asc + gpg_ownertrust.txt"
}

function gpg_restore() {
    _gpg_ready "$@" || return $?
    local home dir f
    home="$(_gpg_homedir)"
    mkdir -p "${home}"
    chmod 700 "${home}"
    _gpg_install_conf || true

    if [[ $# -eq 0 ]]; then
        dir="${HOME}"
        set -- "${dir}"/gpg_*.asc
    elif [[ $# -eq 1 && -d "${1}" ]]; then
        dir="${1}"
        set -- "${dir}"/gpg_*.asc
    fi

    [[ $# -gt 0 && -e "${1}" ]] || {
        echo "gpg_restore: no gpg_*.asc to import" >&2
        return 1
    }
    for f in "$@"; do
        [[ -f "${f}" ]] || continue
        gpg --import "${f}"
    done
    dir="$(dirname -- "${1}")"
    if [[ -f "${dir}/gpg_ownertrust.txt" ]]; then
        gpg --import-ownertrust "${dir}/gpg_ownertrust.txt"
    fi
    gpg_ls
}

function _gpg_paint() {
    # Color gpg --list-keys / verify text. No-op if not a tty or NO_COLOR.
    if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
        cat
        return 0
    fi
    local g r y c m b n d
    g="$(tput setaf 2 2>/dev/null || true)"
    r="$(tput setaf 1 2>/dev/null || true)"
    y="$(tput setaf 3 2>/dev/null || true)"
    c="$(tput setaf 6 2>/dev/null || true)"
    m="$(tput setaf 5 2>/dev/null || true)"
    b="$(tput setaf 4 2>/dev/null || true)"
    d="$(tput setaf 8 2>/dev/null || true)"
    n="$(tput sgr0 2>/dev/null || true)"
    [[ -n "${n}" ]] || { cat; return 0; }
    sed -e "s/^pub/${g}pub${n}/" \
        -e "s/^sec/${g}sec${n}/" \
        -e "s/^sub/${c}sub${n}/" \
        -e "s/^ssb/${c}ssb${n}/" \
        -e "s/^uid/${y}uid${n}/" \
        -e "s/\\[ultimate\\]/${g}[ultimate]${n}/g" \
        -e "s/\\[full\\]/${g}[full]${n}/g" \
        -e "s/\\[unknown\\]/${d}[unknown]${n}/g" \
        -e "s/\\[expired\\]/${r}[expired]${n}/g" \
        -e "s/\\[revoked\\]/${r}[revoked]${n}/g" \
        -e "s/\\[expires:[^]]*\\]/${y}&${n}/g" \
        -e "s/\\[[SCEA][SCEA]*\\]/${m}&${n}/g" \
        -e "s/0x[0-9A-Fa-f]\\{8,16\\}/${c}&${n}/g" \
        -e "s/Key fingerprint =/${b}Key fingerprint =${n}/" \
        -e "s/Good signature/${g}Good signature${n}/" \
        -e "s/BAD signature/${r}BAD signature${n}/"
}

function gpg_ls() {
    _gpg_ready "$@" || return $?
    local secret=0
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s|--secret) secret=1; shift ;;
            -h|--help) _gpg_usage; return 2 ;;
            --) shift; break ;;
            -*) echo "gpg_ls: unknown option ${1}" >&2; return 1 ;;
            *) break ;;
        esac
    done
    if [[ "${secret}" -eq 1 ]]; then
        gpg --list-secret-keys --keyid-format 0xlong --with-fingerprint -- "$@" | _gpg_paint
    else
        gpg --list-keys --keyid-format 0xlong --with-fingerprint -- "$@" | _gpg_paint
    fi
    return "${PIPESTATUS[0]}"
}

function gpg_import() {
    _gpg_ready "$@" || return $?
    local blob f
    if [[ $# -eq 0 ]]; then
        blob="$(cat)"
        if [[ "${blob}" == *"BEGIN PGP PRIVATE KEY"* ]]; then
            echo "gpg_import: refusing secret key on stdin (use gpg_restore)" >&2
            return 1
        fi
        printf '%s\n' "${blob}" | gpg --import
    else
        for f in "$@"; do
            [[ -f "${f}" ]] || { echo "gpg_import: not a file: ${f}" >&2; return 1; }
            if grep -q "BEGIN PGP PRIVATE KEY" "${f}" 2>/dev/null; then
                echo "gpg_import: refusing secret key in ${f} (use gpg_restore)" >&2
                return 1
            fi
            gpg --import -- "${f}"
        done
    fi
    gpg_ls
}

function gpg_export() {
    _gpg_ready "$@" || return $?
    local kid="${1:-}"
    if [[ -z "${kid}" ]]; then
        kid="$(_gpg_enc_fpr)"
        [[ -n "${kid}" ]] || {
            echo "gpg_export: no secret encrypt key; pass a key id" >&2
            return 1
        }
    fi
    gpg --armor --export -- "${kid}"
}

function _gpg_parse_mode() {
    # sets _gpg_sym _gpg_recip; leftover in "$@"
    _gpg_sym=0
    _gpg_recip=""
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -s|--symmetric) _gpg_sym=1; shift ;;
            -r|--recipient)
                [[ -n "${2-}" ]] || { echo "${FUNCNAME[1]}: ${1} needs a key id" >&2; return 1; }
                _gpg_recip="${2}"; shift 2
                ;;
            -h|--help) _gpg_usage; return 2 ;;
            --) shift; break ;;
            -*) echo "${FUNCNAME[1]}: unknown option ${1}" >&2; return 1 ;;
            *) break ;;
        esac
    done
    _gpg_rest=("$@")
}

function _gpg_enc_argv() {
    # prints words for gpg encrypt (no --output)
    local -a a=(gpg --yes)
    if [[ "${_gpg_sym}" -eq 1 ]]; then
        a+=(--cipher-algo AES256 --symmetric)
    elif [[ -n "${_gpg_recip}" ]]; then
        a+=(--recipient "${_gpg_recip}" --encrypt)
    else
        local kid
        kid="$(_gpg_enc_fpr)"
        if [[ -n "${kid}" ]]; then
            a+=(--recipient "${kid}" --encrypt)
        else
            a+=(--cipher-algo AES256 --symmetric)
        fi
    fi
    printf '%s\n' "${a[@]}"
}

function gpg_encrypt() {
    _gpg_ready "$@" || return $?
    local -a _gpg_rest gpg_enc
    _gpg_parse_mode "$@" || return $?
    [[ ${#_gpg_rest[@]} -gt 0 ]] || { _gpg_usage; return 1; }
    mapfile -t gpg_enc < <(_gpg_enc_argv)
    umask 0077

    local input out dir
    for input in "${_gpg_rest[@]}"; do
        [[ -e "${input}" ]] || { echo "gpg_encrypt: not found: ${input}" >&2; return 1; }
        dir="$(cd "$(dirname -- "${input}")" && pwd)"
        if [[ -f "${input}" ]]; then
            out="${dir}/$(basename -- "${input}").gpg"
            "${gpg_enc[@]}" --output "${out}" -- "${input}"
        elif [[ -d "${input}" ]]; then
            out="${dir}/$(basename -- "${input}").tgz.gpg"
            tar -czf - -C "$(dirname -- "${input}")" "$(basename -- "${input}")" \
                | "${gpg_enc[@]}" --output "${out}"
        else
            echo "gpg_encrypt: not a file or directory: ${input}" >&2
            return 1
        fi
        echo "${out}"
    done
}

function gpg_decrypt() {
    _gpg_ready "$@" || return $?
    [[ $# -gt 0 ]] || { _gpg_usage; return 1; }
    local input out dir base
    umask 0077
    for input in "$@"; do
        [[ -f "${input}" ]] || { echo "gpg_decrypt: not a file: ${input}" >&2; return 1; }
        base="$(basename -- "${input}")"
        dir="$(cd "$(dirname -- "${input}")" && pwd)"
        if [[ "${base}" == *.tgz.gpg ]]; then
            gpg --yes --decrypt -- "${input}" | tar --no-same-owner -xzf - -C "${dir}"
        elif [[ "${base}" == *.gpg ]]; then
            out="${dir}/${base%.gpg}"
            gpg --yes --output "${out}" --decrypt -- "${input}"
            echo "${out}"
        else
            echo "gpg_decrypt: expected *.gpg: ${input}" >&2
            return 1
        fi
    done
}

function gpg_encrypt_str() {
    _gpg_ready "$@" || return $?
    local -a _gpg_rest gpg_enc
    _gpg_parse_mode "$@" || return $?
    mapfile -t gpg_enc < <(_gpg_enc_argv)
    local text
    if [[ ${#_gpg_rest[@]} -gt 0 ]]; then
        text="${_gpg_rest[*]}"
    else
        text="$(cat)"
    fi
    printf '%s' "${text}" | "${gpg_enc[@]}" --armor
}

function gpg_decrypt_str() {
    _gpg_ready "$@" || return $?
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$*" | gpg --yes --decrypt
    else
        gpg --yes --decrypt
    fi
}

function _gpg_enc_sub_fprs() {
    gpg --list-secret-keys --with-colons 2>/dev/null \
        | awk -F: '$1=="ssb" && $12 ~ /e/ {want=1; next} want && $1=="fpr" {print $10; want=0}'
}

function gpg_sign() {
    _gpg_ready "$@" || return $?
    local clearsign=0 input out dir
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -c|--clearsign) clearsign=1; shift ;;
            -h|--help) _gpg_usage; return 2 ;;
            --) shift; break ;;
            -*) echo "gpg_sign: unknown option ${1}" >&2; return 1 ;;
            *) break ;;
        esac
    done
    [[ $# -gt 0 ]] || { _gpg_usage; return 1; }
    umask 0077
    for input in "$@"; do
        [[ -f "${input}" ]] || { echo "gpg_sign: not a file: ${input}" >&2; return 1; }
        dir="$(cd "$(dirname -- "${input}")" && pwd)"
        out="${dir}/$(basename -- "${input}").asc"
        if [[ "${clearsign}" -eq 1 ]]; then
            gpg --yes --clearsign --output "${out}" -- "${input}"
        else
            gpg --yes --detach-sign --armor --output "${out}" -- "${input}"
        fi
        echo "${out}"
    done
}

function gpg_verify() {
    _gpg_ready "$@" || return $?
    [[ $# -gt 0 ]] || { _gpg_usage; return 1; }
    if [[ $# -ge 2 ]]; then
        gpg --verify -- "${2}" "${1}" 2>&1 | _gpg_paint
    else
        gpg --verify -- "${1}" 2>&1 | _gpg_paint
    fi
    return "${PIPESTATUS[0]}"
}

function gpg_sign_str() {
    _gpg_ready "$@" || return $?
    local text
    if [[ $# -gt 0 ]]; then
        text="$*"
    else
        text="$(cat)"
    fi
    printf '%s' "${text}" | gpg --clearsign
}

function gpg_verify_str() {
    _gpg_ready "$@" || return $?
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$*" | gpg --verify 2>&1 | _gpg_paint
        return "${PIPESTATUS[1]}"
    else
        gpg --verify 2>&1 | _gpg_paint
        return "${PIPESTATUS[0]}"
    fi
}

function gpg_expire() {
    _gpg_ready "$@" || return $?
    local key period="${2:-2y}"
    key="${1:-$(_gpg_primary_fpr)}"
    [[ -n "${key}" ]] || { echo "gpg_expire: no secret key" >&2; return 1; }
    gpg --quick-set-expire "${key}" "${period}" '*'
    gpg_ls -s
}

function gpg_rotate() {
    _gpg_ready "$@" || return $?
    local key old new f
    key="${1:-$(_gpg_primary_fpr)}"
    [[ -n "${key}" ]] || { echo "gpg_rotate: no secret key" >&2; return 1; }
    mapfile -t old < <(_gpg_enc_sub_fprs)
    gpg --quick-add-key "${key}" cv25519 encr 2y || return 1
    mapfile -t new < <(_gpg_enc_sub_fprs)
    for f in "${old[@]}"; do
        [[ -n "${f}" ]] || continue
        gpg --quick-set-expire "${key}" seconds=1 "${f}" || true
    done
    echo "gpg_rotate: new encrypt subkey added; previous encrypt subkeys expire in 1s"
    gpg_ls -s
}

function gpg_revoke() {
    _gpg_ready "$@" || return $?
    local apply=0 key out
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --apply) apply=1; shift ;;
            -h|--help) _gpg_usage; return 2 ;;
            -*) echo "gpg_revoke: unknown option ${1}" >&2; return 1 ;;
            *) break ;;
        esac
    done
    key="${1:-$(_gpg_primary_fpr)}"
    [[ -n "${key}" ]] || { echo "gpg_revoke: no secret key" >&2; return 1; }
    umask 0077
    out="${HOME}/gpg_revoke-${key: -8}.asc"
    if [[ ! -s "${out}" ]]; then
        printf '%s\n' y 0 "gpg_revoke" y | gpg --no-tty --command-fd 0 --status-fd 2 --gen-revoke "${key}" > "${out}"
        chmod 600 "${out}"
    fi
    echo "gpg_revoke: ${out}"
    if [[ "${apply}" -eq 1 ]]; then
        gpg --import -- "${out}"
        echo "gpg_revoke: imported. Publish gpg_export and this cert."
    else
        echo "gpg_revoke: not imported. gpg_revoke --apply to apply locally."
    fi
}
