alias show='sudo debug.sh'
alias ls='ls --color=auto' 2>/dev/null
alias nmap='nmap -Pn -oG -'
alias pico=nano
alias rot13="tr a-zA-Z n-za-mN-ZA-M"
alias toilet="toilet --directory ${HOME}/.fonts/figlet"
alias vim=nvim

function ask_alpaca()
{
    if [[ ! -z "${1}" ]] &&[[ "$(type -t alpaca)" == "file" ]] && [[ -e "${HOME}/models/ggml-alpaca-7b-q4.bin" ]]; then
        alpaca -m "${HOME}/models/ggml-alpaca-7b-q4.bin" --color --temp 0.9 \
         --prompt "Write a brief response that appropriately completes the request." \
         --file <(echo "${1}") 2>> "${FUNCNAME[0]}.log" | tee -a "${FUNCNAME[0]}.log"
    else
        printf "${FUNCNAME[0]}: Query the Alpaca LLM...\n\n"
        echo "Example>> ${FUNCNAME[0]} \"What is $(uname -s)?\""
    fi
}
