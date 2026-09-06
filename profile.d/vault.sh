# Vault stack: key fingerprint → ssh_hash → get_hash → ansible-vault.
# Functions only. Session decrypt is $RCPATH/session.sh after the profile.d glob.

if command -v argon2 >/dev/null 2>&1; then
    function get_hash() {
        if [ -n "${ssh_hash[*]}" ]; then
            argon2 "${ssh_hash[1]:-$(printf "%-8s" ${USER})}" -i -l 128 -r -v 13 <<< "${@:-$RANDOM}"
        else
            awk '{print $1}' <(sha512sum <<< "${@:-$RANDOM}")
        fi
    }
else
    function get_hash() {
        awk '{print $1}' <(sha512sum <<< "${@:-$RANDOM}")
    }
fi
export -f get_hash

function ssh_fingerprint() {
    local Command_List=( assert_email run_command ssh-keygen )
    local Command_Check
    for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done
    local fp=( $(awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa" 2>/dev/null)) )
    [[ -n "${fp[*]}" ]] || return 1
    assert_email "${fp[1]}" || {
        local email_address=""
        run_command "ssh-keygen -lvf \"${HOME}/.ssh/id_rsa\" 2>/dev/null"
        echo; read -e -i "${USER:-$(whoami)}@" -p "Email Address: " email_address
        assert_email "${email_address}" && {
            run_command "ssh-keygen -c -C \"${email_address}\" -f \"${HOME}/.ssh/id_rsa\""
        }
    }
    awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa")
}
export -f ssh_fingerprint

function _vault_ready() {
    local script missing=() i
    script="${FUNCNAME[1]}"
    type get_hash >/dev/null 2>&1 || missing+=(get_hash)
    ensure_pip ansible-core --cmd ansible-vault || missing+=(ansible-vault)
    [[ "${#missing[@]}" -eq 0 ]] || {
        echo "${script} - requirement failure!"
        for i in "${missing[@]}"; do echo "> command \"${i}\" is missing."; done
        return 1
    }
    [[ -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]] || {
        echo "[${HOSTNAME}] Unable to use vault data!"
        return 1
    }
}

function _vault_passfile() {
    get_hash "${ssh_hash[0]}"
}

function vault_edit() {
    _vault_ready || return 1
    ansible-vault edit "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function vault_get() {
    _vault_ready || return 1
    ansible-vault view "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function vault_init() {
    local script missing=() i
    script="${FUNCNAME[0]}"
    type get_hash >/dev/null 2>&1 || missing+=(get_hash)
    ensure_pip ansible-core --cmd ansible-vault || missing+=(ansible-vault)
    [[ "${#missing[@]}" -eq 0 ]] || {
        echo "${script} - requirement failure!"
        for i in "${missing[@]}"; do echo "> command \"${i}\" is missing."; done
        return 1
    }
    [[ ! -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]] && {
        ansible-vault create "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
    } || {
        echo "[${HOSTNAME}] Unable to create new vault!"
        return 1
    }
}

function vault_protect() {
    _vault_ready || return 1
    ansible-vault encrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function vault_unprotect() {
    _vault_ready || return 1
    ansible-vault decrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function vssh () {
    local script missing=() id_rsa tmp_id
    script="${FUNCNAME[0]}"
    type vault_get >/dev/null 2>&1 || missing+=(vault_get)
    type run_command >/dev/null 2>&1 || missing+=(run_command)
    command -v ssh >/dev/null 2>&1 || missing+=(ssh)
    command -v jq >/dev/null 2>&1 || missing+=(jq)
    ensure_pip yq --cmd yq || missing+=(yq)
    [[ -n "${1}" && "${#missing[@]}" -eq 0 ]] || {
        echo "${script} - requirement failure!"
        [[ -z "${1}" ]] && echo "> user input is required!"
        for i in "${missing[@]}"; do echo "> command \"${i}\" is missing."; done
        return 1
    }
    id_rsa=$(yq --arg host "${1,,}" -c '.hosts | to_entries[] | select(.key==$host)["value"]' <(vault_get))
    [[ -n "${id_rsa}" && "${id_rsa}" != "null" ]] && {
        tmp_id="${TMPDIR:-/tmp}/${$}.id_rsa"
        trap 'rm -f "${tmp_id}"; trap - RETURN' RETURN
        install -m 400 -D <(yq -r '.private_key_content' <<< "${id_rsa}") "${tmp_id}"
        run_command "ssh -i \"${tmp_id}\" -oHostKeyAlgorithms=+ssh-dss $(yq -r '.ansible_ssh_user' <<< "${id_rsa}")@${1,,} $(printf '%q ' "${@:2}")"
    } || {
        echo -e "${script} - null data returned from vault!\n"
        jq -n "{\"hosts\":{\"${1,,}\":{\"ansible_ssh_user\":null,\"private_key_content\":null}}}"
        return 1
    }
}

export -f vault_edit vault_get vault_init vault_protect vault_unprotect vssh

alias vault=vault_get
alias vault_walk="yq -rc '[paths|map((\".\"+strings)//\"[]\")|join(\"\")]|unique[]' <(vault_get)"
