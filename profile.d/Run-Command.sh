function Run-Command() {
    # Display and run a command for a user.
    [[ "${#@}" -ge 1 ]] && {
        local command && for command in "${@}"; do
            printf "$(tput sgr0)>>> $(tput setaf 2)%s$(tput sgr0)\n" "${command}"
            # Check if the chromaterm exists
            if command -v ct &> /dev/null
            then eval "${command}" | ct
            else eval "${command}"
            fi
        done
    } || {
        echo "No commands to execute..."
    }
}

# Export Function
export -f Run-Command
