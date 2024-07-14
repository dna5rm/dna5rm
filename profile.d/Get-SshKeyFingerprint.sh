function Get-SshKeyFingerprint() {
    # Return the SSH key fingerprint w/valid email address.

    # check if commands exist.
    local Command_List=( Assert-StrIsEmail Run-Command ssh-keygen )
    local Command_Check=""; for Command_Check in ${Command_List[@]}; do
        type ${Command_Check} >/dev/null 2>&1 || return 1
    done && {
        local ssh_hash=( $(awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa" 2> /dev/null)) )
    }

    [[ -n "${ssh_hash[*]}" ]] && {
    
        # Check for a valid email address.
        Assert-StrIsEmail "${ssh_hash[1]}" || {
            local email_address=""
            Run-Command  "ssh-keygen -lvf \"${HOME}/.ssh/id_rsa\" 2> /dev/null"
            echo; read -e -i "${USER:-$(whoami)}@" -p "Email Address: " email_address

            # Update the comment with the email address.
            Assert-StrIsEmail "${email_address}" && {
                Run-Command "ssh-keygen -c -C \"${email_address}\" -f \"${HOME}/.ssh/id_rsa\""
            }
        }

        # Return the SSH key hash & comment.
        [[ "${?}" -eq 0 ]] && {
            echo -en "$(awk '{sub(/.*:/, ""); print $1,$2}' <(ssh-keygen -lf "${HOME}/.ssh/id_rsa"))"
        }

    } || return 1
}