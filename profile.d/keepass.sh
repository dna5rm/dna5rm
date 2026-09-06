# KeePassXC via pykeepass (ensure_pip on first use). Never kp.sh, never ~/.kprc.
# KP_PASS from vault .env. Optional KP_KDBX / KP_KEYX (keyx optional).
# Functions always define; missing kdbx fails at invoke (vault exports after this glob).

function _kp_usage() {
    sed "s/^[ \t]*//" <<-EOF
	kp_user <entry>     copy UserName
	kp_pass <entry>     copy Password
	kp_url <entry>      copy URL
	kp_otp <entry>      copy current TOTP
	kp_show <entry>     JSON (Path Title UserName URL Notes). No Password/OTP
	                    unless KP_SHOW_SECRETS=1. Exact title or Path/Title.
	kp_find <query>     Path+Title only (min 3 chars; skips Recycle Bin)
	entry: exact Title, or Path/Title when titles collide.
	Needs KP_PASS (vault .env). Optional KP_KDBX KP_KEYX.
	EOF
}

function _kp_ready() {
    [[ "${1-}" == -h || "${1-}" == --help ]] && { _kp_usage; return 2; }
    type ensure_pip >/dev/null 2>&1 || {
        echo "${FUNCNAME[1]}: ensure_pip missing (source Python.sh)" >&2
        return 1
    }
    ensure_pip pykeepass --import pykeepass || {
        echo "${FUNCNAME[1]}: could not install pykeepass" >&2
        return 1
    }
    ensure_pip pyotp --import pyotp || {
        echo "${FUNCNAME[1]}: could not install pyotp" >&2
        return 1
    }
    [[ -n "${KP_PASS:-}" ]] || {
        echo "${FUNCNAME[1]}: KP_PASS is unset (vault .env)" >&2
        return 1
    }
    export KP_KDBX="${KP_KDBX:-${HOME}/Documents/$(whoami).kdbx}"
    [[ -e "${KP_KDBX}" ]] || {
        echo "${FUNCNAME[1]}: kdbx missing: ${KP_KDBX}" >&2
        return 1
    }
    if [[ -n "${KP_KEYX:-}" && -e "${KP_KEYX}" ]]; then
        export KP_KEYX
    elif [[ -e "${HOME}/Documents/$(whoami).keyx" ]]; then
        export KP_KEYX="${HOME}/Documents/$(whoami).keyx"
    else
        unset KP_KEYX
    fi
}

function _kp_py() {
    "${PYTHON:-python}" - "$@" <<'PY'
import json, os, sys
from urllib.parse import parse_qs, unquote, urlparse
from pykeepass import PyKeePass
import pyotp

cmd, query = sys.argv[1], sys.argv[2]
kdbx = os.environ["KP_KDBX"]
keyx = os.environ.get("KP_KEYX") or None
if keyx and not os.path.exists(keyx):
    keyx = None
kp = PyKeePass(kdbx, password=os.environ["KP_PASS"], keyfile=keyx)
show_secrets = os.environ.get("KP_SHOW_SECRETS", "") in ("1", "true", "yes")

def group_path(e):
    names = []
    g = getattr(e, "group", None)
    while g is not None:
        name = getattr(g, "name", None) or ""
        if name and name != "Root":
            names.append(name)
        g = getattr(g, "parentgroup", None) or getattr(g, "parent", None)
    names.reverse()
    title = e.title or ""
    return "/".join(names + ([title] if title else []))

def is_trash(e):
    g = getattr(e, "group", None)
    while g is not None:
        if (getattr(g, "name", None) or "") == "Recycle Bin":
            return True
        g = getattr(g, "parentgroup", None) or getattr(g, "parent", None)
    return False

def custom(e, *names):
    props = getattr(e, "custom_properties", None) or {}
    for n in names:
        v = props.get(n)
        if v:
            return v
    return ""

def totp_code(e):
    uri = (getattr(e, "otp", None) or "") or custom(e, "otp", "OTP", "TOTP")
    if uri.startswith("otpauth://"):
        try:
            return pyotp.parse_uri(uri).now()
        except Exception:
            q = parse_qs(urlparse(uri).query)
            secret = (q.get("secret") or [""])[0]
            if secret:
                digits = int((q.get("digits") or ["6"])[0] or 6)
                period = int((q.get("period") or ["30"])[0] or 30)
                return pyotp.TOTP(unquote(secret), digits=digits, interval=period).now()
            return ""
    secret = custom(e, "TimeOtp-Secret-Base32", "TOTP Seed", "totp", "otp-secret")
    if not secret:
        return ""
    digits = int(custom(e, "TimeOtp-Length") or 6)
    period = int(custom(e, "TimeOtp-Period") or 30)
    try:
        return pyotp.TOTP(secret, digits=digits, interval=period).now()
    except Exception:
        return ""

def rec(e):
    out = {
        "Path": group_path(e),
        "Title": e.title or "",
        "UserName": e.username or "",
        "URL": e.url or "",
        "Notes": e.notes or "",
    }
    if show_secrets:
        out["Password"] = e.password or ""
        out["OTP"] = totp_code(e)
    return out

def live():
    return [e for e in (kp.entries or []) if not is_trash(e)]

def entries(q, exact=False):
    pool = live()
    if exact:
        if "/" in q:
            return [e for e in pool if group_path(e) == q or group_path(e).endswith("/" + q)]
        return [e for e in pool if (e.title or "") == q]
    found = [e for e in pool if q.lower() in (e.title or "").lower() or q.lower() in group_path(e).lower()]
    if not found:
        import re
        try:
            rx = re.compile(q, re.I)
        except re.error:
            return []
        found = [e for e in pool if rx.search(e.title or "") or rx.search(group_path(e))]
    return found

hits = entries(query, exact=(cmd != "find"))
if cmd == "find":
    if len(query) < 3:
        sys.stderr.write("kp_find: query must be at least 3 characters\n")
        sys.exit(2)
    loc = [{"Path": group_path(e), "Title": e.title or ""} for e in hits]
    json.dump(loc, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0 if hits else 1)
if not hits:
    sys.exit(1)
if cmd != "find" and len(hits) > 1:
    sys.stderr.write("ambiguous title; use Path:\n")
    for e in hits:
        sys.stderr.write("  " + group_path(e) + "\n")
    sys.exit(1)
e = hits[0]
if cmd == "show":
    json.dump(rec(e), sys.stdout, indent=2)
    sys.stdout.write("\n")
elif cmd in ("UserName", "Password", "URL", "OTP"):
    if cmd == "OTP":
        val = totp_code(e)
    elif cmd == "Password":
        val = e.password or ""
    elif cmd == "URL":
        val = e.url or ""
    else:
        val = e.username or ""
    if not val:
        sys.exit(1)
    sys.stdout.write(val)
else:
    sys.exit(2)
PY
}

function kp_user() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_user <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py UserName "${1}") || return 1
    clip_set "${v}"
}

function kp_pass() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_pass <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py Password "${1}") || return 1
    clip_set "${v}"
}

function kp_url() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_url <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py URL "${1}") || return 1
    clip_set "${v}"
}

function kp_otp() {
    local v
    [[ -n "${1-}" ]] || { echo "usage: kp_otp <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    v=$(_kp_py OTP "${1}") || {
        echo "kp_otp: no TOTP on '${1}'" >&2
        return 1
    }
    clip_set "${v}"
}

function kp_show() {
    [[ -n "${1-}" ]] || { echo "usage: kp_show <entry>" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    _kp_py show "${1}"
}

function kp_find() {
    [[ -n "${1-}" ]] || { echo "usage: kp_find <query>" >&2; return 2; }
    [[ "${#1}" -ge 3 ]] || { echo "kp_find: query must be at least 3 characters" >&2; return 2; }
    _kp_ready "${1}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    _kp_py find "${1}"
}

export -f _kp_usage _kp_ready _kp_py \
    kp_user kp_pass kp_url kp_otp kp_show kp_find
