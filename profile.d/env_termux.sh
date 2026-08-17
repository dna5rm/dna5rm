# Things to do if inside termux.
if type "termux-info" >/dev/null 2>&1; then

    export CARGO_BUILD_TARGET="${CARGO_BUILD_TARGET:-$(uname -m)-linux-android}"
    export CRYPTOGRAPHY_DONT_BUILD_RUST=1
    export MATHLIB="m"

    alias android_settings="am start -a android.intent.action.MAIN -n com.android.settings/.Settings"
    alias mplayer=termux-open
    alias tts="termux-tts-speak -r 1.5"

    # Dead X11/openbox artifact — leave for later. Even then the path is wrong:
    # file lives at ${RCPATH}/.config/openbox/startx.sh, not profile.d's sibling openbox/.
    # alias startx="export DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1:4713 && ${RCPATH}/openbox/startx.sh"

    type lsd >/dev/null 2>&1 && {
        alias ls='lsd'
        alias tree='lsd --tree'
    }

    # sshd may already be up (Termux:Boot / a prior session). Do not make wake-lock
    # depend on sshd's exit status. Pair with ssh_server_stop.
    function ssh_server()
    {
        pidof sshd >/dev/null 2>&1 || sshd
        termux-wake-lock
    }

    function ssh_server_stop()
    {
        pkill sshd
        termux-wake-unlock
    }

    function kp_user()
    {
        [[ -n "${1}" ]] || { echo "usage: kp_user <entry>" >&2; return 1; }
        jq -r '.[0].UserName // empty' <(kp.sh show "${1}") | termux-clipboard-set
    }

    function kp_pass()
    {
        [[ -n "${1}" ]] || { echo "usage: kp_pass <entry>" >&2; return 1; }
        jq -r '.[0].Password // empty' <(kp.sh show "${1}") | termux-clipboard-set
    }

fi
