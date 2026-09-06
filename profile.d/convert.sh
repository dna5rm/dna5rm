# Convert helpers — defined always; pip on first use, no login probes.

function j2y() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert JSON to YAML from stdin."; return 1; }
    ensure_pip pyyaml --import yaml || return 1
    python -c 'import sys,yaml,json; yaml.safe_dump(json.load(sys.stdin), sys.stdout, default_flow_style=False)'
}

function y2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert YAML to JSON from stdin."; return 1; }
    ensure_pip pyyaml --import yaml || return 1
    python -c 'import sys,yaml,json; print(json.dumps(yaml.safe_load(sys.stdin.read()),indent=2))'
}

function x2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert XML to JSON from stdin."; return 1; }
    ensure_pip xmltodict --import xmltodict || return 1
    python -c 'import sys,json,xmltodict; print(json.dumps(xmltodict.parse(sys.stdin.read()),indent=2))'
}

function t2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert TOML to JSON from stdin."; return 1; }
    python -c 'import sys,json,tomllib; print(json.dumps(tomllib.loads(sys.stdin.read()),indent=2))'
}

function j2t() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert JSON to TOML from stdin."; return 1; }
    ensure_pip tomli-w --import tomli_w || return 1
    python -c 'import sys,json,tomli_w; tomli_w.dump(json.load(sys.stdin), sys.stdout)'
}

function csv2j() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Convert CSV to JSON from stdin."; return 1; }
    python -c 'import sys,csv,json; print(json.dumps(list(csv.DictReader(sys.stdin)),indent=2))'
}

function b64e() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Base64-encode stdin."; return 1; }
    python -c 'import sys,base64; sys.stdout.write(base64.b64encode(sys.stdin.buffer.read()).decode()+"\n")'
}

function b64d() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - Base64-decode stdin."; return 1; }
    python -c 'import sys,base64; sys.stdout.buffer.write(base64.b64decode(sys.stdin.read()))'
}

function urlenc() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - URL-encode stdin."; return 1; }
    python -c 'import sys,urllib.parse; sys.stdout.write(urllib.parse.quote(sys.stdin.read(),safe=""))'
}

function urldec() {
    [[ "${0}" != -*"bash" ]] && local script="$(basename "${0}" 2>/dev/null):${FUNCNAME[0]}" || local script="${FUNCNAME[0]}"
    [[ ${#} -eq 0 ]] && [[ ! -t 0 ]] || { echo "${script} - URL-decode stdin."; return 1; }
    python -c 'import sys,urllib.parse; sys.stdout.write(urllib.parse.unquote(sys.stdin.read()))'
}

export -f j2y y2j x2j t2j j2t csv2j b64e b64d urlenc urldec
