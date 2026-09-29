# prompt.zsh — the prompt:  <dir> <git-branch> $
#
#   workstation feat/initial-layout $
#
# Colours are 256-colour indexes: 33 = blue (directory), 40 = green (branch),
# 99 = purple ($). The branch only shows inside a git repo, with no stray space.

setopt PROMPT_SUBST

# git_branch — current branch (or short SHA when detached), empty outside a repo.
git_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  [[ -n "$b" ]] && print -n "$b "
}

PROMPT='%F{33}%1~%f %F{40}$(git_branch)%F{99}%(!.#.$)%f '

# Some tools (VS Code's shell integration) break if RPROMPT is unset.
RPROMPT="${RPROMPT-}"
