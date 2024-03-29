#!/bin/bash
## Inspirational quote.

QUOTES="${RCPATH}/share/quotes.json"

function rc_quote ()
{
    # Verify script requirements.
    for req in fmt jq shuf; do
        type ${req} >/dev/null 2>&1 || {
            echo >&2 "$(basename "${0}"): I require \"${req}\" but it's not installed. Aborting."
            exit 1
        }
    done

    # Select random author/category.
    if [[ -z "${1}" ]]; then
        local category="$(jq -r 'keys[]' "${QUOTES}" | shuf -n1)"
    else
        local category="${1^^}"
    fi

    # Query the total number of quotes.
    local count="$(jq -r --arg key "${category}" '.[$key]|length' "${QUOTES}")"

    # Select a random quote.
    if [[ "${count}" -gt "1" ]]; then
        # Random number based on $count
        local quote=$(( ( RANDOM % ${count} )  + 0 ))

        # Display formated quote.
        fmt <(jq -r --arg key "${category}" --arg val "${quote}" '.[$key][$val|fromjson] | "\n" + .quote, "\n-" + .source + "\n"' "${QUOTES}")
    else
        echo "$(basename "${0}"): Unable to find \"${1}\" quote."
    fi
}


[[ -f "${QUOTES}" ]] && {
    rc_quote "${1}"
}
