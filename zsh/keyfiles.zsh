# keyfiles.zsh — back up and restore whole key files through 1Password.
# Sourced from zshrc (interactive shells); defines functions only.
#
# secrets.zsh handles secrets that are *values* (env vars). Some secrets are
# *files*: a git-crypt key, an API key file a tool reads from ~/.config. These
# helpers keep such files at
#
#   $KEYFILES_DIR/<app>/<file>          (default KEYFILES_DIR: ~/.config)
#
# and mirror each one to a 1Password document titled `secret:<app>/<file>`,
# tagged `secret,<app>`, in $KEYFILES_VAULT. The title encodes the path, so
# restoring needs nothing but 1Password.
#
#   keyfile-save git-crypt george.key   # store or update one file
#   keyfile-get  git-crypt george.key   # restore one file (dir 700, file 600)
#   keyfile-list                        # what's stored
#   keyfile-sync                        # re-store every tracked file that changed
#   keyfile-restore                     # restore everything (new machine)
#
# Set in ~/.zshrc.local (never committed — it names your account and vault):
#
#   export OP_ACCOUNT=<your-account>.1password.com   # which 1Password account
#   export KEYFILES_VAULT=<vault>                    # where the documents live

: "${KEYFILES_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}}"

_keyfiles_ready() {
  if ! (( $+commands[op] )); then
    print -u2 "keyfiles: the 1Password CLI isn't installed (brew install 1password-cli)"
    return 1
  fi
  if [[ -z "$KEYFILES_VAULT" ]]; then
    print -u2 "keyfiles: set KEYFILES_VAULT in ~/.zshrc.local"
    return 1
  fi
}

# _keyfiles_args APP FILE — validate both parts (no path tricks like ../).
_keyfiles_args() {
  [[ -n "$1" && -n "$2" && "$1" != *..* && "$2" != *..* && "$2" != */* ]]
}

# _keyfiles_titles — every `secret:<app>/<file>` title in the vault, one per line.
# Fails with op's own message (e.g. "not signed in") rather than a parse error.
_keyfiles_titles() {
  local json
  if ! json=$(op item list --vault "$KEYFILES_VAULT" --tags secret --format json 2>&1) ||
     [[ "$json" != \[* ]]; then
    print -u2 "keyfiles: ${json:-op item list failed}"
    return 1
  fi
  print -r -- "$json" |
    python3 -c 'import json,sys; [print(i["title"]) for i in json.load(sys.stdin) if i["title"].startswith("secret:")]'
}

# keyfile-save APP FILE — create or update the 1Password document for one file.
keyfile-save() {
  emulate -L zsh
  _keyfiles_args "$1" "$2" || { print -u2 "usage: keyfile-save APP FILE"; return 2; }
  _keyfiles_ready || return
  local file="$KEYFILES_DIR/$1/$2" title="secret:$1/$2"
  [[ -f "$file" ]] || { print -u2 "keyfile-save: no such file: $file"; return 1; }
  if op document get "$title" --vault "$KEYFILES_VAULT" >/dev/null 2>&1; then
    op document edit "$title" "$file" --vault "$KEYFILES_VAULT" --file-name "$2" >/dev/null &&
      print "updated $title"
  else
    op document create "$file" --title "$title" --vault "$KEYFILES_VAULT" \
      --file-name "$2" --tags "secret,$1" >/dev/null &&
      print "saved $title"
  fi
}

# keyfile-get APP FILE — restore one file from 1Password, owner-only permissions.
keyfile-get() {
  emulate -L zsh
  _keyfiles_args "$1" "$2" || { print -u2 "usage: keyfile-get APP FILE"; return 2; }
  _keyfiles_ready || return
  local dir="$KEYFILES_DIR/$1"
  mkdir -p "$dir" && chmod 700 "$dir"
  (umask 077; op document get "secret:$1/$2" --vault "$KEYFILES_VAULT" --out-file "$dir/$2" --force >/dev/null) &&
    chmod 600 "$dir/$2" && print "restored $dir/$2"
}

# keyfile-list — titles of every stored key file. No values.
keyfile-list() {
  _keyfiles_ready || return
  _keyfiles_titles
}

# _keyfiles_each — titles into the caller's `titles` array; fails if op does.
_keyfiles_each() {
  local out
  out=$(_keyfiles_titles) || return
  titles=(${(f)out})
}

# keyfile-sync — re-store every tracked file whose contents changed locally.
keyfile-sync() {
  emulate -L zsh
  _keyfiles_ready || return
  local title rest app name file
  local -a titles
  _keyfiles_each || return
  for title in $titles; do
    rest="${title#secret:}"; app="${rest%/*}"; name="${rest##*/}"
    file="$KEYFILES_DIR/$app/$name"
    if [[ ! -f "$file" ]]; then
      print -u2 "keyfile-sync: $file missing locally; skipped"
      continue
    fi
    # Compare checksums so an unchanged file doesn't create a new version.
    if [[ "$(shasum -a 256 < "$file")" == \
          "$(op document get "$title" --vault "$KEYFILES_VAULT" 2>/dev/null | shasum -a 256)" ]]; then
      print "unchanged: $title"
    else
      keyfile-save "$app" "$name"
    fi
  done
}

# keyfile-restore — restore every stored key file (setting up a new machine).
keyfile-restore() {
  emulate -L zsh
  _keyfiles_ready || return
  local title rest
  local -a titles
  _keyfiles_each || return
  for title in $titles; do
    rest="${title#secret:}"
    keyfile-get "${rest%/*}" "${rest##*/}"
  done
}
