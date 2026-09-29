# AGENTS.md

A public repo that sets up a Mac: `install.sh` symlinks the configs here into
`$HOME`. See [README.md](README.md) for the layout.

## Rules

- **Nothing personal or secret, ever.** The repo is public. Hostnames, IPs,
  usernames, identity, tokens and passwords go in the `*.local` files or
  1Password (`zsh/secrets.zsh`), never in a tracked file.
- **`install.sh` runs on macOS's `/bin/bash` 3.2** (it's piped from curl): no
  associative arrays, `${var,,}`, `mapfile` or other bash-4 features.
- **Idempotent.** Re-running `install.sh` must change nothing; `make test`
  checks this.
- **Additive PATH.** Only add a directory if it exists (see `zsh/path.zsh`).
- **Comment every file**: what it is, when it's loaded, and why a non-obvious
  line exists.
- **Before a PR:** `make lint test`. CI runs the same on macOS.
- Branch + PR for every change; never commit to `main`.
