# Vault stack: key fingerprint → ssh_hash → Get-Hash → ansible-vault.
# Functions only. Session decrypt is in .bashrc after the profile.d glob.

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

function Edit-Vault() {
    # Check if commands exist.
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        Ensure-Pip ansible-core --cmd ansible-vault || return 1
        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault edit "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
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

    local test_cmds=( Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        Ensure-Pip ansible-core --cmd ansible-vault || return 1
        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault view "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
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

    local test_cmds=( Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        Ensure-Pip ansible-core --cmd ansible-vault || return 1
        [[ (! -f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault create "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        } || {
            echo "[${HOSTNAME}] Unable to create new vault!"
            return 1
        }

    } || return 1
}

function Protect-Vault() {
    # Check if commands exist.
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        Ensure-Pip ansible-core --cmd ansible-vault || return 1
        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault encrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        } || {
            echo "[${HOSTNAME}] Unable perform vault action!"
            return 1
        }

    }
}

function Unprotect-Vault() {
    # Check if commands exist.
    [[ "${0}" != -*"bash" ]] && {
        local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    } || {
        local script="${FUNCNAME[0]}"
    }

    local test_cmds=( Get-Hash )
    local test_result=()
    mapfile -t test_result< <(for i in "${test_cmds[@]}"; do command -v "${i}" &> /dev/null || echo "${i}"; done)

    [[ "${#test_result[@]}" != 0 ]] && {
        echo "${script} - requirement failure!"
        for missing in "${test_result[@]}"; do
            echo "> command \"${missing}\" is missing."
        done; return 1
    } || {

        Ensure-Pip ansible-core --cmd ansible-vault || return 1
        [[ (-f "${HOME}/.${USER:-$(whoami)}.vault") && (-n "${ssh_hash[*]}") ]] && {
            ansible-vault decrypt "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        } || {
            echo "[${HOSTNAME}] Unable perform vault action!"
            return 1
        }

    }
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
            trap 'rm -rf "${tmp_id}"; trap - RETURN' RETURN
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

# Aliases only (no Get-Vault call). Session decrypt lives in .bashrc after the glob.
type Get-Vault >/dev/null 2>&1 && {
    alias vault=Get-Vault
    alias vault_walk="yq -rc '[paths|map((\".\"+strings)//\"[]\")|join(\"\")]|unique[]' <(vault)"
}
