# ~/.profile: login shells. bash(1) skips this if ~/.bash_profile or ~/.bash_login exists.

# umask: libpam-umask for ssh if you need it.
#umask 022

# PATH lives in .bashrc (bin, .local/bin, …). Do not prepend here — duplicates.

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi
