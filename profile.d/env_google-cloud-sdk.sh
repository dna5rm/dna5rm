# If Google Cloud SDK exists.
[[ -d "${HOME}/google-cloud-sdk" ]] && {

    # The next line updates PATH for the Google Cloud SDK.
    [[ -f "${HOME}/google-cloud-sdk/path.bash.inc" ]] && {
        . "${HOME}/google-cloud-sdk/path.bash.inc"
    }

    # The next line enables shell command completion for gcloud.
    [[ -f "${HOME}/google-cloud-sdk/completion.bash.inc" ]] && {
        . "${HOME}/google-cloud-sdk/completion.bash.inc"
    }
}
