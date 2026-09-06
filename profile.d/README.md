# Bash ENV

profile.d functions load at login from dna5rm (clone + symlink). Portable: Linux x86/x64, Pi, Termux. First-box install (symlink rc files): `install-home.sh` in the repo root, not this directory.

Rule: these files only define functions / cheap local aliases. Do not call other profile.d functions at source time. Lexical glob order must not matter.

`run_command` is defined in `.bashrc` (not here). Session work is `$RCPATH/session.sh`, sourced after the glob (ssh_hash, one vault_get decrypt, cloginrc, ssh-agent).

Host-only quirks live in `$HOME/.env` (gitignored). Sourced *before* venv. Pin the interpreter with `PYTHON=python3.11` on Termux; do not alias `python3` for venv bootstrap.

Unix function names (prefix_verb). Do not split get_hash / ssh_fingerprint out of vault.sh.

Files (topic names, not load-order prefixes):

  assert.sh         assert_in dns email ipv4 cidr cmd file dir (no pip)
  clipboard.sh      clip_set clip_get
  convert.sh        j2y y2j x2j t2j j2t csv2j b64e b64d urlenc urldec
  crypt.sh          crypt (openssl AES-CBC)
  gpg.sh            gpg_init backup restore ls import export encrypt decrypt sign verify expire rotate revoke
  git.sh            git_pull git_push git_diff proj_pull proj_status
  keepass.sh        kp_user kp_pass kp_url kp_otp kp_show kp_find (KP_PASS from vault)
  password.sh       new_password
  prompt.sh         set_prompt
  python.sh         ensure_pip pyhttpd pip-update
  rclone.sh         rclone-sync
  termux.sh         Termux-only aliases/functions
  vault.sh          get_hash ssh_fingerprint vault_get vault_edit vault_init vault_protect vault_unprotect vssh
