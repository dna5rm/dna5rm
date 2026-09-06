# Bash ENV

profile.d functions load at login from dna5rm (clone + symlink). Portable: Linux x86/x64, Pi, Termux. First-box install (symlink rc files): `install-home.sh` in the repo root, not this directory.

Rule: these files only define functions / cheap local aliases. Do not call other profile.d functions at source time. Lexical glob order must not matter.

`Run-Command` is defined in `.bashrc` (not here). Session work is `$RCPATH/session.sh`, sourced after the glob (ssh_hash, one Get-Vault decrypt, cloginrc, ssh-agent).

Host-only quirks live in `$HOME/.env` (gitignored). Sourced *before* venv. Pin the interpreter with `PYTHON=python3.11` on Termux; do not alias `python3` for venv bootstrap.

PowerShell approved verbs for function names. Do not split Get-Hash / Get-SshKeyFingerprint out of Vault.sh.

Files (topic names, not load-order prefixes):

  Assert.sh         Assert-ContainsElement, Assert-StrIsDns, Assert-StrIsEmail
  Convert.sh        j2y y2j x2j
  Crypt.sh          crypt
  Git.sh            git_pull git_push git_diff proj_pull proj_status
  Google-Cloud.sh   gcloud PATH/completion if SDK present
  New-Password.sh   New-Password
  Prompt.sh         set_prompt
  Python.sh         Ensure-Pip pyhttpd pip-update
  Rclone.sh         rclone-sync
  Termux.sh         Termux-only aliases/functions
  Vault.sh          Get-Hash Get-SshKeyFingerprint Get-Vault Edit/Initialize/Protect/Unprotect-Vault vssh
