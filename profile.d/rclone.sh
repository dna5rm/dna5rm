# rclone-sync [--dry-run] path [path…]
# Env: RCLONE_REMOTE (required), RCLONE_TARGET (optional remote subpath).
# Dirs: rclone sync. Files: copy up, or pull down if remote is newer.

function rclone-sync() {
    local script dry=() rc=0 source remote_share remote_path remote_type remote_host
    local local_epoch remote_epoch line

    if [[ "${0}" != -*"bash" ]]; then
        script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}"
    else
        script="${FUNCNAME[0]}"
    fi

    [[ "${1}" == --dry-run ]] && { dry=(--dry-run); shift; }

    if [[ ${#} -eq 0 ]]; then
        echo "${script} [--dry-run] path [path…]" >&2
        echo "Set RCLONE_REMOTE (and optional RCLONE_TARGET)." >&2
        return 2
    fi

    command -v rclone >/dev/null 2>&1 || {
        echo "${script} - rclone is not installed" >&2
        return 1
    }

    if [[ -z "${RCLONE_REMOTE}" ]]; then
        echo "${script} - RCLONE_REMOTE is not set" >&2
        return 1
    fi
    remote_share="${RCLONE_REMOTE}:${RCLONE_TARGET:-}"

    rclone listremotes 2>/dev/null | grep -qx "${RCLONE_REMOTE}:" || {
        echo "${script} - remote '${RCLONE_REMOTE}' is not configured" >&2
        return 1
    }

    remote_type=$(rclone config show "${RCLONE_REMOTE}" 2>/dev/null \
        | awk -F' = ' '/^type / { print $2; exit }')
    if [[ "${remote_type}" == sftp || "${remote_type}" == ssh ]]; then
        remote_host=$(rclone config show "${RCLONE_REMOTE}" 2>/dev/null \
            | awk -F' = ' '/^host / { print $2; exit }')
        if [[ -n "${remote_host}" ]] && ! ping -c 1 -W 2 "${remote_host}" >/dev/null 2>&1; then
            echo "${script} - cannot reach ${remote_host}" >&2
            return 1
        fi
    fi

    for source in "${@}"; do
        if [[ ! -e "${source}" ]]; then
            echo "${script} - missing: ${source}" >&2
            rc=1
            continue
        fi
        if [[ -d "${source}" ]]; then
            source=$(cd "${source}" && pwd) || { rc=1; continue; }
        else
            source="$(cd "$(dirname "${source}")" && pwd)/$(basename "${source}")"
        fi
        remote_path="${remote_share}/$(basename "${source}")"

        if [[ -d "${source}" ]]; then
            if ! run_command rclone sync "${source}" "${remote_path}" \
                --copy-links --update --use-server-modtime --progress "${dry[@]}"; then
                echo "${script} - directory sync failed: ${source}" >&2
                rc=1
            fi
            continue
        fi

        line=$(rclone lsl "${remote_path}" 2>/dev/null | awk 'NR==1 { print $2 " " $3 }')
        if [[ -n "${line}" ]]; then
            remote_epoch=$(date -d "${line}" +%s 2>/dev/null) || remote_epoch=0
            local_epoch=$(date -r "${source}" +%s 2>/dev/null) || local_epoch=0
            if (( remote_epoch > local_epoch )); then
                run_command rclone copy "${remote_path}" "$(dirname "${source}")" \
                    --progress "${dry[@]}" || rc=1
            else
                run_command rclone copy "${source}" "${remote_share}" \
                    --progress "${dry[@]}" || rc=1
            fi
        else
            run_command rclone copy "${source}" "${remote_share}" \
                --progress "${dry[@]}" || rc=1
        fi
    done
    return "${rc}"
}

export -f rclone-sync
