# aliases.zsh — short names for things typed all day. Sourced from zshrc.

# Navigation / listing
alias ..='cd ..'
alias ls='ls -G'            # -G: colour on macOS
alias ll='ls -lh'
alias la='ls -A'
alias lla='ls -lhA'

# Show only dotfiles in the current directory.
dot() { ls -A "$@" | grep '^\.'; }

alias grep='grep --color=auto'
alias python='python3'

# Kubernetes / Talos (only if installed, so a fresh Mac doesn't have dead aliases)
(( $+commands[kubectl] ))  && alias k='kubectl'
(( $+commands[talosctl] )) && alias t='talosctl'
