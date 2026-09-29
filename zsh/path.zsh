# path.zsh — PATH additions, sourced from zprofile.
#
# Each directory is added only if it exists, so a fresh Mac gets a short,
# honest PATH and a tool's directory appears the moment the tool is installed.
# `typeset -U` keeps PATH free of duplicates however often this is sourced.

typeset -U path

# path_prepend DIR... — put existing DIRs at the front of PATH, in order given.
path_prepend() {
  local d
  for d in "${(Oa)@}"; do            # reverse, so the first argument ends up first
    [[ -d "$d" ]] && path=("$d" $path)
  done
}

path_prepend \
  "$HOME/bin" \
  "$HOME/.bin" \
  "$HOME/.local/bin" \
  "$HOME/go/bin" \
  "${KREW_ROOT:-$HOME/.krew}/bin" \
  "$HOME/.foundry/bin"

export GOPATH="$HOME/go"

# Tool installers that ship an env script (uv, tempoup): source if present.
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
[[ -f "$HOME/.tempo/env" ]] && source "$HOME/.tempo/env"

unfunction path_prepend
