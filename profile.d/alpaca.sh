function ask_alpaca()
{
    [[ ! -z "${1}" ]] && {
        [[ "$(type -t alpaca)" == "file" ]] && {
            [[ ! -z "${alpaca_model}" ]] && {
                printf "[ $(date) ]\n\n${FUNCNAME[0]}:task: \"${1}\"\n\n" >> "${HOME}/${FUNCNAME[0]}.log"
                alpaca -m "${alpaca_model}" --color --temp 0.9 \
                 --prompt "Write a brief response that appropriately completes the request." \
                 --file <(echo "${1}") 2>> "${HOME}/${FUNCNAME[0]}.log" | tee -a "${HOME}/${FUNCNAME[0]}.log"
            } || {
                echo "${FUNCNAME[0]}: The variable \"\${alpaca_model}\" is not set..."
            }
        } || {
            echo "${FUNCNAME[0]}: Missing \"alpaca\" executable..."
        }
    } || {
        printf "${FUNCNAME[0]}: Query the Alpaca LLM...\n\n"
        echo "Example>> ${FUNCNAME[0]} \"What is $(uname -s)?\""
    }
}
