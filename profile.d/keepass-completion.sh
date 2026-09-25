# Bash completion for the kp_* functions in profile.d/keepass.sh.
# Sourced with the rest of profile.d (glob order does not matter: the
# completer only runs on TAB). Registration only — at complete time nothing
# calls pykeepass, reads the kdbx, or needs KP_PASS, so entry/tag/field/
# group names are never enumerated. Free-form args (entry, dest, query,
# tag, field name) complete to nothing; only the static flags keepass.sh
# itself documents are offered:
#   kp_rm -f | kp_tag +|- | kp_field NAME - | kp_pass - (TTY read)

function _kp_completer() {
    local cur n i
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    # n = number of positional words already given (flag words excluded).
    n=0
    for ((i = 1; i < COMP_CWORD; i++)); do
        case "${COMP_WORDS[i]}" in
            -*) ;;
            *) ((n += 1)) ;;
        esac
    done
    case "${COMP_WORDS[0]}" in
        kp_rm)
            # kp_rm <entry> [-f|--force]; -f only after the entry word.
            if ((n > 0)) && [[ "${cur}" == -* || -z "${cur}" ]]; then
                COMPREPLY=($(compgen -W '-f --force' -- "${cur}"))
            elif ((n == 0)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-h --help' -- "${cur}"))
            fi
            ;;
        kp_tag)
            # kp_tag <entry> [+tag|-tag …]: bare tag names are not
            # enumerable, so offer the +/- ops as the syntax hint.
            if ((n > 0)); then
                COMPREPLY=($(compgen -W '+ -' -- "${cur}"))
            elif [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-h --help' -- "${cur}"))
            fi
            ;;
        kp_field)
            # kp_field <entry> [name [value|-]]: '-' deletes; offer it only
            # once a field name is set and only when '-' is already typed.
            if ((n == 2)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-' -- "${cur}"))
            elif ((n == 0)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-h --help' -- "${cur}"))
            fi
            ;;
        kp_pass)
            # kp_pass <entry> [value|-]: '-' switches to the TTY read.
            if ((n == 0)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-h --help' -- "${cur}"))
            elif ((n == 1)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-' -- "${cur}"))
            fi
            ;;
        kp_ls)
            # kp_ls [-a] [group]. Group is free-form; offer only the flag.
            if [[ "${cur}" == -* || -z "${cur}" ]]; then
                COMPREPLY=($(compgen -W '-a --all -h --help' -- "${cur}"))
            fi
            ;;
        kp_find | kp_mv)
            # Free-form query/dest; keepass.sh does not honour -h here.
            ;;
        *)
            # kp_user kp_url kp_otp kp_show kp_add kp_note (+ future kp_*):
            # <entry>/<dest> are free-form; -h/--help only as the first word.
            if ((n == 0)) && [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W '-h --help' -- "${cur}"))
            fi
            ;;
    esac
    return 0
}

# nospace for kp_tag/kp_field/kp_pass: a bare '+'/'-' insert must be
# followed directly by the tag/field text ("+tag", not "+ tag" — kp_tag
# would otherwise add a literal "+" tag).
complete -F _kp_completer -o nospace kp_tag kp_field kp_pass
complete -F _kp_completer \
    kp_user kp_url kp_otp kp_show kp_find kp_ls kp_mv kp_add kp_rm kp_note