<!-- readme-type: infra -->
# workstation

Set up a new Mac: shell, prompt, git, Homebrew and macOS defaults in one install

One command takes a fresh Mac to a working setup — zsh with a clean prompt,
git, the everyday command-line tools, and secrets from 1Password instead of
plaintext in dotfiles. Everything is symlinked from this repo, so a change
here is a change on every machine after a `git pull`.

**Status:** new (2026-09) — installed on one machine so far; CI installs it into a clean `$HOME` on macOS on every change.

A real run — configs only (`--no-brew`), into a `$HOME` that already had a `.zshrc`:

```text
$ ~/src/workstation/install.sh --no-brew
==> Using ~/src/workstation
==> Created ~/.zshrc.local
==> Created ~/.gitconfig.local
==> Created ~/.ssh/config.local
==> Linking configs into ~
==> Kept your ~/.zshrc settings: appended to ~/.zshrc.local
==> Backed up ~/.zshrc to ~/.workstation-backup/20260930-075703-30591/.zshrc
==> Done. Open a new terminal (or: exec zsh -l).
==> Replaced files are in ~/.workstation-backup/20260930-075703-30591
```

## Quick start

On a new Mac, in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/gjcourt/workstation/main/install.sh | bash
```

Then, in a new terminal:

```bash
gh auth login                                  # GitHub, for git over HTTPS
$EDITOR ~/.gitconfig.local                     # your name and email
~/src/workstation/install.sh --macos --extras  # optional: macOS defaults, extra tools
```

`install.sh --help` lists the options; `--dry-run` shows what would change.
Options go after `bash -s --` when piping, e.g. configs only, no Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/gjcourt/workstation/main/install.sh | bash -s -- --no-brew
```

## Layout

```text
install.sh         the installer: CLT → Homebrew → brew bundle → symlinks → local files
Brewfile           everyday tools (Brewfile.extras: hardware, media, one-offs)
zsh/               zshenv · zprofile · zshrc, plus prompt, path, aliases, completion, secrets
bash/              a small bash mirror of the zsh setup (same prompt and PATH)
git/               config (identity comes from ~/.gitconfig.local) and the global ignore
vim/ tmux/         editor and terminal-multiplexer config
ssh/               defaults only; hosts live in ~/.ssh/config.local
macos/defaults.sh  opt-in Finder, keyboard and screenshot settings
terminal/          the Terminal.app theme (IR_Black-2, Monaco) and its installer — applied with --macos
bin/               secrets-import: move plaintext secrets into 1Password
scripts/           test-install.sh: the CI install test
```

What's **not** in the repo, by design — created by `install.sh`, never
committed:

| File | For |
|---|---|
| `~/.zshrc.local` | machine-specific shell config: hosts, work env, extra PATH |
| `~/.bashrc.local`, `~/.vimrc.local` | the same for bash and vim |
| `~/.gitconfig.local` | git identity and signing |
| `~/.ssh/config.local` | ssh hosts |

Installing over an existing setup keeps it working. Every file `install.sh`
replaces is backed up to `~/.workstation-backup/<timestamp>/`, and an existing
`~/.zshrc`, `~/.bashrc` or `~/.vimrc` is also appended to its `.local` file —
loaded last, so your old settings still apply and win over the defaults. An
existing `~/.ssh/config` becomes `~/.ssh/config.local`, and git keeps your name
and email. Other replaced files (`~/.zprofile`, `~/.zshenv`, `~/.bash_profile`,
`~/.tmux.conf`, the rest of `~/.gitconfig`) aren't merged; `install.sh` warns
about each, and they're in the backup.
| `~/.config/workstation/secrets.env` | which 1Password item holds each secret (no values) |

### Secrets

No secret is ever in a dotfile. They live in 1Password and are fetched only
when a command needs them (Touch ID each time):

```bash
secrets-run make deploy       # run a command with every mapped secret in its environment
secrets-load GHCR_TOKEN       # export one into the current shell
secret GHCR_TOKEN | pbcopy    # print one
secrets-list                  # what's mapped (names only)
```

Moving an existing setup over: `bin/secrets-import --dry-run` lists the
`export NAME=value` secrets in `~/.zshrc` (or in `~/.zshrc.local`, once
`install.sh` has carried your old `~/.zshrc` into it); without `--dry-run` it
stores each in 1Password and writes the map. Then delete the plaintext lines —
and the backup `install.sh` made of your old `~/.zshrc`, which still has them.

## Making a change

1. Branch from `main` and edit the files in this repo — your `~` files are
   symlinks to them, so changes apply as soon as a new shell starts.
2. Run `make lint test`.
3. Open a PR; CI lints and runs the same install test on macOS.
4. After merging, other machines pick it up with `git -C ~/src/workstation pull`.

Nothing personal goes in the repo — it's public. Hostnames, IPs, identity and
secrets belong in the `*.local` files or 1Password.

## Development

```bash
make lint   # shellcheck (bash), zsh -n (zsh), ruff (bin/secrets-import)
make test   # install into a throwaway $HOME; check links, backups, and clean shell start-up
```

Conventions: [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
