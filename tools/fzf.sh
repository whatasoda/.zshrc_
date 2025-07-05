# fzf-tab
zstyle ':fzf-tab:*' continuous-trigger ','
source $ZSH/fzf-tab/fzf-tab.plugin.zsh

# fzf history
function fzf-select-history() {
    BUFFER=$(history -n -r 1 | fzf --query "$LBUFFER" --reverse)
    CURSOR=$#BUFFER
    zle reset-prompt
}
zle -N fzf-select-history
bindkey '^r' fzf-select-history
