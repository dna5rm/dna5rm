# KeePassXC via pykeepass (Ensure-Pip on first use). Never kp.sh, never ~/.kprc.
# KP_PASS from vault .env. Optional KP_KDBX / KP_KEYX.
# KEYX is optional: missing .keyx is not an error.
# If the kdbx is not on this host, define nothing (Termux-style gate).

: "${KP_KDBX:=${HOME}/Documents/$(whoami).kdbx}"
[[ -e "${KP_KDBX}" ]] || return 0
export KP_KDBX

function _kp_usage() {
    sed "s/^[ \t]*//" <<-EOF
	kp_user <entry>     copy UserName
	kp_pass <entry>     copy Password
	kp_url <entry>      copy URL
	kp_show <entry>     JSON object (Title UserName Password URL Notes)
	kp_find <query>     JSON array of those objects
	Needs KP_PASS (vault .env). Optional KP_KDBX KP_KEYX.
	Example: kp_show GALEGA | jq -r .UserName
	EOF
}

function _kp_ready() {
    [[ "${1-}" == -h || "${1-}" == --help ]] && { _kp_usage; return 2; }
    type Ensure-Pip >/dev/null 2>&1 || {
        echo "${FUNCNAME[1]}: Ensure-Pip missing (source Python.sh)" >&2
        return 1
    }
    Ensure-Pip pykeepass --import pykeepass || {
        echo "${FUNCNAME[1]}: could not install pykeepass" >&2
        return 1
    }
    [[ -n "${KP_PASS:-}" ]] || {
        echo "${FUNCNAME[1]}: KP_PASS is unset (vault .env)" >&2
        return 1
    }
    export KP_KDBX
    # KEYX optional: only export if the file exists.
    if [[ -n "${KP_KEYX:-}" && -e "${KP_KEYX}" ]]; then
        export KP_KEYX
    elif [[ -e "${HOME}/Documents/$(whoami).keyx" ]]; then
        export KP_KEYX="${HOME}/Documents/$(whoami).keyx"
    else
        unset KP_KEYX
    fi
}

function _kp_py() {
    python - "$@" <<'PY'
import json, os, sys
from pykeepass import PyKeePass

cmd, query = sys.argv[1], sys.argv[2]
kdbx = os.environ["KP_KDBX"]
keyx = os.environ.get("KP_KEYX") or None
if keyx and not os.path.exists(keyx):
    keyx = None
kp = PyKeePass(kdbx, password=os.environ["KP_PASS"], keyfile=keyx)

def entries(q):
    found = kp.find_entries(title=q, first=False) or []
    if not found:
        found = kp.find_entries(title=q, regex=True, flags="i") or []
    return found

def rec(e):
    return {
        "Title": e.title or "",
        "UserName": e.username or "",
        "Password": e.password or "",
        "URL": e.url or "",
        "Notes": e.notes or "",
    }

hits = entries(query)
if cmd == "find":
    json.dump([rec(e) for e in hits], sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0 if hits else 1)
if not hits:
    sys.exit(1)
e = hits[0]
if cmd == "show":
    json.dump(rec(e), sys.stdout, indent=2)
    sys.stdout.write("\n")
elif cmd in ("UserName", "Password", "URL"):
    val = rec(e)[cmd]
    if not val:
        sys.exit(1)
    sys.stdout.write(val)
else:
    sys.exit(2)
PY
}

function _kp_field() {
    local entry="${1-}" field="${2-}"
    [[ -n "${entry}" && -n "${field}" ]] || return 2
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    _kp_py "${field}" "${entry}"
}

function kp_user() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_user <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py UserName "${1}") || return 1
    Set-Clipboard "${v}"
}

function kp_pass() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_pass <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py Password "${1}") || return 1
    Set-Clipboard "${v}"
}

function kp_url() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_url <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py URL "${1}") || return 1
    Set-Clipboard "${v}"
}

function kp_show() {
    [[ -n "${1-}" ]] || { echo "usage: kp_show <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    _kp_py show "${1}"
}

function kp_find() {
    [[ -n "${1-}" ]] || { echo "usage: kp_find <query>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    _kp_py find "${1}"
}

export -f _kp_usage _kp_ready _kp_py _kp_field \
    kp_user kp_pass kp_url kp_show kp_find
