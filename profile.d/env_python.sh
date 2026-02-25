### Python Functions ###

# Aliases
#alias pyhttp="python3 -m http.server --directory \"${1:-${PWD}}\""

function pyhttpd () {
    # Check if uploadserver is installed.
    python3 -c 'import uploadserver' 2> /dev/null

    # Run tempoary HTTP server.
    [[ ${?} -eq 0 ]] && {
        # Ref: https://github.com/Densaugeo/uploadserver/blob/master/README.md
        python3 -m uploadserver --theme dark --directory "${1:-${PWD}}"
    } || {
        python3 -m http.server --directory "${1:-${PWD}}"
    }
}


# Update every module
function pip-update ()
{
    if [[ "$(whereis pip | wc -w)" -gt "1" ]]; then
        pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 pip install -U
    else
        echo "ERR: pip-update conditions not met."
    fi
}

# Use pip_search instead of the native search
alias pip='function _pip()
{
    if [ $1 = "search" ]; then
        pip_search "$2"
    else
        pip "$@"
        fi
}; _pip'
