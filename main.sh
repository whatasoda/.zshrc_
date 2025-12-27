export LANG=en_US.UTF-8

ZSH=$HOME/.zsh
fpath=($ZSH/completion $fpath)

# Auto Completion
autoload -U compinit
compinit -u

# Set PATH, MANPATH, etc., for Homebrew.
eval "$(/opt/homebrew/bin/brew shellenv)"

. $HOME/.zshrc_/anyenv.sh
. $HOME/.zshrc_/git.sh
. $HOME/.zshrc_/gcloud.sh
. $HOME/.zshrc_/node.sh

. $HOME/.zshrc_/tools/deduplicate.sh
. $HOME/.zshrc_/tools/difit.sh
. $HOME/.zshrc_/tools/docker_log.sh
. $HOME/.zshrc_/tools/fzf.sh
. $HOME/.zshrc_/tools/look_ip.sh
. $HOME/.zshrc_/tools/switch_dir.sh

# Mac
alias restart-sound-service="sudo kill -9 `ps ax|grep 'coreaudio[a-z]' | awk '{print $1}'`"
alias restart-control-center="killall ControlCenter"

# zsh-autosuggestions
source $ZSH/zsh-autosuggestions/zsh-autosuggestions.zsh

# Starship
eval "$(starship init zsh)"

alias ttyconf='code "$HOME/Library/Application Support/com.mitchellh.ghostty/config"'

alias cs="cursor"
alias code="cursor"
PATH="$HOME/claude/local/node_modules/.bin:$PATH"
