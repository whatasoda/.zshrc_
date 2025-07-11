alias difit="bunx --bun difit"

gifit() {
  local from_commit to_commit from_hash to_hash

  from_commit=$(git log --oneline --decorate -100 | fzf --prompt "FROM(inclusive)> ") || return
  from_hash="${from_commit%% *}"

  to_commit=$(git log --oneline --decorate -100 $from_hash~1.. | fzf --prompt "TO(inclusive)> ") || return
  to_hash="${to_commit%% *}"

  difit "$to_hash" "$from_hash~1"
}
