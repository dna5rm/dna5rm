# Clipboard helpers. Termux, Wayland, X11, else stdout/stdin.

function clip_set() {
    local data
    if [[ ${#} -gt 0 ]]; then
        data="$*"
    else
        data=$(cat)
    fi
    [[ -n "${data}" ]] || return 1
    if type termux-clipboard-set >/dev/null 2>&1; then
        printf '%s' "${data}" | termux-clipboard-set
    elif type wl-copy >/dev/null 2>&1; then
        printf '%s' "${data}" | wl-copy
    elif type xclip >/dev/null 2>&1; then
        printf '%s' "${data}" | xclip -selection clipboard
    else
        printf '%s\n' "${data}"
    fi
}

function clip_get() {
    if type termux-clipboard-get >/dev/null 2>&1; then
        termux-clipboard-get
    elif type wl-paste >/dev/null 2>&1; then
        wl-paste -n
    elif type xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o
    else
        echo "${FUNCNAME[0]}: no clipboard tool" >&2
        return 1
    fi
}

export -f clip_set clip_get
