switch_dir() {
  local json=$1            # The JSON string containing path mappings
  local default_base=$2    # The default base path (e.g. ~/workspace/...)
  local expected_repo=$3   # The expected Git repo name
  local fallback_prefix=$4 # The fallback subdirectory (e.g. "packages")
  local key=$5             # The key to look up (e.g. "web")

  local base="$default_base"

  if [[ -n "$expected_repo" ]]; then
    # If inside a Git repo and it's the expected one, override base path
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local repo_name
      repo_name=$(basename -s .git "$(git remote get-url origin 2>/dev/null)")
      if [[ "$repo_name" == "$expected_repo" ]]; then
        base=$(git rev-parse --show-toplevel)
      fi
    fi
  fi

  # Try to extract the subpath from JSON using jq
  local subpath
  subpath=$(jq -r --arg k "$key" 'if has($k) then .[$k] else empty end' <<< "$json")

  # If found in JSON, use that path; otherwise fallback to default directory
  if [[ -n "$subpath" ]]; then
    cd "$base/$subpath" || return 1
  else
    cd "$base/$fallback_prefix/$key" || return 1
  fi
}

_switch_dir() {
  local default_base=$1     # Fallback root directory
  local expected_repo=$2    # Expected Git repository name
  local fallback_prefix=$3  # Subdirectory used for fallback (e.g. "packages")

  local base="$default_base"

  if [[ -n "$expected_repo" ]]; then
    # If inside a Git repo and it matches the expected repo, override base
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      local repo_name
      repo_name=$(basename -s .git "$(git remote get-url origin 2>/dev/null)")
      if [[ "$repo_name" == "$expected_repo" ]]; then
        base=$(git rev-parse --show-toplevel)
      fi
    fi
  fi

  # Collect all directories under fallback_prefix as candidates
  local -a result
  for dir in "$base/$fallback_prefix/"*/; do
    [[ -d "$dir" ]] && result+=("$(basename "$dir")")
  done

  echo "${result[@]}"
}
