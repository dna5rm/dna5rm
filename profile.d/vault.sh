# # Get vault password file for ansible-vault.
# echo ansible-vault argon2 yq | Assert-ContainsElement ${cmd_avail[@]} > /dev/null 2>&1 && {

#     [[ ! -f "${HOME}/.vault" ]] && {
#         read -rs -t 15 -p "Vault Passphrase: " passphrase
#         install -m 400 -D <(argon2 "$(printf "%-8s" ${USER:-$(whoami)})" -i -l 128 -r -v 13 <<< "${passphrase:-${HOSTNAME,,}}") "${TMPDIR}/.vault"
#         unset passphrase && echo
#     } || { ln -sf "${HOME}/.vault" "${TMPDIR}/.vault"; }

#     # Create a vault if it does not exist.
#     [[ ! -f "${HOME}/.${USER:-loginrc}.vault" ]] && {
#         ansible-vault create "${HOME}/.${USER:-loginrc}.vault" --vault-password-file "${TMPDIR}/.vault"
#     }

#     # extract sensitive credentials.
#     vault > /dev/null 2>&1 && {
#         # ssh private key & agent.
#         install -m 400 <(yq -r '.["'''${USER:-$(whoami)}'''"]["private_key_content"]' <(vault)) "${TMPDIR}/id_rsa"
#         eval $(ssh-agent) && [[ -s "${TMPDIR}/id_rsa" ]] && { timeout 1s ssh-add -k "${TMPDIR}/id_rsa" || alias id_rsa="ssh-add -k \"${TMPDIR}/id_rsa\""; }
#         echo

#         # .cloginrc for rancid.
#         sed -e 's/^[ \t]*//' <<-EOF > "${TMPDIR}/.cloginrc" && chmod 400 "${TMPDIR}/.cloginrc"
#         ## Generated from ~/.${USER:-$(whoami)}.vault :: $(date) ##
#         add user        *       ${USER:-$(whoami)}
#         add password    *       $(printf "%q\t%q" $(yq -r '.["'''${USER:-$(whoami)}'''"]|[.tacacs,.tacacs]|@tsv' <(vault)))
#         add method      *       ssh telnet
# 	EOF
#     }
# }

function Edit-Vault() {
    # Check if commands exist.
    local Command_List=( ansible-vault Get-Hash )
    local Command_Check=""; for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done && {

        # Extract vaulted data.
        if [[ -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]]; then
            ansible-vault edit "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        else
            echo "[${HOSTNAME}] Unable to edit vaulted data!"
            return 1
        fi

    } || return 1
}

function Get-Vault() {
    # Check if commands exist.
    local Command_List=( ansible-vault Get-Hash )
    local Command_Check=""; for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done && {

        if [[ -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]]; then
            ansible-vault view "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        else
            echo "[${HOSTNAME}] Unable to get vaulted data!"
            return 1
        fi

    } || return 1
}

function Initialize-Vault() {
    # Check if commands exist.
    local Command_List=( ansible-vault Get-Hash )
    local Command_Check=""; for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done && {

        if [[ ! -f "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]]; then
            ansible-vault create "${HOME}/.${USER:-$(whoami)}.vault" --vault-password-file <(Get-Hash "${ssh_hash[0]}")
        else
            echo "[${HOSTNAME}] Unable to create new vault file!"
            return 1
        fi

    } || return 1
}
