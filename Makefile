# make lint — static checks (what CI runs first)
# make test — install into a throwaway $HOME and prove the shells start cleanly

BASH_FILES := install.sh scripts/test-install.sh macos/defaults.sh bash/bashrc bash/bash_profile
ZSH_FILES  := zsh/zshenv zsh/zprofile zsh/zshrc $(wildcard zsh/*.zsh)

.PHONY: lint test

lint:
	shellcheck --shell=bash $(BASH_FILES)
	@for f in $(ZSH_FILES); do zsh -n "$$f" || exit 1; done; echo "zsh -n: ok"
	ruff check bin/secrets-import
	ruff format --check bin/secrets-import

test:
	./scripts/test-install.sh
