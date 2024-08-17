function Edit-Vault() {
    # Check if commands exist.
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( ansible-vault Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        # Extract vaulted data.
        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault edit "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file "${TMPDIR}/.vault"
        } || {
            echo "[${HOSTNAME}] Unable to edit vault data!"
            return 1
        }

    }
}

function Get-Vault() {
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( ansible-vault Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-f "${TMPDIR}/.vault") ]] && {
            ansible-vault view "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file "${TMPDIR}/.vault"
        } || {
            echo "[${HOSTNAME}] Unable to unvault data!"
            return 1
        }

    }
}

function Initialize-Vault() {
    # Check if commands exist.
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( ansible-vault Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        if [[ ! -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]]; then
            ansible-vault create "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file "${TMPDIR}/.vault"
        else
            echo "[${HOSTNAME}] Unable to create new vault!"
            return 1
        fi

    } || return 1
}

function vssh () {
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( ansible-vault jq ssh vault yq Run-Command )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ ( -z "${1}" ) || ( "${#test_result[@]}" != 0 ) ]] && {
        echo "${script} - requirement failure!"
        [[ -z "${1}" ]] && { echo "> user input is required!"; }
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {
        local id_rsa=`yq --arg host "${1,,}" -c '.hosts | to_entries[] | select(.key==$host)["value"]' <(Get-Vault)`

        [[ ! -z "${id_rsa}" ]] && {
            tmp_id="${TMPDIR:-/tmp}/${!}.id_rsa"
            #trap 'rm -rf "${tmp_id}"' RETURN
            install -m 400 -D <(yq -r '.private_key_content' <<< "${id_rsa}") "${tmp_id}"
            Run-Command "ssh -i \"${tmp_id}\" -oHostKeyAlgorithms=+ssh-dss $(yq -r '.ansible_ssh_user' <<< "${id_rsa}")@${1,,} \"${*:2}\""
        } || {
            echo -e "${script} - null data returned from vault!\n"
            jq -n '{"hosts":{"'''${1,,}'''":{"ansible_ssh_user":null,"private_key_content":null}}}'
            return 1;
        }
    }
}

# Export Functions
export -f Get-Vault
export -f vssh

# Load Alises
type Get-Vault >/dev/null 2>&1 && {
    alias vault=Get-Vault
    alias vault_walk="yq -rc '[paths|map((\".\"+strings)//\"[]\")|join(\"\")]|unique[]' <(vault)"
}
