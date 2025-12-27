switch_dir() {
  local json=$1
  local default_base=$2
  local expected_repo=$3
  local fallback_prefix=$4
  local key=$5
  local dir_prefix=$6

  local target
  target=$(switch-dir resolve \
    --base "$default_base" \
    --prefix "$fallback_prefix" \
    ${expected_repo:+--expected-repo "$expected_repo"} \
    ${dir_prefix:+--dir-prefix "$dir_prefix"} \
    ${json:+--json "$json"} \
    --key "$key")

  [[ -n "$target" ]] && cd "$target"
}

_switch_dir() {
  local default_base=$1
  local expected_repo=$2
  local fallback_prefix=$3
  local dir_prefix=$4

  switch-dir list \
    --base "$default_base" \
    --prefix "$fallback_prefix" \
    ${expected_repo:+--expected-repo "$expected_repo"} \
    ${dir_prefix:+--dir-prefix "$dir_prefix"}
}
