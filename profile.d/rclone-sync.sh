function rclone-sync() { local script source remote_path remote_share remote_host

    # Set script name
    if [[ "${0}" != -*"bash" ]]; then
        script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
    else
        script="${FUNCNAME[0]}"
    fi

    # Validate rclone installation
    if ! command -v rclone &>/dev/null; then
        echo "${script} - rclone is not installed!"
        return 1
    fi

    # Check if remote share is configured in environment
    if [[ -z "${RCLONE_REMOTE}" ]]; then
        echo "${script} - RCLONE_REMOTE environment variable not set!"
        echo "Please set with: export RCLONE_REMOTE=your_remote_name"
        return 1
    fi
    remote_share="${RCLONE_REMOTE}:${RCLONE_TARGET:-}"

    # Validate remote is configured
    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
        echo "${script} - Remote share '${RCLONE_REMOTE}' not configured in rclone!"
        echo "Please run 'rclone config' first to set up the remote."
        return 1
    fi

    # Extract host from rclone config
    remote_host=$(rclone config show "${RCLONE_REMOTE}" 2>/dev/null | grep 'host' | awk '{print $3}' | tr -d '"')
    if [[ -z "${remote_host}" ]]; then
        echo "${script} - Could not determine host from rclone config!"
        return 1
    fi

    # Check host connectivity
    if ! ping -c 1 -W 2 "${remote_host}" &>/dev/null; then
        echo "${script} - Cannot reach host: ${remote_host}"
        return 1
    fi

    # Process each argument (file or directory)
    for source in "$@"; do
        # Skip if source doesn't exist locally
        if [[ ! -e "${source}" ]]; then
            echo "${script} - Warning: Local path does not exist: ${source}"
            continue
        fi

        # Convert to absolute path and clean it
        source=$(realpath "${source}")

        # Get the base directory name for remote path construction
        local base_name=$(basename "${source}") && remote_path="${remote_share}/${base_name}"

        if [[ -d "${source}" ]]; then
            # Handle directory sync
            if ! Run-Command "rclone sync \"${source}\" \"${remote_path}\" --copy-links --update --use-server-modtime --progress"
            then
                echo "${script} - Directory sync failed for: ${source}"
                continue
            fi
        else
            # Handle file sync
            # Check if remote file exists and is newer
            if rclone lsl "${remote_path}" &>/dev/null; then
                local remote_newer && remote_newer=$(rclone lsl "${remote_path}" | awk '{print $2 " " $3}')
                local local_newer  && local_newer=$(date -r "${source}" "+%Y-%m-%d %H:%M:%S")

                # Remote file is newer, downloading...
                if [[ "$(date -d "${remote_newer}" +%s)" > "$(date -d "${local_newer}" +%s)" ]]; then
                    Run-Command "rclone copy \"${remote_path}\" \"$(dirname "${source}")\" --progress"
                fi
            else
                Run-Command "rclone copy \"${source}\" \"${remote_share}\" --progress"
            fi
        fi
    done

    return 0
}

# Export function
export -f rclone-sync
