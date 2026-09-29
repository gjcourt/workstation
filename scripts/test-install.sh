#!/bin/bash
# test-install.sh — run install.sh (configs only, no Homebrew) against a
# throwaway $HOME, then check that every link is in place and that zsh and bash
# start without errors. Never touches the real $HOME.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

# A pre-existing config, to prove it's backed up rather than lost.
printf 'export OLD=1\n' >"$home/.zshrc"
mkdir -p "$home/.ssh" && printf 'Host old\n  HostName example.invalid\n' >"$home/.ssh/config"

HOME="$home" WORKSTATION_DIR="$repo" /bin/bash "$repo/install.sh" --no-brew

fail=0
check() { if eval "$2"; then echo "ok    $1"; else echo "FAIL  $1"; fail=1; fi; }

for pair in zsh/zshrc:.zshrc zsh/zprofile:.zprofile zsh/zshenv:.zshenv bash/bashrc:.bashrc \
            git/config:.gitconfig git/ignore:.config/git/ignore vim/vimrc:.vimrc \
            tmux/tmux.conf:.tmux.conf ssh/config:.ssh/config; do
  src="${pair%%:*}" dst="${pair#*:}"
  check "HOME/$dst -> $src" "[ \"\$(readlink '$home/$dst')\" = '$repo/$src' ]"
done
check "old .zshrc backed up" "grep -q OLD=1 '$home'/.workstation-backup/*/.zshrc"
check "old ssh config kept as config.local" "grep -q 'Host old' '$home/.ssh/config.local'"
check "HOME/.gitconfig.local created" "[ -f '$home/.gitconfig.local' ]"
check "HOME/.zshrc.local is mode 600" "[ \"\$(stat -f %Lp '$home/.zshrc.local')\" = 600 ]"
check "second run is a no-op" "HOME='$home' WORKSTATION_DIR='$repo' /bin/bash '$repo/install.sh' --no-brew >/dev/null && [ \$(ls '$home/.workstation-backup' | wc -l) -eq 1 ]"

# The shells must start with no errors on stderr.
check "zsh -l -i starts cleanly" "[ -z \"\$(HOME='$home' WORKSTATION_DIR='$repo' zsh -l -i -c exit 2>&1 >/dev/null)\" ]"
# bash -i without a terminal always prints job-control noise and echoes
# "exit"; ignore exactly those lines, fail on anything else.
check "bash -i starts cleanly"   "[ -z \"\$(HOME='$home' bash -i -c exit 2>&1 >/dev/null | grep -v -E 'no job control|terminal process group|^exit\$')\" ]"
check "git reads the config"     "HOME='$home' git config --global push.default | grep -qx current"
check "prompt renders the dir"   "HOME='$home' WORKSTATION_DIR='$repo' zsh -l -i -c 'print -P \"\$PROMPT\"' 2>/dev/null | grep -q ."

exit $fail
