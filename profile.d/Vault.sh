# Vault stack: key fingerprint → ssh_hash → Get-Hash → ansible-vault.
# Functions only. Session decrypt is $RCPATH/session.sh after the profile.d glob.

if command -v argon2 >/dev/null 2>&1; then
    function Get-Hash() {
        if [ -n "${ssh_hash[*]}" ]; then
            argon2 "${ssh_hash[1]:-$(printf "%-8s" ${USER})}" -i -l 128 -r -v 13 <<< "${@:-$RANDOM}"
        else
            awk '{print $1}' <(sha512sum <<< "${@:-$RANDOM}")
        fi
    }
else
    function Get-Hash() {
        awk '{print $1}' <(sha512sum <<< "${@:-$RANDOM}")
    }
fi
export -f Get-Hash

function Get-SshKeyFingerprint() {
    local Command_List=( Assert-StrIsEmail Run-Command ssh-keygen )
    local Command_Check
    for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done
    local fp=( $(awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa" 2>/dev/null)) )
    [[ -n "${fp[*]}" ]] || return 1
    Assert-StrIsEmail "${fp[1]}" || {
        local email_address=""
        Run-Command "ssh-keygen -lvf \"${HOME}/.ssh/id_rsa\" 2>/dev/null"
        echo; read -e -i "${USER:-$(whoami)}@" -p "Email Address: " email_address
        Assert-StrIsEmail "${email_address}" && {
            Run-Command "ssh-keygen -c -C \"${email_address}\" -f \"${HOME}/.ssh/id_rsa\""
        }
    }
    awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa")
}
export -f Get-SshKeyFingerprint

function _vault_ready() {
    local script missing=() i
    script="${FUNCNAME[1]}"
    type Get-Hash >/dev/null 2>&1 || missing+=(Get-Hash)
    Ensure-Pip ansible-core --cmd ansible-vault || missing+=(ansible-vault)
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
    Get-Hash "${ssh_hash[0]}"
}

function Edit-Vault() {
    _vault_ready || return 1
    ansible-vault edit "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function Get-Vault() {
    _vault_ready || return 1
    ansible-vault view "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function Initialize-Vault() {
    local script missing=() i
    script="${FUNCNAME[0]}"
    type Get-Hash >/dev/null 2>&1 || missing+=(Get-Hash)
    Ensure-Pip ansible-core --cmd ansible-vault || missing+=(ansible-vault)
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

function Protect-Vault() {
    _vault_ready || return 1
    ansible-vault encrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function Unprotect-Vault() {
    _vault_ready || return 1
    ansible-vault decrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(_vault_passfile)
}

function vssh () {
    local script missing=() id_rsa tmp_id
    script="${FUNCNAME[0]}"
    type Get-Vault >/dev/null 2>&1 || missing+=(Get-Vault)
    type Run-Command >/dev/null 2>&1 || missing+=(Run-Command)
    command -v ssh >/dev/null 2>&1 || missing+=(ssh)
    command -v jq >/dev/null 2>&1 || missing+=(jq)
    Ensure-Pip yq --cmd yq || missing+=(yq)
    [[ -n "${1}" && "${#missing[@]}" -eq 0 ]] || {
        echo "${script} - requirement failure!"
        [[ -z "${1}" ]] && echo "> user input is required!"
        for i in "${missing[@]}"; do echo "> command \"${i}\" is missing."; done
        return 1
    }
    id_rsa=$(yq --arg host "${1,,}" -c '.hosts | to_entries[] | select(.key==$host)["value"]' <(Get-Vault))
    [[ -n "${id_rsa}" && "${id_rsa}" != "null" ]] && {
        tmp_id="${TMPDIR:-/tmp}/${$}.id_rsa"
        trap 'rm -f "${tmp_id}"; trap - RETURN' RETURN
        install -m 400 -D <(yq -r '.private_key_content' <<< "${id_rsa}") "${tmp_id}"
        Run-Command "ssh -i \"${tmp_id}\" -oHostKeyAlgorithms=+ssh-dss $(yq -r '.ansible_ssh_user' <<< "${id_rsa}")@${1,,} $(printf '%q ' "${@:2}")"
    } || {
        echo -e "${script} - null data returned from vault!\n"
        jq -n "{\"hosts\":{\"${1,,}\":{\"ansible_ssh_user\":null,\"private_key_content\":null}}}"
        return 1
    }
}

export -f Edit-Vault Get-Vault Initialize-Vault Protect-Vault Unprotect-Vault vssh

alias vault=Get-Vault
alias vault_walk="yq -rc '[paths|map((\".\"+strings)//\"[]\")|join(\"\")]|unique[]' <(Get-Vault)"
