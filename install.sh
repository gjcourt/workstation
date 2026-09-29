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
#      they replace to ~/.workstation-backup/<timestamp>/
#   5. Create the local, never-committed override files (*.local) if missing
#   6. With --macos: apply macos/defaults.sh
#
# Must run on /bin/bash 3.2 (what macOS ships and what `curl | bash` uses), so:
# no associative arrays, no ${var,,}, no mapfile.
set -euo pipefail

REPO_URL="https://github.com/gjcourt/workstation.git"
WORKSTATION_DIR="${WORKSTATION_DIR:-$HOME/src/workstation}"

# --- options -----------------------------------------------------------------

DRY_RUN=0 BREW=1 EXTRAS=0 MACOS=0

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--no-brew] [--extras] [--macos]

  --dry-run   print what would change; change nothing
  --no-brew   skip Homebrew and `brew bundle` (configs only)
  --extras    also install Brewfile.extras (hardware, media, one-off tools)
  --macos     also apply macos/defaults.sh (Finder, keyboard, screenshots)
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
    run git -C "$WORKSTATION_DIR" pull --ff-only
  else
    say "Cloning $REPO_URL to $WORKSTATION_DIR"
    run mkdir -p "$(dirname "$WORKSTATION_DIR")"
    run git clone "$REPO_URL" "$WORKSTATION_DIR"
  fi
  [ "$DRY_RUN" -eq 1 ] && { say "dry-run: would continue from $WORKSTATION_DIR/install.sh"; exit 0; }
  # Re-run from the checkout so every later step uses the repo's own files.
  exec /bin/bash "$WORKSTATION_DIR/install.sh" "$@"
}

# --- 3. Homebrew -------------------------------------------------------------

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
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
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$b" ] && eval "$("$b" shellenv)" && break
    done
  fi
  say "brew bundle (Brewfile)"
  run brew bundle --no-upgrade --file="$WORKSTATION_DIR/Brewfile"
  if [ "$EXTRAS" -eq 1 ]; then
    say "brew bundle (Brewfile.extras)"
    run brew bundle --no-upgrade --file="$WORKSTATION_DIR/Brewfile.extras"
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

BACKUP_DIR="$HOME/.workstation-backup/$(date +%Y%m%d-%H%M%S)"

# link SRC TARGET — make $HOME/TARGET a symlink to $WORKSTATION_DIR/SRC.
link() {
  src="$WORKSTATION_DIR/$1"
  dst="$HOME/$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    return # already linked
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    case "$2" in
      # A pre-existing ssh config keeps working: it becomes the local include.
      .ssh/config)
        if [ -e "$HOME/.ssh/config.local" ]; then
          run mkdir -p "$BACKUP_DIR/.ssh" && run mv "$dst" "$BACKUP_DIR/.ssh/config"
        else
          say "Keeping your existing ~/.ssh/config as ~/.ssh/config.local"
          run mv "$dst" "$HOME/.ssh/config.local"
        fi
        ;;
      *)
        run mkdir -p "$(dirname "$BACKUP_DIR/$2")"
        run mv "$dst" "$BACKUP_DIR/$2"
        say "Backed up ~/$2 to $BACKUP_DIR/$2"
        ;;
    esac
  fi
  run ln -s "$src" "$dst"
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

  # Carry git identity over from an existing config when there is one.
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
  [ "$DRY_RUN" -eq 1 ] || chmod 700 "$HOME/.ssh"
}

# --- main --------------------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || { warn "this installer targets macOS"; exit 1; }

ensure_checkout "$@"
say "Using $WORKSTATION_DIR"
[ "$BREW" -eq 1 ] && ensure_brew
make_locals # before linking: git/config includes ~/.gitconfig.local
link_all
if [ "$MACOS" -eq 1 ]; then
  say "Applying macOS defaults"
  run /bin/bash "$WORKSTATION_DIR/macos/defaults.sh"
fi
say "Done. Open a new terminal (or: exec zsh -l)."
[ -d "$BACKUP_DIR" ] && say "Replaced files are in $BACKUP_DIR"
exit 0
