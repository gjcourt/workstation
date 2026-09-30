#!/bin/bash
# terminal/install-theme.sh — import the IR_Black-2 Terminal.app profile and
# make it the default for new windows and at launch.
#
# Run by `install.sh --macos` (or directly). Safe to re-run: skips the import
# when the profile is already installed and already the default.
#
# The profile (IR_Black-2.terminal) was exported from Terminal.app's own
# preferences: colours, key bindings, Monaco font (ships with macOS). To update
# it after changing the profile in Terminal → Settings → Profiles, re-export it
# with Terminal's "Export…" (gear menu) over this file.
set -euo pipefail

name="IR_Black-2"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="$here/$name.terminal"

has_profile() {
  defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q "\"$name\" ="
}

current="$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)"
installed=0
if has_profile; then
  installed=1
fi

if [ "$installed" -eq 1 ] && [ "$current" = "$name" ]; then
  echo "Terminal profile $name is already installed and the default."
  exit 0
fi

if [ "$installed" -eq 0 ]; then
  # Opening a .terminal file is how Terminal imports a profile; it also opens
  # one window using it. The import is asynchronous: wait (up to ~10s) for the
  # profile to appear in Terminal's preferences before pointing the default at it.
  echo "Importing Terminal profile $name (a Terminal window will open)"
  open "$profile"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    has_profile && break
    sleep 1
  done
  if ! has_profile; then
    echo "Terminal did not register profile $name; open $profile by hand and re-run." >&2
    exit 1
  fi
fi

# Set the default through Terminal itself rather than `defaults write`: a
# running Terminal holds these in memory, and plain `defaults write` on them is
# reported not to take effect (mathiasbynens/dotfiles#185; that repo's .macos
# and geerlingguy/mac-dev-playbook#26 both use this AppleScript instead). If
# scripting Terminal is refused (Automation permission), fall back to defaults.
if ! osascript -e "tell application \"Terminal\"
  set default settings to settings set \"$name\"
  set startup settings to settings set \"$name\"
end tell" >/dev/null 2>&1; then
  defaults write com.apple.Terminal "Default Window Settings" -string "$name"   # new windows/tabs
  defaults write com.apple.Terminal "Startup Window Settings" -string "$name"   # first window at launch
fi
echo "Terminal profile $name is the default (applies to new windows)."
