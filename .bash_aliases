alias _listen="lsof -nP -iTCP -sTCP:LISTEN | sed '1 s,.*,$(tput smso)&$(tput sgr0),'"
alias less='less -r'
alias rot13="tr a-zA-Z n-za-mN-ZA-M"

# User vault
type ansible-vault >/dev/null 2>&1 && {
    alias vault=vault_view
    alias vault_edit="ansible-vault edit \"${HOME}/.${USER:-loginrc}.vault\" --vault-password-file \"${TMPDIR}/.vault\""
    alias vault_view="ansible-vault view \"${HOME}/.${USER:-loginrc}.vault\" --vault-password-file \"${TMPDIR}/.vault\""
}

# Rancid chromaterm+cloginrc
type clogin >/dev/null 2>&1 && { alias clogin="ct clogin -f \"${TMPDIR}/.cloginrc\""; }

# Directory listing: ls/lsd
type lsd >/dev/null 2>&1 && {
    alias ls='lsd'
    alias tree='lsd --tree'
} || {
    alias ls='ls --color=auto' 2>/dev/null
}

# Other verification aliases.
type nano >/dev/null 2>&1 && { alias pico=nano; }
type nmap >/dev/null 2>&1 && { alias nmap='nmap -Pn -oG -'; }
type toilet >/dev/null 2>&1 && { alias toilet="toilet --directory \"${HOME}/.fonts/figlet\""; }
