# Report unpushed changes to any project.
[[ `command -v proj_status` ]] && {
    proj_status && sleep 3
}

# Output installed pip packages.
if [[ -d "${HOME}/Projects" ]] && [[ ! -z "${python_ver}" ]]
 then python -m pip freeze > "${HOME}/.local/venv${python_ver}/requirements.txt"
fi
