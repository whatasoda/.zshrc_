alias difit="bunx --bun difit"

gifit() {
  local base_commit target_commit base_hash

  base_commit=$(git log --oneline --decorate -100 | fzf --prompt "BASE(2nd arg)> ") || return
  base_hash="${base_commit%% *}"

  target_commit=$(git log --oneline --decorate -100 $base_hash~1.. | fzf --prompt "TARGET(1st arg)> ") || return
  target_hash="${target_commit%% *}"

  difit "$target_hash" "$base_hash"
}
