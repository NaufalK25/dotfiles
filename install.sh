#!/usr/bin/env bash
# dotfiles install script — Ubuntu VPS targeted
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Linking dotfiles"
for f in .zshrc .gitconfig; do
  if [ -f "$DIR/$f" ]; then
    ln -sf "$DIR/$f" "$HOME/$f"
    echo "linked $f"
  fi
done

# ~/.config/* files, if you keep any in repo/config/
if [ -d "$DIR/config" ]; then
  mkdir -p "$HOME/.config"
  for f in "$DIR"/config/*; do
    [ -e "$f" ] || continue
    ln -sf "$f" "$HOME/.config/$(basename "$f")"
    echo "linked .config/$(basename "$f")"
  done
fi

# ~/.claude/* files, if you keep any in repo/claude/
if [ -d "$DIR/claude" ]; then
  mkdir -p "$HOME/.claude"
  for f in "$DIR"/claude/*; do
    [ -e "$f" ] || continue
    ln -sf "$f" "$HOME/.claude/$(basename "$f")"
    echo "linked .claude/$(basename "$f")"
  done
fi

# global gitignore + gitattributes
if [ -f "$DIR/.gitignore_global" ]; then
  ln -sf "$DIR/.gitignore_global" "$HOME/.gitignore_global"
  git config --global core.excludesfile "$HOME/.gitignore_global"
  echo "linked .gitignore_global"
fi

echo "==> Updating apt"
sudo apt update -y
sudo apt upgrade -y

echo "==> Installing apt-available packages"
# ripgrep, fd-find, bat, zoxide are packaged directly on recent Ubuntu.
# fd-find installs as 'fdfind', bat installs as 'batcat' — matches your aliases.
sudo apt install -y \
  ripgrep \
  fd-find \
  bat \
  zoxide \
  git \
  curl \
  wget \
  build-essential \
  unzip \
  ufw \
  fail2ban \
  unattended-upgrades \
  redis-server

# --- eza (not always in apt, use official repo if missing) ---
if ! command -v eza &> /dev/null; then
  echo "==> Installing eza"
  sudo apt install -y gpg
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt update -y
  sudo apt install -y eza
fi

# --- fnm ---
if ! command -v fnm &> /dev/null; then
  echo "==> Installing fnm"
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi

# --- starship ---
if ! command -v starship &> /dev/null; then
  echo "==> Installing starship"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# --- pay-respects ---
if ! command -v pay-respects &> /dev/null; then
  echo "==> Installing pay-respects"
  curl -fsSL https://raw.githubusercontent.com/iffse/pay-respects/main/install.sh | sh
fi

# --- zsh plugins (autosuggestions / syntax-highlighting) ---
mkdir -p "$HOME/.zsh"
if [ ! -d "$HOME/.zsh/zsh-autosuggestions" ]; then
  echo "==> Cloning zsh-autosuggestions"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
fi
if [ ! -d "$HOME/.zsh/zsh-syntax-highlighting" ]; then
  echo "==> Cloning zsh-syntax-highlighting"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.zsh/zsh-syntax-highlighting"
fi

# --- nginx ---
if ! command -v nginx &> /dev/null; then
  echo "==> Installing nginx"
  sudo apt install -y nginx
fi

# --- link system-level (/etc) configs, if present in repo/etc/... ---
# Use this for anything that needs root, e.g. repo/etc/nginx/nginx.conf -> /etc/nginx/nginx.conf
if [ -d "$DIR/etc" ]; then
  echo "==> Linking /etc configs"
  find "$DIR/etc" -type f | while read -r src; do
    rel="${src#$DIR/etc/}"
    dest="/etc/$rel"
    sudo mkdir -p "$(dirname "$dest")"
    sudo ln -sf "$src" "$dest"
    echo "linked /etc/$rel"
  done
  sudo nginx -t
fi

# --- enable services properly via systemd (real init system on a VPS) ---
echo "==> Enabling services"
sudo systemctl enable --now nginx
sudo systemctl enable --now redis-server
sudo systemctl enable --now fail2ban

# --- firewall: only allow SSH, HTTP, HTTPS ---
echo "==> Configuring ufw"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# --- unattended security upgrades ---
echo "==> Enabling unattended-upgrades"
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# --- swap file (helps on small VPS instances, e.g. 512MB-1GB RAM) ---
if [ ! -f /swapfile ]; then
  echo "==> Creating 2G swapfile"
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# --- fnm: install a default Node LTS ---
export PATH="$HOME/.local/share/fnm:$PATH"
if command -v fnm &> /dev/null; then
  eval "$(fnm env --shell bash)"
  fnm install --lts
  fnm default lts-latest
fi

echo "==> Done. Restart your shell or run: exec zsh"