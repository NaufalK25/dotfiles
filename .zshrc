# Created by newuser for 5.9

export PATH="$HOME/.local/bin:$PATH"

# fnm
FNM_PATH="/home/naufal/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi
eval "$(starship init zsh)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fnm
FNM_PATH="/home/naufal/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

eval "$(pay-respects zsh --alias)"

# --- Modern CLI replacements ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza --tree --icons'

alias cat='batcat'

alias grep='rg'

alias find='fd'
alias fd='fdfind'

eval "$(zoxide init zsh)"
