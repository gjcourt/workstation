# prompt.zsh — the prompt:  <dir> <git-branch> $
#
#   workstation feat/initial-layout $
#
# Colours are 256-colour indexes: 33 = blue (directory), 40 = green (branch),
# 99 = purple ($). The branch only shows inside a git repo, with no stray space.
#
# Same look as the old dotfiles prompt,
#   PROMPT='%F{33}%1~ %F{40}$(git_branch) %F{99}\$%f '
# except: no double space outside a repo, colours reset after each part, and
# `#` instead of `$` in a root shell.

setopt PROMPT_SUBST

# git_branch — current branch (or short SHA when detached), empty outside a repo.
git_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  # PROMPT_SUBST output still gets %-escapes expanded; double any % so a
  # branch like "fix-100%" prints literally.
  [[ -n "$b" ]] && print -rn -- "${b//\%/%%} "
}

PROMPT='%F{33}%1~%f %F{40}$(git_branch)%F{99}%(!.#.$)%f '

# Some tools (VS Code's shell integration) break if RPROMPT is unset.
RPROMPT="${RPROMPT-}"
