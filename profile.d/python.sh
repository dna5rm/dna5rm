### Python Functions ###

# Aliases
#alias pyhttp="python3 -m http.server --directory ${HOME}/public_html"

function pyhttpd () {
    [[ -d "${HOME}/public_html" ]] || mkdir -p "${HOME}/public_html"
    python3 -c 'import uploadserver' 2> /dev/null
    [[ ${?} -eq 0 ]] && {
        # Ref: https://github.com/Densaugeo/uploadserver/blob/master/README.md
        python3 -m uploadserver --theme dark --directory "${HOME}/public_html"
    } || {
        python3 -m http.server --directory "${HOME}/public_html"
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
