# Report if vault is not encrypted.
awk 'NR==1 && /ANSIBLE_VAULT/ {exit 0} NR>1 {exit 1}' "${HOME}/.${USER:-$(whoami)}.vault" || {
    echo "[~/.${USER:-$(whoami)}.vault] Vault does not exist or is not protected!"
}

# Report unpushed changes to any project.
[[ `command -v proj_status` ]] && {
    proj_status && sleep 3
}

# Output installed pip packages.
if [[ -d "${HOME}/Projects" ]] && [[ ! -z "${python_ver}" ]]
 then python -m pip freeze > "${HOME}/.local/venv${python_ver}/requirements.txt"
fi
