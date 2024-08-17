# Load the following if PyYAML available to python.
[[ "$(python3 -c "import pkgutil; print(0) if pkgutil.find_loader('yaml') else print(1)")" == 0 ]] && {
    function j2y() {
        # Get the function source.
        [[ "${0}" != -*"bash" ]] && {
            local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
        } || {
            local script="${FUNCNAME[0]}"
        }

        [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] && {
            python3 -c 'import sys,yaml,json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)' 2> /dev/null
            return "${?}"
        } || {
            echo "${script} - Convert JSON to YAML from stdin."
        }
    }

    function y2j() {
        # Get the function source.
        [[ "${0}" != -*"bash" ]] && {
            local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
        } || {
            local script="${FUNCNAME[0]}"
        }

        [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] && {
            python3 -c 'import sys,yaml,json; print(json.dumps(yaml.safe_load(sys.stdin.read()),indent=2))' 2> /dev/null
            return "${?}"
        } || {
            echo "${script} - Convert YAML to JSON from stdin."
        }
    }

    # Export Functions
    export -f j2y
    export -f y2j
}

# Load the following if xmltodict available to python.
[[ "$(python3 -c "import pkgutil; print(0) if pkgutil.find_loader('xmltodict') else print(1)")" == 0 ]] && {
    function x2j() {
        # Get the function source.
        [[ "${0}" != -*"bash" ]] && {
            local script="$(basename "${0}" 2> /dev/null):${FUNCNAME[0]}"
        } || {
            local script="${FUNCNAME[0]}"
        }

        [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] && {
            python3 -c 'import sys,json,xmltodict; print(json.dumps(xmltodict.parse(sys.stdin.read()),indent=2))' 2> /dev/null
        } || {
            echo "${script} - Convert XML to JSON from stdin."
        }
    }

    # Export Functions
    export -f x2j
}
