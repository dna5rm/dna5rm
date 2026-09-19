# KeePassXC via pykeepass (ensure_pip on first use). Never ~/.kprc.
# KP_PASS from vault .env. Optional KP_KDBX / KP_KEYX (keyx optional).
# Default basename is not whoami: Termux USER is u0_aNNN. Same idea as vault
# ${USER:-…} plus ssh_hash[1] (key comment local-part, e.g. user@host).
# Functions always define; missing kdbx fails at invoke (vault exports after this glob).
# Get: one arg, copies to clipboard. Set: extra arg (or '-' / TTY for password).
# Add/Rm: kp_add <Group/Title|Title> creates a blank entry (fill fields with
# kp_user/kp_pass/kp_url/kp_otp/kp_note/kp_tag); kp_rm <entry> [-f] moves to
# the Recycle Bin by default (type the Path to confirm; -f hard-deletes).
# kp_field <entry> [name [value|-]]: custom fields (String properties);
# '-' deletes name.

function _kp_usage() {
    sed "s/^[ \t]*//" <<-EOF
	kp_user <entry> [value]   get UserName (clipboard) or set it
	kp_pass <entry> [value|-] get Password or set it ('-' or omit value: TTY)
	kp_url  <entry> [value]   get URL or set it
	kp_note <entry> [value]   get Notes or set it
	kp_otp  <entry> [secret]  get current TOTP or set seed (otpauth:// or base32)
	kp_show <entry>           JSON (Path Title UserName URL Notes). No Password/OTP
	                          unless KP_SHOW_SECRETS=1. Exact title or Path/Title.
	kp_find <query>           Path+Title only (min 3 chars; skips Recycle Bin)
	kp_mv   <entry> <dest>    rename and/or move. dest is NewTitle, Group/,
	                          or Group/NewTitle (groups created as needed).
	kp_tag  <entry> [ops…]    list tags, or +tag / -tag (bare name adds).
	kp_field <entry> [name [value|-]]
	                          custom fields: JSON list (no name), get name
	                          (clipboard; rc 1 if missing), set name=value
	                          (created if missing), or '-' deletes name.
	                          username/password/url/otp/notes/title are
	                          reserved (use kp_user/kp_pass/kp_url/kp_otp/
	                          kp_note).
	kp_add  <dest>            create a blank entry. dest is Group/Title or
	                          Title (groups created as needed); fill the
	                          fields afterwards with kp_user/kp_pass/
	                          kp_url/kp_note/kp_otp. Refuses when the
	                          exact Path already exists.
	kp_rm   <entry> [-f]      move entry to Recycle Bin. Without -f,
	                          type its Path to confirm; -f hard-deletes
	                          and skips the prompt (flag anywhere).
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
    local kp_user="${KP_USER:-}"
    if [[ -z "${kp_user}" ]]; then
        kp_user="${USER:-}"
        # Termux app UID; ignore even when USER is set (vault ${USER:-whoami} is not enough).
        if [[ -z "${kp_user}" || "${kp_user}" == u0_a* ]]; then
            kp_user="${ssh_hash[1]%%@*}"
        fi
        [[ -n "${kp_user}" && "${kp_user}" != u0_a* ]] || kp_user="$(whoami)"
    fi
    export KP_KDBX="${KP_KDBX:-${HOME}/Documents/${kp_user}.kdbx}"
    [[ -e "${KP_KDBX}" ]] || {
        echo "${FUNCNAME[1]}: kdbx missing: ${KP_KDBX}" >&2
        return 1
    }
    if [[ -n "${KP_KEYX:-}" && -e "${KP_KEYX}" ]]; then
        export KP_KEYX
    elif [[ -e "${HOME}/Documents/${kp_user}.keyx" ]]; then
        export KP_KEYX="${HOME}/Documents/${kp_user}.keyx"
    else
        unset KP_KEYX
    fi
}

function _kp_py() {
    "${PYTHON:-python}" - "$@" <<'PY'
import json, os, sys
from urllib.parse import parse_qs, quote, unquote, urlparse
from pykeepass import PyKeePass
import pyotp

cmd = sys.argv[1]
# rm accepts -f/--force anywhere after the command; keep only the query.
if cmd == "rm":
    query = next((a for a in sys.argv[2:] if a not in ("-f", "--force")), "")
else:
    query = sys.argv[2]
kdbx = os.environ["KP_KDBX"]
keyx = os.environ.get("KP_KEYX") or None
if keyx and not os.path.exists(keyx):
    keyx = None
kp = PyKeePass(kdbx, password=os.environ["KP_PASS"], keyfile=keyx)
show_secrets = os.environ.get("KP_SHOW_SECRETS", "") in ("1", "true", "yes")
set_value = os.environ.get("KP_SET_VALUE")
# Unset so child dumps / crash traces never reprint it.
os.environ.pop("KP_SET_VALUE", None)
rm_confirm = os.environ.get("KP_RM_CONFIRM", "") == "1"
os.environ.pop("KP_RM_CONFIRM", None)

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
        "Tags": tag_list(e),
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

def tag_list(e):
    t = getattr(e, "tags", None)
    if not t:
        return []
    if isinstance(t, str):
        return [x.strip() for x in t.replace(";", ",").split(",") if x.strip()]
    return [str(x).strip() for x in t if str(x).strip()]

def ensure_group(parts):
    g = kp.root_group
    for name in parts:
        if not name or name == "Root":
            continue
        child = None
        for c in (getattr(g, "subgroups", None) or []):
            if (getattr(c, "name", None) or "") == name:
                child = c
                break
        if child is None:
            child = kp.add_group(g, name)
        g = child
    return g

def otpauth_from(secret, title):
    s = (secret or "").strip()
    if s.startswith("otpauth://"):
        return s
    s = s.replace(" ", "").upper()
    if not s:
        raise ValueError("empty TOTP secret")
    label = quote(title or "entry", safe="")
    return f"otpauth://totp/{label}?secret={s}&period=30&digits=6"

hits = entries(query, exact=(cmd != "find"))
if cmd == "find":
    if len(query) < 3:
        sys.stderr.write("kp_find: query must be at least 3 characters\n")
        sys.exit(2)
    loc = [{"Path": group_path(e), "Title": e.title or ""} for e in hits]
    json.dump(loc, sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.exit(0 if hits else 1)
if cmd == "add":
    # Entry creation: blank Path/Title entry only. dest is the argv query
    # (no secret); set fields afterwards via kp_user/kp_pass/kp_url/kp_otp/
    # kp_note/kp_field.
    dest = query.strip()
    if not dest:
        sys.stderr.write("kp_add: dest required (Group/Title or Title)\n")
        sys.exit(2)
    if dest.endswith("/"):
        sys.stderr.write("kp_add: title required (dest ends in '/'): %s\n" % dest)
        sys.exit(2)
    parts = [p for p in dest.split("/") if p]
    title = parts[-1]
    new_path = "/".join(parts)
    if any(group_path(x) == new_path for x in live()):
        sys.stderr.write("kp_add: entry exists: %s\n" % new_path)
        sys.exit(1)
    new_entry = kp.add_entry(ensure_group(parts[:-1]), title)
    kp.save()
    sys.stderr.write("added %s\n" % group_path(new_entry))
    sys.exit(0)
if not hits:
    sys.exit(1)
if cmd != "find" and len(hits) > 1:
    sys.stderr.write("ambiguous title; use Path:\n")
    for e in hits:
        sys.stderr.write("  " + group_path(e) + "\n")
    sys.exit(1)
e = hits[0]
if cmd == "rm":
    # Dry run (KP_RM_CONFIRM unset) only resolves the entry: prints its Path.
    # Confirm run moves to the Recycle Bin: trash_entry when this pykeepass
    # has it, else move_entry into recyclebin_group (found or created).
    # -f hard-deletes instead.
    rm_force = any(a in ("-f", "--force") for a in sys.argv[3:])
    rm_path = group_path(e)
    if not rm_confirm:
        sys.stdout.write(rm_path)
        sys.exit(0)
    if rm_force:
        kp.delete_entry(e)
        kp.save()
        sys.stderr.write("deleted %s\n" % rm_path)
    else:
        if hasattr(kp, "trash_entry"):
            kp.trash_entry(e)
        else:
            try:
                rb = kp.recyclebin_group
            except Exception:
                rb = None
            if rb is None:
                for c in (getattr(kp.root_group, "subgroups", None) or []):
                    if (getattr(c, "name", None) or "") == "Recycle Bin":
                        rb = c
                        break
            if rb is None:
                rb = kp.add_group(kp.root_group, "Recycle Bin")
            if e.group is not rb:
                kp.move_entry(e, rb)
        kp.save()
        sys.stderr.write("moved to Recycle Bin: %s\n" % rm_path)
    sys.exit(0)
if cmd == "mv":
    raw = (set_value or "").strip()
    move_only = raw.endswith("/")
    dest = raw.strip("/")
    if not dest:
        sys.stderr.write("kp_mv: dest required\n")
        sys.exit(2)
    old = group_path(e)
    if not move_only and "/" not in dest:
        e.title = dest
    else:
        parts = [p for p in dest.split("/") if p]
        if not parts:
            sys.stderr.write("kp_mv: dest required\n")
            sys.exit(2)
        if move_only:
            grp = ensure_group(parts)
            title = e.title or ""
        else:
            grp = ensure_group(parts[:-1])
            title = parts[-1]
        if e.group is not grp:
            kp.move_entry(e, grp)
        if title and title != (e.title or ""):
            e.title = title
    kp.save()
    sys.stderr.write("moved %s -> %s\n" % (old, group_path(e)))
    sys.exit(0)
if cmd == "tag":
    cur = tag_list(e)
    if set_value is None:
        json.dump(cur, sys.stdout, indent=2)
        sys.stdout.write("\n")
        sys.exit(0 if cur else 1)
    added, removed = [], []
    for tok in set_value.split():
        if tok.startswith("-") and len(tok) > 1:
            name = tok[1:]
            if name in cur:
                cur = [x for x in cur if x != name]
                removed.append(name)
        else:
            name = tok[1:] if tok.startswith("+") and len(tok) > 1 else tok
            if name and name not in cur:
                cur.append(name)
                added.append(name)
    e.tags = cur
    kp.save()
    sys.stderr.write("tags %s +%s -%s -> %s\n" % (
        group_path(e), ",".join(added) or "-", ",".join(removed) or "-", ",".join(cur) or "(none)"))
    sys.exit(0)
if cmd == "field":
    # Custom fields (String properties). No name: JSON listing. Name only:
    # value to stdout (clipboard; rc 1 when missing). KP_SET_VALUE '-' deletes,
    # sets (created when missing). Reserved names go through kp_user etc.
    name = sys.argv[3] if len(sys.argv) > 3 else ""
    if name.lower() in ("username", "password", "url", "otp", "notes", "title"):
        sys.stderr.write("kp_field: field '%s' is reserved (use kp_user/kp_pass/kp_url/kp_otp/kp_note)\n" % name)
        sys.exit(2)
    props = dict(getattr(e, "custom_properties", None) or {})
    if not name:
        json.dump(props, sys.stdout, indent=2)
        sys.stdout.write("\n")
        sys.exit(0 if props else 1)
    if set_value is None:
        val = props.get(name) or ""
        if not val:
            sys.stderr.write("kp_field: no field '%s' on %s\n" % (name, group_path(e)))
            sys.exit(1)
        sys.stdout.write(val)
        sys.exit(0)
    if set_value == "-":
        if name not in props:
            sys.stderr.write("kp_field: no field '%s' on %s\n" % (name, group_path(e)))
            sys.exit(1)
        e.delete_custom_property(name)
        kp.save()
        sys.stderr.write("field %s %s deleted\n" % (group_path(e), name))
        sys.exit(0)
    e.set_custom_property(name, set_value)
    kp.save()
    sys.stderr.write("field %s %s set\n" % (group_path(e), name))
    sys.exit(0)
if cmd == "show":
    json.dump(rec(e), sys.stdout, indent=2)
    sys.stdout.write("\n")
elif cmd in ("UserName", "Password", "URL", "Notes", "OTP"):
    if set_value is not None:
        if cmd == "UserName":
            e.username = set_value
        elif cmd == "Password":
            e.password = set_value
        elif cmd == "URL":
            e.url = set_value
        elif cmd == "Notes":
            e.notes = set_value
        else:
            uri = otpauth_from(set_value, e.title or "")
            e.otp = uri
            try:
                e.set_custom_property("TimeOtp-Secret-Base32", parse_qs(urlparse(uri).query).get("secret", [""])[0])
            except Exception:
                pass
        kp.save()
        sys.stderr.write("updated %s on %s\n" % (cmd, group_path(e)))
        sys.exit(0)
    if cmd == "OTP":
        val = totp_code(e)
    elif cmd == "Password":
        val = e.password or ""
    elif cmd == "URL":
        val = e.url or ""
    elif cmd == "Notes":
        val = e.notes or ""
    else:
        val = e.username or ""
    if not val:
        sys.exit(1)
    sys.stdout.write(val)
else:
    sys.exit(2)
PY
}

function _kp_apply() {
    local field="${1-}" entry="${2-}" rc use
    if (( $# >= 2 )); then shift 2; else shift $#; fi
    # Usage line maps the pykeepass field to its kp_* wrapper name.
    case "${field}" in
        UserName) use="kp_user <entry> [value]" ;;
        Password) use="kp_pass <entry> [value|-]" ;;
        URL)      use="kp_url <entry> [value]" ;;
        OTP)      use="kp_otp <entry> [otpauth:// or base32]" ;;
        Notes)    use="kp_note <entry> [value]" ;;
        *)        use="kp_${field,,} <entry> [value]" ;;
    esac
    [[ -n "${entry}" ]] || { echo "usage: ${use}" >&2; return 2; }
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    if (($#)); then
        export KP_SET_VALUE="$*"
        _kp_py "${field}" "${entry}"
        rc=$?
        unset KP_SET_VALUE
        return "${rc}"
    fi
    local v
    v=$(_kp_py "${field}" "${entry}") || return 1
    clip_set "${v}"
}

function kp_user() {
    _kp_apply UserName "$@"
}

function kp_pass() {
    local entry="${1-}"
    [[ -n "${entry}" ]] || { echo "usage: kp_pass <entry> [value|-]" >&2; return 2; }
    if (($# == 1)); then
        _kp_apply Password "${entry}"
        return
    fi
    shift
    local val="$*"
    if [[ "${val}" == "-" || -z "${val}" ]]; then
        [[ -t 0 || -r /dev/tty ]] || { echo "kp_pass: no TTY for password" >&2; return 1; }
        printf "new password: " >/dev/tty
        read -r -s val </dev/tty
        printf "\n" >/dev/tty
        printf "again: " >/dev/tty
        local val2
        read -r -s val2 </dev/tty
        printf "\n" >/dev/tty
        [[ "${val}" == "${val2}" ]] || { echo "kp_pass: mismatch" >&2; return 1; }
        [[ -n "${val}" ]] || { echo "kp_pass: empty password" >&2; return 1; }
    fi
    _kp_apply Password "${entry}" "${val}"
}

function kp_url() {
    _kp_apply URL "$@"
}

function kp_note() {
    _kp_apply Notes "$@"
}

function kp_otp() {
    _kp_apply OTP "$@"
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

function kp_mv() {
    local entry="${1-}" dest="${2-}"
    [[ -n "${entry}" && -n "${dest}" && $# -ge 2 ]] || {
        echo "usage: kp_mv <entry> <dest>" >&2
        return 2
    }
    shift
    dest="$*"
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    export KP_SET_VALUE="${dest}"
    _kp_py mv "${entry}"
    local rc=$?
    unset KP_SET_VALUE
    return "${rc}"
}

function kp_tag() {
    local entry="${1-}"
    [[ -n "${entry}" ]] || { echo "usage: kp_tag <entry> [+tag|-tag …]" >&2; return 2; }
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    if (($# == 1)); then
        _kp_py tag "${entry}"
        return
    fi
    shift
    export KP_SET_VALUE="$*"
    _kp_py tag "${entry}"
    local rc=$?
    unset KP_SET_VALUE
    return "${rc}"
}

function kp_field() {
    local entry="${1-}" name="${2-}" val rc
    [[ -n "${entry}" ]] || { echo "usage: kp_field <entry> [name [value|-]]" >&2; return 2; }
    if (($# == 1)); then
        _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
        _kp_py field "${entry}"
        return
    fi
    [[ -n "${name}" ]] || { echo "kp_field: field name required" >&2; return 2; }
    # Reserved standard fields: route through kp_user/kp_pass/kp_url/kp_otp/kp_note.
    case "${name,,}" in
        username|password|url|otp|notes|title)
            echo "kp_field: field '${name}' is reserved (use kp_user/kp_pass/kp_url/kp_otp/kp_note)" >&2
            return 2 ;;
    esac
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    if (($# == 2)); then
        local v
        v=$(_kp_py field "${entry}" "${name}") || return 1
        clip_set "${v}"
        return
    fi
    # Set (create if missing) or delete ('-'); VALUE travels via KP_SET_VALUE.
    shift 2
    val="$*"
    export KP_SET_VALUE="${val}"
    _kp_py field "${entry}" "${name}"
    rc=$?
    unset KP_SET_VALUE
    return "${rc}"
}

function kp_add() {
    local dest="${1-}"
    [[ -n "${dest}" ]] || {
        echo "usage: kp_add <Group/Title|Title>" >&2
        return 2
    }
    [[ $# -eq 1 ]] || { echo "kp_add: unexpected argument: ${2}" >&2; return 2; }
    _kp_ready "${dest}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    # Blank Path/Title entry only; dest is the argv query (no secret). Fields
    # are set afterwards via kp_user/kp_pass/kp_url/kp_otp/kp_note/kp_tag/kp_field.
    _kp_py add "${dest}"
}

function kp_rm() {
    local entry="" force="" a
    for a in "$@"; do
        case "${a}" in
            -f|--force) force=1 ;;
            -*)
                echo "kp_rm: unknown argument: ${a}" >&2
                return 2 ;;
            *)
                [[ -z "${entry}" ]] || {
                    echo "kp_rm: unexpected argument: ${a}" >&2
                    return 2
                }
                entry="${a}" ;;
        esac
    done
    [[ -n "${entry}" ]] || { echo "usage: kp_rm <entry> [-f]" >&2; return 2; }
    _kp_ready "${entry}" || { [[ $? -eq 2 ]] && return 0; return 1; }
    local rc
    if [[ -n "${force}" ]]; then
        # Hard delete: no resolve/confirm pass (single kdbx open).
        export KP_RM_CONFIRM=1
        _kp_py rm "${entry}" -f
        rc=$?
        unset KP_RM_CONFIRM
        return "${rc}"
    fi
    # Same exact lookup as kp_show; dry run only resolves the entry's Path.
    local entry_path
    entry_path="$(_kp_py rm "${entry}")" || return 1
    [[ -t 0 || -r /dev/tty ]] || { echo "kp_rm: no TTY to confirm (use -f)" >&2; return 1; }
    local ans
    printf "moving %s to Recycle Bin: type the Path to confirm: " "${entry_path}" >/dev/tty
    read -r ans </dev/tty
    [[ "${ans}" == "${entry_path}" ]] || { echo "kp_rm: confirmation mismatch" >&2; return 1; }
    export KP_RM_CONFIRM=1
    _kp_py rm "${entry}"
    rc=$?
    unset KP_RM_CONFIRM
    return "${rc}"
}

export -f _kp_usage _kp_ready _kp_py _kp_apply \
    kp_user kp_pass kp_url kp_note kp_otp kp_show kp_find kp_mv kp_tag \
    kp_field kp_add kp_rm
