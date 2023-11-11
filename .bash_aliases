alias _listen="lsof -nP -iTCP -sTCP:LISTEN | sed '1 s,.*,$(tput smso)&$(tput sgr0),'"
alias clogin="ct clogin -f \"${TMPDIR}/.cloginrc\""
alias ls='ls --color=auto' 2>/dev/null
alias nmap='nmap -Pn -oG -'
alias pico=nano
alias rot13="tr a-zA-Z n-za-mN-ZA-M"
alias toilet="toilet --directory \"${HOME}/.fonts/figlet\""
alias vault=vault_view
alias vault_edit="ansible-vault edit \"${HOME}/.${USER:-loginrc}.vault\" --vault-password-file \"${TMPDIR}/.vault\""
alias vault_view="ansible-vault view \"${HOME}/.${USER:-loginrc}.vault\" --vault-password-file \"${TMPDIR}/.vault\""
#alias vim=nvim
