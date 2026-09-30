#!/bin/bash
# test-install.sh — run install.sh (configs only, no Homebrew) against a
# throwaway $HOME, then check that every link is in place and that zsh and bash
# start without errors. Never touches the real $HOME.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

# Pre-existing configs, to prove they're backed up and carried over, not lost.
# The .zshrc also sources its own .local file, which must not loop; the .vimrc
# is a symlink into an "old dotfiles repo", which must still be read.
printf 'export OLD=1\n[ -f ~/.zshrc.local ] && source ~/.zshrc.local\n' >"$home/.zshrc"
printf 'export OLD_BASH=1\n' >"$home/.bashrc"
mkdir -p "$home/old-dotfiles" && printf 'set number\n' >"$home/old-dotfiles/vimrc"
ln -s "$home/old-dotfiles/vimrc" "$home/.vimrc"
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
check "old .zshrc carried into .zshrc.local" "grep -qx 'export OLD=1' '$home/.zshrc.local'"
check "self-sourcing line disabled" "grep -q '^# \\[install.sh: would source itself\\] \\[ -f ~/.zshrc.local' '$home/.zshrc.local'"
check "old .bashrc carried into .bashrc.local" "grep -qx 'export OLD_BASH=1' '$home/.bashrc.local'"
check "symlinked old .vimrc carried over" "grep -qx 'set number' '$home/.vimrc.local'"
check "carried-over settings apply in zsh" "[ \"\$(HOME='$home' env -u WORKSTATION_DIR zsh -l -i -c 'echo \$OLD' 2>/dev/null)\" = 1 ]"
check "old ssh config kept as config.local" "grep -q 'Host old' '$home/.ssh/config.local'"
check "HOME/.gitconfig.local created" "[ -f '$home/.gitconfig.local' ]"
check "HOME/.zshrc.local is mode 600" "[ \"\$(stat -f %Lp '$home/.zshrc.local')\" = 600 ]"
check "second run is a no-op" "HOME='$home' WORKSTATION_DIR='$repo' /bin/bash '$repo/install.sh' --no-brew >/dev/null && [ \$(ls '$home/.workstation-backup' | wc -l) -eq 1 ] && [ \$(grep -c 'Carried over' '$home/.zshrc.local') -eq 1 ]"

# The shells must start with no errors on stderr. WORKSTATION_DIR is unset so
# zshenv has to find the checkout by following the ~/.zshenv symlink.
check "zsh -l -i starts cleanly" "[ -z \"\$(HOME='$home' env -u WORKSTATION_DIR zsh -l -i -c exit 2>&1 >/dev/null)\" ]"
# bash -i without a terminal always prints job-control noise and echoes
# "exit"; ignore exactly those lines, fail on anything else.
check "bash -i starts cleanly"   "[ -z \"\$(HOME='$home' bash -i -c exit 2>&1 >/dev/null | grep -v -E 'no job control|terminal process group|^exit\$')\" ]"
check "git reads the config"     "HOME='$home' git config --global push.default | grep -qx current"
check "prompt renders the dir"   "HOME='$home' env -u WORKSTATION_DIR zsh -l -i -c 'print -P \"\$PROMPT\"' 2>/dev/null | grep -q ."
# tmux reports unknown options on stderr; a clean source-file prints nothing.
if command -v tmux >/dev/null 2>&1; then
  sock="ws-test-$$"
  tmux_err="$(tmux -L "$sock" -f /dev/null start-server \; source-file "$repo/tmux/tmux.conf" 2>&1)" || true
  tmux -L "$sock" kill-server 2>/dev/null || true
  if [ -z "$tmux_err" ]; then r=true; else echo "$tmux_err"; r=false; fi
  check "tmux.conf loads without errors" "$r"
fi

# The curl-pipe path: script on stdin, flags after `bash -s --`, into a second
# throwaway HOME with its own clone (of the committed HEAD). It must re-run
# from the clone with the flags intact. A stub `brew` first on PATH records
# any call, so a dropped --no-brew fails the test instead of installing things.
home2="$(mktemp -d)"
trap 'rm -rf "$home" "$home2"' EXIT
git clone -q "$repo" "$home2/ws"
mkdir -p "$home2/stub"
printf '#!/bin/sh\necho "stub brew called: $*"\nexit 1\n' >"$home2/stub/brew"
chmod +x "$home2/stub/brew"
out="$(PATH="$home2/stub:$PATH" HOME="$home2" WORKSTATION_DIR="$home2/ws" \
  /bin/bash -s -- --no-brew <"$repo/install.sh" 2>&1)" || true
check "piped install re-runs from the clone" "[ \"\$(readlink '$home2/.zshrc')\" = '$home2/ws/zsh/zshrc' ]"
if printf '%s' "$out" | grep -q "stub brew called"; then r=false; else r=true; fi
check "piped install keeps its flags"        "$r"

exit $fail
