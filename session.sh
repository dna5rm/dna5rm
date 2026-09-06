# Session init — sourced from .bashrc AFTER profile.d.
# Needs Get-SshKeyFingerprint, Get-Vault, Ensure-Pip already defined.
# Do not source from the profile.d glob.

# Fingerprint + one vault decrypt. Never Run-Command Get-Vault (banner would land in yaml).
if [[ -z "${ssh_hash[*]}" && -f "${HOME}/.ssh/id_rsa" ]] && type Get-SshKeyFingerprint >/dev/null 2>&1; then
    export ssh_hash=( $(Get-SshKeyFingerprint) )
    [[ -z "${USER}" && -n "${ssh_hash[1]}" ]] && export USER="${ssh_hash[1]%@*}"
fi
if [[ -e "${HOME}/.${USER:-$(whoami)}.vault" && -n "${ssh_hash[*]}" ]] && type Get-Vault >/dev/null 2>&1; then
    type Ensure-Pip >/dev/null 2>&1 && Ensure-Pip yq --cmd yq
    _vault_tmp="${TMPDIR:-/tmp}/.vault.yaml"
    Get-Vault > "${_vault_tmp}" && chmod 600 "${_vault_tmp}"
    if command -v yq >/dev/null 2>&1 && yq -e '.env | keys | length > 0' "${_vault_tmp}" >/dev/null 2>&1; then
        eval "$(yq -r '.env | to_entries[] | "export " + .key + "=" + (.value|tostring|@sh)' "${_vault_tmp}")"
    else
        tput setaf 8 2>/dev/null
        echo "### No vaulted environmental variables found. ###"
        tput sgr0 2>/dev/null; echo
    fi
    if command -v clogin >/dev/null 2>&1 && command -v yq >/dev/null 2>&1; then
        _user="${USER:-$(whoami)}"
        _tac="${TACACS:-$(yq -r --arg u "${_user}" '.[$u].tacacs // empty' "${_vault_tmp}" 2>/dev/null)}"
        [[ -n "${_tac}" ]] && {
            umask 077
            printf 'add user * %s\nadd password * %s %s\nadd method * ssh telnet\n' \
                "${_user}" "${_tac}" "${_tac}" > "${TMPDIR}/.cloginrc"
        }
    fi
    rm -f "${_vault_tmp}"
    unset _vault_tmp _tac _user
elif [[ -n "${ssh_hash[*]}" ]] && type Initialize-Vault >/dev/null 2>&1; then
    echo -e "\n[${HOSTNAME}] Run the \"$(tput setaf 2 2>/dev/null)Initialize-Vault$(tput sgr0 2>/dev/null)\" shell function to create a vault.\n"
fi

# ssh-agent only on SSH, reuse if already live.
[[ -n "${SSH_CONNECTION}" && -n "${ssh_hash[*]}" ]] && {
    _agent_ok=0
    if [[ -n "${SSH_AUTH_SOCK}" ]]; then
        ssh-add -l >/dev/null 2>&1
        [[ $? -ne 2 ]] && _agent_ok=1
    fi
    [[ ${_agent_ok} -eq 0 ]] && eval "$(ssh-agent)"
    alias id_rsa="ssh-add -k \"${HOME}/.ssh/id_rsa\""
    unset _agent_ok
}
