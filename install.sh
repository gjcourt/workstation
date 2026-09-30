#!/bin/bash
# install.sh — set up a Mac from this repo.
#
# Quick start on a brand-new Mac (nothing else needs to be installed first):
#
#   curl -fsSL https://raw.githubusercontent.com/gjcourt/workstation/main/install.sh | bash
#
# What it does, in order (each step is idempotent — re-running is safe):
#   1. Xcode Command Line Tools (provides git, needed to clone this repo)
#   2. Clone this repo to $WORKSTATION_DIR (default ~/src/workstation) if we
#      were piped from curl, then re-run from the checkout
#   3. Homebrew, then `brew bundle` from Brewfile (+ Brewfile.extras with --extras)
#   4. Symlink the configs in LINKS below into $HOME, backing up anything
#      they replace to ~/.workstation-backup/<timestamp>/. An existing
#      ~/.zshrc, ~/.bashrc or ~/.vimrc is also appended to its *.local file,
#      and an existing ~/.ssh/config becomes ~/.ssh/config.local, so what
#      you had keeps working.
#   5. Create the local, never-committed override files (*.local) if missing
#   6. With --macos: apply macos/defaults.sh and the Terminal.app theme
#
# Must run on /bin/bash 3.2 (what macOS ships and what `curl | bash` uses), so:
# no associative arrays, no ${var,,}, no mapfile.
set -euo pipefail

REPO_URL="https://github.com/gjcourt/workstation.git"
WORKSTATION_DIR="${WORKSTATION_DIR:-$HOME/src/workstation}"

# --- options -----------------------------------------------------------------

DRY_RUN=0 BREW=1 EXTRAS=0 MACOS=0
# The recognised flags, re-passed when the curl-piped copy re-runs itself from
# the checkout (step 2). A plain string, not an array: bash 3.2 + `set -u`
# treats an empty "${arr[@]}" as unbound. Flags never contain spaces.
FLAGS=""

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--no-brew] [--extras] [--macos]

  --dry-run   print what would change; change nothing
  --no-brew   skip Homebrew and `brew bundle` (configs only)
  --extras    also install Brewfile.extras (hardware, media, one-off tools)
  --macos     also apply macos/defaults.sh (Finder, keyboard, screenshots)
              and the Terminal.app theme (terminal/IR_Black-2.terminal)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-brew) BREW=0 ;;
    --extras) EXTRAS=1 ;;
    --macos) MACOS=1 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  FLAGS="$FLAGS $1"
  shift
done

# --- helpers -----------------------------------------------------------------

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

# run CMD... — execute, or just print it under --dry-run.
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# --- 1. Command Line Tools ---------------------------------------------------

ensure_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi
  say "Installing Xcode Command Line Tools (a dialog will appear)"
  run xcode-select --install || true
  [ "$DRY_RUN" -eq 1 ] && return
  # The installer is a GUI; wait for it rather than failing on the next git call.
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
}

# --- 2. Get a checkout -------------------------------------------------------

# Where this script lives, if it's a file (empty when piped from curl).
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

ensure_checkout() {
  # Already running from a checkout: use it.
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/zsh" ]; then
    WORKSTATION_DIR="$SCRIPT_DIR"
    return
  fi
  ensure_clt
  if [ -d "$WORKSTATION_DIR/.git" ]; then
    say "Updating $WORKSTATION_DIR"
    # Not fatal: a checkout with local work, or on no branch, is used as it is.
    run git -C "$WORKSTATION_DIR" pull --ff-only || warn "couldn't fast-forward $WORKSTATION_DIR; using it as is"
  else
    say "Cloning $REPO_URL to $WORKSTATION_DIR"
    run mkdir -p "$(dirname "$WORKSTATION_DIR")"
    run git clone "$REPO_URL" "$WORKSTATION_DIR"
  fi
  [ "$DRY_RUN" -eq 1 ] && { say "dry-run: would continue from $WORKSTATION_DIR/install.sh"; exit 0; }
  # Re-run from the checkout so every later step uses the repo's own files,
  # with the same flags ($FLAGS is unquoted on purpose: one word per flag).
  #
  # Under `curl | bash` stdin is the pipe the script arrived on, so anything
  # that reads stdin (the Homebrew installer's sudo prompt and "Press RETURN")
  # would read the rest of this script instead of the keyboard. Reattach stdin
  # to the terminal when there is one; with none (CI), Homebrew sees no TTY and
  # runs non-interactively by itself.
  if (exec </dev/tty) 2>/dev/null; then
    # shellcheck disable=SC2086
    exec /bin/bash "$WORKSTATION_DIR/install.sh" $FLAGS </dev/tty
  fi
  # shellcheck disable=SC2086
  exec /bin/bash "$WORKSTATION_DIR/install.sh" $FLAGS
}

# --- 3. Homebrew -------------------------------------------------------------

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    # Installed but not on PATH (this shell predates it): Apple Silicon, then Intel.
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$b" ] && eval "$("$b" shellenv)" && break
    done
  fi
  if ! command -v brew >/dev/null 2>&1; then
    say "Installing Homebrew"
    if [ "$DRY_RUN" -eq 1 ]; then
      run /bin/bash -c "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash"
      return
    fi
    # Interactive on purpose: a fresh Mac has no cached sudo, and the installer
    # must ask for the password (NONINTERACTIVE=1 would make it fail instead).
    # Without a TTY (CI) it switches to non-interactive mode on its own.
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # A fresh install isn't on PATH yet: load it the same way zsh/zprofile does.
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$b" ] && eval "$("$b" shellenv)" && break
    done
  fi
  # --no-upgrade: install what's missing; don't upgrade what's already there
  # (that's `brew upgrade`'s job, when you choose to run it).
  say "brew bundle (Brewfile)"
  run brew bundle install --no-upgrade --file="$WORKSTATION_DIR/Brewfile"
  if [ "$EXTRAS" -eq 1 ]; then
    say "brew bundle (Brewfile.extras)"
    run brew bundle install --no-upgrade --file="$WORKSTATION_DIR/Brewfile.extras"
  fi
}

# --- 4. Symlinks -------------------------------------------------------------

# "source-in-repo:target-under-home" — one per line. Targets are relative to $HOME.
LINKS="
zsh/zshenv:.zshenv
zsh/zprofile:.zprofile
zsh/zshrc:.zshrc
bash/bash_profile:.bash_profile
bash/bashrc:.bashrc
git/config:.gitconfig
git/ignore:.config/git/ignore
vim/vimrc:.vimrc
tmux/tmux.conf:.tmux.conf
ssh/config:.ssh/config
"

# One directory per run. The PID suffix keeps two runs in the same second from
# sharing (and overwriting) a backup directory.
BACKUP_DIR="$HOME/.workstation-backup/$(date +%Y%m%d-%H%M%S)-$$"

# link SRC TARGET — make $HOME/TARGET a symlink to $WORKSTATION_DIR/SRC.
link() {
  src="$WORKSTATION_DIR/$1"
  dst="$HOME/$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return # already linked
  fi
  # Anything else at the target — a file, a directory, or a symlink to
  # somewhere else (e.g. an old dotfiles repo) — is moved aside, not deleted.
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    case "$2" in
      # A pre-existing ssh config keeps working: it becomes the local include.
      .ssh/config)
        if [ -e "$HOME/.ssh/config.local" ]; then
          run mkdir -p "$BACKUP_DIR/.ssh" && run mv "$dst" "$BACKUP_DIR/.ssh/config"
          say "Backed up ~/.ssh/config to $BACKUP_DIR/.ssh/config"
        else
          say "Keeping your existing ~/.ssh/config as ~/.ssh/config.local"
          run mv "$dst" "$HOME/.ssh/config.local"
        fi
        ;;
      *)
        # Configs whose repo version sources a *.local file keep working too:
        # the old contents are appended to that file before the move.
        # The rest have no *.local hook (git keeps only your identity), so say
        # plainly that anything else in them now lives only in the backup.
        case "$2" in
          .zshrc | .bashrc | .vimrc) carry_over "$dst" "$dst.local" ;;
          *) if [ -s "$dst" ]; then warn "Replaced ~/$2 without merging: copy anything you still need from the backup"; fi ;;
        esac
        run mkdir -p "$(dirname "$BACKUP_DIR/$2")"
        run mv "$dst" "$BACKUP_DIR/$2"
        say "Backed up ~/$2 to $BACKUP_DIR/$2"
        ;;
    esac
  fi
  run ln -s "$src" "$dst"
}

# carry_over OLD LOCAL — append the contents of an existing config (a file, or
# a symlink to one, e.g. from an old dotfiles repo) to its *.local override,
# which the repo's version sources last, so the old settings still apply and
# win over the defaults. The old contents are kept verbatim, between a guard
# and its reset: an old config that sources LOCAL (in any form — a one-liner,
# an if/fi or if/endif block, a variable) would otherwise make LOCAL source
# itself forever. On that nested source the guard returns early, so only the
# part of LOCAL above the block runs twice.
carry_over() {
  [ -f "$1" ] && [ -s "$1" ] || return 0 # nothing to keep (or a directory)
  name="$(basename "$2")"
  # A symlink into another workstation checkout (the repo was moved or
  # re-cloned) is this repo's own config, not settings to keep.
  if [ -L "$1" ]; then
    target="$(readlink "$1")"
    case "$target" in /*) ;; *) target="$(dirname "$1")/$target" ;; esac
    if grep -q 'gjcourt/workstation' "$(dirname "$target")/../install.sh" 2>/dev/null; then
      say "Not carrying over ~/$(basename "$1"): it was another workstation checkout's"
      return 0
    fi
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    say "[dry-run] would append ~/$(basename "$1") to ~/$name"
    return 0
  fi
  # vim comments start with ", not #; the guard is per file (.zshrc -> zshrc).
  guard="_workstation_carry_$(basename "$1" | tr -cd '[:alnum:]')"
  if [ "$name" = .vimrc.local ]; then
    c='"'
    open="if exists('g:$guard') | finish | endif | let g:$guard = 1"
    close="unlet g:$guard"
  else
    c='#'
    open="if [ -n \"\${$guard:-}\" ]; then return 0; fi; $guard=1"
    close="unset $guard"
  fi
  (
    umask 077 # LOCAL may not exist yet, and the old file may hold secrets
    {
      printf '\n%s --- Carried over from your previous ~/%s by install.sh, %s.\n' \
        "$c" "$(basename "$1")" "$(date +%Y-%m-%d)"
      printf '%s --- The original is in %s. Trim what the repo already does.\n' "$c" "$BACKUP_DIR"
      printf '%s\n' "$open"
      cat "$1"
      # No trailing newline: don't let the reset join the last old line.
      if [ -n "$(tail -c 1 "$1")" ]; then echo; fi
      printf '%s\n%s --- End of your previous ~/%s.\n' "$close" "$c" "$(basename "$1")"
    } >>"$2"
  )
  chmod 600 "$2"
  say "Kept your ~/$(basename "$1") settings: appended to ~/$name"
}

link_all() {
  say "Linking configs into $HOME"
  echo "$LINKS" | while IFS=: read -r src dst; do
    # `if`, not `[ … ] && link`: under set -e + pipefail a false test on the
    # blank last line would otherwise abort the whole install.
    if [ -n "$src" ]; then link "$src" "$dst"; fi
  done
}

# --- 5. Local overrides ------------------------------------------------------

# touch_local PATH HEADER — create an override file (mode 600) if it's missing.
touch_local() {
  [ -e "$1" ] && return
  run mkdir -p "$(dirname "$1")"
  if [ "$DRY_RUN" -eq 1 ]; then
    run touch "$1"
    return
  fi
  printf '%s\n' "$2" >"$1"
  chmod 600 "$1"
  say "Created $1"
}

make_locals() {
  touch_local "$HOME/.zshrc.local" "# Machine-specific zsh config (not in git): hosts, work env, extra PATH.
# Secrets don't go here — see 'secrets' in the workstation README."

  # Carry git identity over from an existing config when there is one. This
  # runs before link_all, so on a first install ~/.gitconfig is still the old
  # file; --includes also finds an identity kept in a file it includes.
  name="$(git config --global --includes user.name 2>/dev/null || true)"
  email="$(git config --global --includes user.email 2>/dev/null || true)"
  touch_local "$HOME/.gitconfig.local" "# Machine-specific git config (not in git): identity, signing.
[user]
	name = ${name:-Your Name}
	email = ${email:-you@example.com}"

  # Skip when a real ~/.ssh/config exists: link() moves it to config.local
  # instead, so existing hosts keep working.
  if [ -L "$HOME/.ssh/config" ] || [ ! -e "$HOME/.ssh/config" ]; then
    touch_local "$HOME/.ssh/config.local" "# Machine-specific ssh hosts (not in git). Keys stay in ~/.ssh, never in the repo."
  fi
  # ssh refuses keys in a group/world-readable ~/.ssh; mkdir may have made it 755.
  [ "$DRY_RUN" -eq 1 ] || { mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; }
}

# --- main --------------------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || { warn "this installer targets macOS"; exit 1; }

ensure_checkout
say "Using $WORKSTATION_DIR"
[ "$BREW" -eq 1 ] && ensure_brew
make_locals # before linking: git/config includes ~/.gitconfig.local
link_all
if [ "$MACOS" -eq 1 ]; then
  say "Applying macOS defaults"
  run /bin/bash "$WORKSTATION_DIR/macos/defaults.sh"
  say "Installing the Terminal.app theme"
  run /bin/bash "$WORKSTATION_DIR/terminal/install-theme.sh"
fi
say "Done. Open a new terminal (or: exec zsh -l)."
[ -d "$BACKUP_DIR" ] && say "Replaced files are in $BACKUP_DIR"
exit 0
