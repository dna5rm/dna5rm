### Python Functions ###

# Lazy pip: only when a function actually needs the module. Login never bulk-installs.
# Usage: Ensure-Pip <pip-name> [--cmd bin] [--import mod]
function Ensure-Pip() {
    local pkg="${1}" cmd="" imp=""
    shift || return 1
    [[ -z "${pkg}" ]] && return 1
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            --cmd) cmd="${2}"; shift 2 ;;
            --import) imp="${2}"; shift 2 ;;
            *) shift ;;
        esac
    done
    [[ -n "${cmd}" ]] && command -v "${cmd}" >/dev/null 2>&1 && return 0
    [[ -n "${imp}" ]] && python -c "import ${imp}" >/dev/null 2>&1 && return 0
    [[ -z "${cmd}" && -z "${imp}" ]] && python -c "import ${pkg}" >/dev/null 2>&1 && return 0
    command -v python >/dev/null 2>&1 || { echo "Ensure-Pip: no python in PATH (activate venv)" >&2; return 1; }
    if type Run-Command >/dev/null 2>&1; then
        Run-Command "python -m pip install -q '${pkg}'"
    else
        python -m pip install -q "${pkg}"
    fi
}
export -f Ensure-Pip

function pyhttpd () {
    if Ensure-Pip uploadserver --import uploadserver; then
        python -m uploadserver --theme dark --directory "${1:-${PWD}}"
    else
        python -m http.server --directory "${1:-${PWD}}"
    fi
}

function pip-update () {
    python -m pip freeze --local | grep -v '^\-e' | cut -d = -f 1 | xargs -r -n1 python -m pip install -U
}
