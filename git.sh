# Git
PATH=$(brew --prefix git):$PATH
fpath=($(brew --prefix)/share/zsh/site-function $fpath)

alias s="git status"
compdef s "git status"
alias w="git switch"
compdef w "git switch"
alias a="git add"
compdef a "git add"
alias p="git push"
compdef p "git push"
alias c="git commit"
compdef c "git commit"
alias pl="git pull"
compdef pl "git pull"
alias l="git log --oneline"
compdef l "git log"
alias r="git reset"
compdef r "git reset"
alias rb="git rebase"
compdef rb "git rebase"
alias v="gh pr view --web"

alias curr-branch="git rev-parse --short --abbrev-ref HEAD"

# git switch
function ww() {
  git for-each-ref --format '%(refname:short) %(authoremail)' --sort=-committerdate refs/heads/ \
    | awk -F'[<>@]' '{ print $2 "\t" $1 }' \
    | grep -v "github-actions" \
    | fzf --no-sort \
    | awk -F'\t' '{ print $2 }' \
    | xargs git checkout
}

# Worktree sync configuration (for gw/gwlink functions)
# Uncomment and modify the following line to sync files between main repo and worktrees
GW_SYNC_PATHS=(
  ".claude/settings.local.json"
)

# ==========================
# gw function
# ==========================
function gw() {
  local wt_name="$1"

  # Get current Git repository root
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a Git repository"
    return 1
  }

  # Determine main repository root (resolve from worktree if needed)
  local main_repo_root="$repo_root"
  if [[ -f "$repo_root/.git" ]]; then
    local gitdir_line
    gitdir_line=$(<"$repo_root/.git")
    if [[ "$gitdir_line" =~ gitdir:\ (.*)/\.git/worktrees/.* ]]; then
      main_repo_root="${match[1]}"
    fi
  fi

  # If no argument: go to main repository
  if [[ -z "$wt_name" ]]; then
    if [[ "$repo_root" != "$main_repo_root" ]]; then
      echo "[gw] Moving to main repository: $main_repo_root"
    else
      echo "[gw] Already in main repository: $repo_root"
    fi
    cd "$main_repo_root" || return 1
    return 0
  fi

  local base_dir="$main_repo_root/.claude/worktree"
  local target_dir="$base_dir/$wt_name"

  if [[ -d "$target_dir" ]]; then
    echo "[gw] Switching to existing worktree: $target_dir"
    cd "$target_dir" || return 1
    return 0
  fi

  echo "[gw] Worktree does not exist: $target_dir"
  echo -n "Create new worktree from origin/<default-branch>? [Enter = Yes, Ctrl+C = Cancel] "
  read

  # Only here: determine default branch from remote
  local default_branch
  default_branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  default_branch=${default_branch:-main}

  echo "[gw] Creating new worktree '$wt_name' from origin/$default_branch"
  mkdir -p "$base_dir"
  git fetch origin "$default_branch"
  git worktree add "$target_dir" "origin/$default_branch" || return 1
  cd "$target_dir" || return 1
  
  # Auto-sync configured paths for new worktree
  if [[ ${#GW_SYNC_PATHS[@]} -gt 0 ]]; then
    echo "[gw] Setting up symbolic links for synced paths..."
    gwlink
  fi
}

# ==========================
# gwlink function - Create symbolic links for synced paths
# ==========================
function gwlink() {
  # Get current Git repository root
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a Git repository"
    return 1
  }

  # Check if GW_SYNC_PATHS is set
  if [[ ${#GW_SYNC_PATHS[@]} -eq 0 ]]; then
    echo "[gwlink] No paths to sync. Set GW_SYNC_PATHS array."
    echo "[gwlink] Example: GW_SYNC_PATHS=(\".claude/settings.local.json\" \".vscode/settings.json\")"
    return 0
  fi

  # Determine the main repository path (same logic as gw function)
  local main_repo_path="$repo_root"
  if [[ -f "$repo_root/.git" ]]; then
    local gitdir_line
    gitdir_line=$(<"$repo_root/.git")
    if [[ "$gitdir_line" =~ gitdir:\ (.*)/\.git/worktrees/.* ]]; then
      main_repo_path="${match[1]}"
      echo "[gwlink] Detected worktree. Main repository: $main_repo_path"
    else
      echo "[gwlink] Already in main repository. No linking needed."
      return 0
    fi
  else
    echo "[gwlink] Already in main repository. No linking needed."
    return 0
  fi

  # Process each path in GW_SYNC_PATHS array
  local failed=0
  
  for sync_path in "${GW_SYNC_PATHS[@]}"; do
    # Trim whitespace
    sync_path="${sync_path## }"
    sync_path="${sync_path%% }"
    
    if [[ -z "$sync_path" ]]; then
      continue
    fi

    local source_path="$main_repo_path/$sync_path"
    local target_path="$repo_root/$sync_path"
    local target_dir="$(dirname "$target_path")"

    echo "[gwlink] Processing: $sync_path"

    # Check if source exists in main repository
    if [[ ! -e "$source_path" ]]; then
      echo "[gwlink]   ⚠ Source does not exist in main repository: $source_path"
      echo "[gwlink]   Skipping..."
      continue
    fi

    # Check if target already exists
    if [[ -e "$target_path" || -L "$target_path" ]]; then
      if [[ -L "$target_path" ]]; then
        local current_link=$(readlink "$target_path")
        if [[ "$current_link" == "$source_path" ]]; then
          echo "[gwlink]   ✓ Already linked correctly"
          continue
        else
          echo "[gwlink]   ✗ Error: Symbolic link exists but points to different location"
          echo "[gwlink]     Current: $current_link"
          echo "[gwlink]     Expected: $source_path"
          echo "[gwlink]     Please remove or fix manually: rm \"$target_path\""
          failed=1
          continue
        fi
      else
        echo "[gwlink]   ✗ Error: File/directory already exists at target location"
        echo "[gwlink]     Path: $target_path"
        echo "[gwlink]     Please remove or backup manually before linking"
        failed=1
        continue
      fi
    fi

    # Create target directory if needed
    if [[ ! -d "$target_dir" ]]; then
      echo "[gwlink]   Creating directory: $target_dir"
      mkdir -p "$target_dir" || {
        echo "[gwlink]   ✗ Error: Failed to create directory"
        failed=1
        continue
      }
    fi

    # Create symbolic link
    ln -s "$source_path" "$target_path" || {
      echo "[gwlink]   ✗ Error: Failed to create symbolic link"
      failed=1
      continue
    }

    echo "[gwlink]   ✓ Successfully linked to main repository"
  done

  if [[ $failed -eq 1 ]]; then
    echo "[gwlink] Some operations failed. Please resolve the issues above."
    return 1
  fi

  echo "[gwlink] All paths synced successfully."
  return 0
}

# ==========================
# gw completion (_gw)
# ==========================
function _gw() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return

  local main_repo_root="$repo_root"
  if [[ -f "$repo_root/.git" ]]; then
    local gitdir_line
    gitdir_line=$(<"$repo_root/.git")
    if [[ "$gitdir_line" =~ gitdir:\ (.*)/\.git/worktrees/.* ]]; then
      main_repo_root="${match[1]}"
    fi
  fi

  local base_dir="$main_repo_root/.claude/worktree"
  [[ -d "$base_dir" ]] || return

  local -a worktrees
  worktrees=(${(f)"$(find "$base_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)"})

  compadd -Q -- "${worktrees[@]}"
}
compdef _gw gw
