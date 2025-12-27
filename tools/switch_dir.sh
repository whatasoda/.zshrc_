alias switch-dir=$HOME/.zshrc_/tools/switch_dir/target/release/switch-dir

switch_dir() {
  local config=$1
  local key=$2
  local target
  target=$(switch-dir resolve --config "$config" --key "$key")
  [[ -n "$target" ]] && cd "$target"
}

_switch_dir() {
  local config=$1
  switch-dir list --config "$config"
}
