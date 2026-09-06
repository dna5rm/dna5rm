# Things to do if inside termux.
if type "termux-info" >/dev/null 2>&1; then

    export CARGO_BUILD_TARGET="${CARGO_BUILD_TARGET:-$(uname -m)-linux-android}"
    export CRYPTOGRAPHY_DONT_BUILD_RUST=1
    export MATHLIB="m"

    alias android_settings="am start -a android.intent.action.MAIN -n com.android.settings/.Settings"
    alias mplayer=termux-open
    alias tts="termux-tts-speak -s MUSIC -r 1.5"

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

fi
