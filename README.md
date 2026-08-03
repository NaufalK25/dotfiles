# dotfiles

Personal configuration for a fresh **Ubuntu VPS** setup — shell, editor, formatting,
and a handful of services (nginx, redis) bootstrapped in one script.

## What's in here

```
dotfiles/
├── vscode/
│   ├── extensions.json   # editor recommended extensions, linked into VS Code
│   └── settings.json     # editor settings, linked into VS Code
├── config/
│   └── rtk/
│       ├── config.toml   # rtk (token-saving CLI proxy) config, linked into ~/.config/rtk/
│       └── filters.toml  # rtk output filters
├── claude/
│   ├── CLAUDE.md          # global Claude instructions, linked into ~/.claude/
│   ├── RTK.md             # rtk usage reference for Claude, linked into ~/.claude/
│   └── settings.json      # Bash-rewrite hook wiring rtk into Claude Code, linked into ~/.claude/
├── gh/
│   └── config.yml         # gh CLI config (no tokens), linked into ~/.config/gh/
├── .editorconfig         # indent/whitespace rules, editor-agnostic
├── .gitattributes        # forces LF line endings
├── .gitconfig            # git identity + aliases
├── .gitignore_global     # machine-wide gitignore (node_modules, .env, OS junk)
├── .prettierignore       # files Prettier should skip
├── .prettierrc           # code formatting rules
├── .zshrc                # shell config (fnm, starship, aliases, plugins)
├── eslint.config.mjs     # flat ESLint config for TS/Node projects
├── install.sh            # bootstraps everything below on a fresh Ubuntu VPS
└── tsconfig.base.json    # base tsconfig other projects can extend
```

`config/` and `etc/` don't exist until you add something to them — `install.sh`
only touches them if present.

## Usage

On a fresh Ubuntu VPS:

```bash
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then either restart your shell or run:

```bash
exec zsh
```

## What `install.sh` does

- **Links dotfiles** — any dotfile in the repo root is symlinked into `$HOME`
  automatically (no list to maintain). Anything in `config/` is linked into
  `~/.config/`. Anything in `claude/` is linked into `~/.claude/`. `gh/config.yml`
  is linked into `~/.config/gh/` as a single file — `hosts.yml` (your gh oauth
  token) lives alongside it on disk but is never touched by this repo.
- **Sets the global gitignore/gitattributes** — links `.gitignore_global` and
  `.gitattributes` and points `git config --global core.excludesfile` /
  `core.attributesFile` at them.
- **Installs CLI tools** — `ripgrep`, `fd-find`, `bat`, `zoxide`, `eza`, `gh`,
  `fnm`, `starship`, `pay-respects`, the Rust toolchain (`rustup`/`cargo`) plus
  `rtk` built from source (`cargo install --git https://github.com/rtk-ai/rtk`),
  the Claude Code CLI (`npm install -g @anthropic-ai/claude-code`), and the zsh
  plugins referenced in `.zshrc` (`zsh-autosuggestions`, `zsh-syntax-highlighting`).
- **Installs and enables services** — `nginx`, `redis-server`, `fail2ban` via
  `systemctl enable --now` (persist across reboots).
- **Links `/etc` configs** — anything placed in `repo/etc/...` (e.g.
  `etc/nginx/nginx.conf`) is symlinked to the matching path under `/etc`, then
  `nginx -t` validates the config.
- **Firewall** — configures `ufw` to only allow SSH and Nginx traffic, then
  enables it.
- **Security updates** — enables `unattended-upgrades` for automatic patching.
- **Swap file** — creates a 2G swapfile if one doesn't already exist, useful
  on small-RAM VPS tiers.
- **Node** — installs the latest Node LTS via `fnm` and sets it as default.

The script is idempotent — safe to re-run; each step checks whether it's
already done before acting.

## Adding new configs later

- New home dotfile (`.tmux.conf`, etc.) → drop it in the repo root, re-run
  `install.sh`, it's picked up automatically.
- New `~/.config/` file → drop it in `config/`.
- New `~/.claude/` file → drop it in `claude/`.
- New `~/.config/gh/` file → drop it in `gh/` (never `hosts.yml` — it holds your oauth token).
- New root-owned config (another nginx site, etc.) → drop it under `etc/`
  mirroring the real `/etc` path.

## Notes

- Lockfiles (`package-lock.json`, `bun.lock`, etc.) belong in the _projects_
  you build, not in this repo — nothing here applies to that, just a reminder
  not to gitignore them in your actual projects.
- `vscode/settings.json` mirrors editor preferences only — no credentials are
  stored here. Extensions that need API keys use the OS keychain, not this
  file.
- SSH hardening (key-only auth, disabling root login) is intentionally **not**
  automated here — worth doing manually/deliberately per server rather than
  baking into a general-purpose script.
