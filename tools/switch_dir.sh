alias switch-dir=$HOME/.zshrc_/tools/switch_dir/target/release/switch-dir

switch_dir() {
  if [[ "$2" == "--refresh" ]]; then
    switch-dir resolve --config "$HOME/.zshrc_/.config/switch_dir/$1.json" --key="$2"
    return
  fi
  local target=$(switch-dir resolve --config "$HOME/.zshrc_/.config/switch_dir/$1.json" --key="$2")
  [[ -n "$target" ]] && cd "$target"
}

_switch_dir() {
  switch-dir list --config "$HOME/.zshrc_/.config/switch_dir/$1.json"
}
