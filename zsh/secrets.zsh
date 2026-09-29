# secrets.zsh — secrets from 1Password, loaded on demand, never on disk.
# Sourced from zshrc (interactive shells); defines functions only.
#
# Nothing secret is exported when a shell starts. A local, never-committed map
# (default ~/.config/workstation/secrets.env) lists each secret as a 1Password
# reference, in the dotenv format `op run --env-file` reads (KEY=value lines,
# `#` comments):
#
#   GHCR_TOKEN=op://Private/workstation-GHCR_TOKEN/credential
#
# Then, when a command needs them:
#
#   secrets-run make deploy        # run one command with every secret in its env
#   secrets-load GHCR_TOKEN        # export named secrets into this shell
#   secret GHCR_TOKEN | pbcopy     # print one secret (e.g. to pipe it)
#   secrets-list                   # which names are mapped (no values)
#
# Everything goes through the 1Password CLI (`op`), which asks for Touch ID.
# bin/secrets-import moves existing `export NAME=value` lines into 1Password
# and writes the map for you.

WORKSTATION_SECRETS="${WORKSTATION_SECRETS:-${XDG_CONFIG_HOME:-$HOME/.config}/workstation/secrets.env}"

_secrets_ready() {
  if ! (( $+commands[op] )); then
    print -u2 "secrets: the 1Password CLI isn't installed (brew install 1password-cli)"
    return 1
  fi
  if [[ ! -r "$WORKSTATION_SECRETS" ]]; then
    print -u2 "secrets: no map at $WORKSTATION_SECRETS (see bin/secrets-import)"
    return 1
  fi
}

# _secrets_ref NAME — the op:// reference mapped to NAME (the last one, if a
# name appears twice); fails if NAME isn't a valid variable name or isn't mapped.
_secrets_ref() {
  [[ "$1" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || return 1   # also keeps the grep below regex-safe
  local line
  line=$(grep -E "^$1=" "$WORKSTATION_SECRETS" | tail -1)
  [[ -n "$line" ]] || return 1
  print -r -- "${line#*=}"
}

# secrets-list — the mapped names, one per line. No values, no Touch ID.
secrets-list() {
  _secrets_ready || return
  grep -E '^[A-Z_][A-Z0-9_]*=' "$WORKSTATION_SECRETS" | cut -d= -f1
}

# secret NAME — print one secret's value on stdout.
secret() {
  (( $# == 1 )) || { print -u2 "usage: secret NAME"; return 2; }
  _secrets_ready || return
  local ref
  ref=$(_secrets_ref "$1") || { print -u2 "secret: $1 isn't mapped"; return 1; }
  op read -- "$ref"
}

# secrets-load NAME… — export the named secrets into this shell (until it exits).
secrets-load() {
  (( $# )) || { print -u2 "usage: secrets-load NAME…"; return 2; }
  _secrets_ready || return
  local name ref value
  for name in "$@"; do
    ref=$(_secrets_ref "$name") || { print -u2 "secrets-load: $name isn't mapped"; return 1; }
    value=$(op read -- "$ref") || return
    export "$name=$value"
  done
}

# secrets-run COMMAND… — run COMMAND with every mapped secret in its
# environment; this shell never sees them. (`op run` also masks any secret the
# command prints; pass `op run --no-masking` yourself if that gets in the way.)
secrets-run() {
  (( $# )) || { print -u2 "usage: secrets-run COMMAND…"; return 2; }
  _secrets_ready || return
  op run --env-file="$WORKSTATION_SECRETS" -- "$@"
}
