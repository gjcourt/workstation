#!/bin/bash
# macos/defaults.sh — a conservative set of macOS preferences.
# Opt-in: run by `install.sh --macos`, or directly. Safe to re-run. Each
# setting says what it does; delete any you don't want. Some take effect only
# after logging out and back in.
set -euo pipefail

echo "Applying macOS defaults"

# --- Finder --------------------------------------------------------------------
defaults write NSGlobalDomain AppleShowAllExtensions -bool true        # show every file extension
defaults write com.apple.finder ShowPathbar -bool true                 # path bar at the bottom
defaults write com.apple.finder ShowStatusBar -bool true               # item count + free space
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"    # list view by default
defaults write com.apple.finder _FXSortFoldersFirst -bool true         # folders before files
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"    # search the current folder
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true   # no .DS_Store on network shares
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true       # …or USB drives

# --- Dialogs -------------------------------------------------------------------
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true    # expanded Save dialog
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true       # expanded Print dialog

# --- Keyboard & text -------------------------------------------------------------
defaults write NSGlobalDomain KeyRepeat -int 2                   # fast key repeat
defaults write NSGlobalDomain InitialKeyRepeat -int 20           # short delay before repeat
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false   # straight quotes (code-safe)
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false    # no -- → — conversion

# --- Screenshots ---------------------------------------------------------------
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"   # not the Desktop
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true             # no drop shadow on windows

# Restart the apps whose settings changed (ignore "not running").
for app in Finder SystemUIServer; do killall "$app" >/dev/null 2>&1 || true; done
echo "Done. Keyboard settings apply after logging out and back in."
