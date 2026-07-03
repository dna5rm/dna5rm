### Bash Prompt ###
# Powerline blocks. Subtle separators. Git text only.

function set_prompt() {
    local last_exit=$?

    local bold="\[\e[1m\]"
    local baby_blue="\[\e[38;5;81m\]"      # #8be9fd
    local green="\[\e[38;5;82m\]"          # #50fa7b
    local yellow="\[\e[38;5;228m\]"        # #f1fa8c
    local orange="\[\e[38;5;215m\]"        # #ffb86c
    local red="\[\e[38;5;196m\]"           # #ff5555
    local pink="\[\e[38;5;212m\]"          # #ff79c6
    local sep_color="\[\e[38;5;243m\]"     # subtle gray separator
    local dark_bg="\[\e[48;5;236m\]"       # #282a36
    local red_bg="\[\e[48;5;196m\]"        # #ff5555
    local reset="\[\e[0m\]"

    local sep=$(printf "\u276f")            # ❯
    local p=""

    # Leading arrow
    p="${p}\[${reset}${sep_color}${sep}${reset}\] "

    # Segment 1: Exit code (only shown when non-zero)
    if [[ ${last_exit} -ne 0 ]]; then
        p="${p}\[${red_bg}${bold}${baby_blue}\] ${last_exit} "
        local prev="${sep_color}"
    else
        local prev=""
    fi

    # Segment 2: user@host - bold baby blue on dark bg
    if [[ -n "${prev}" ]]; then
        p="${p}\[${prev}${dark_bg}${sep}${reset}\]"
    fi
    p="${p}\[${dark_bg}${bold}${baby_blue}\]\u@\h "

    # Segment 3: venv (only shown when active) - orange on dark bg
    if [[ -n ${VIRTUAL_ENV} ]]; then
        p="${p}\[${sep_color}${dark_bg}${sep}${reset}\]\[${dark_bg}${orange}\] ${VIRTUAL_ENV##/*/} "
    fi

    # Segment 4: working directory - pink on dark bg
    p="${p}\[${sep_color}${dark_bg}${sep}${reset}\]\[${dark_bg}${pink}\] \w/ "

    # Segment 5: git status - text only, no background
    if inside_git_repo; then
        local branch=$(git branch 2>/dev/null | grep "\*" | sed "s/* //")
        local dirty=$(git diff --quiet 2>/dev/null || echo "1")
        if [[ -n ${dirty} ]]; then
            p="${p}\[${reset}${sep_color}${sep}${reset}\] ${yellow}${branch}${reset}"
        else
            p="${p}\[${reset}${sep_color}${sep}${reset}\] ${green}${branch}${reset}"
        fi
    else
        p="${p}\[${reset}${sep_color}${sep}${reset}\]"
    fi

    PS1="${p}\n$ "
}

function inside_git_repo() {
    git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
}

PROMPT_COMMAND=set_prompt
