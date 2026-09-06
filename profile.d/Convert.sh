# Convert helpers — defined always; pip on first use, no login probes.

function j2y() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert JSON to YAML from stdin."; return 1; }
    Ensure-Pip pyyaml --import yaml || return 1
    python -c 'import sys,yaml,json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)'
}

function y2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert YAML to JSON from stdin."; return 1; }
    Ensure-Pip pyyaml --import yaml || return 1
    python -c 'import sys,yaml,json; print(json.dumps(yaml.safe_load(sys.stdin.read()),indent=2))'
}

function x2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert XML to JSON from stdin."; return 1; }
    Ensure-Pip xmltodict --import xmltodict || return 1
    python -c 'import sys,json,xmltodict; print(json.dumps(xmltodict.parse(sys.stdin.read()),indent=2))'
}

export -f j2y y2j x2j
