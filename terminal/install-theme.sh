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

current="$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null || true)"
installed=0
if defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q "\"$name\" ="; then
  installed=1
fi

if [ "$installed" -eq 1 ] && [ "$current" = "$name" ]; then
  echo "Terminal profile $name is already installed and the default."
  exit 0
fi

if [ "$installed" -eq 0 ]; then
  # Opening a .terminal file is how Terminal imports a profile; it also opens
  # one window using it. Give Terminal a moment to register the new profile.
  echo "Importing Terminal profile $name (a Terminal window will open)"
  open "$profile"
  sleep 2
fi

defaults write com.apple.Terminal "Default Window Settings" -string "$name"   # new windows/tabs
defaults write com.apple.Terminal "Startup Window Settings" -string "$name"   # first window at launch
echo "Terminal profile $name is the default (applies to new windows)."
