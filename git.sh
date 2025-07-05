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
alias l="git log"
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

# ==========================
# gw function
# ==========================
function gw() {
  local WT_ROOT="$HOME/worktrees"
  local wt_name="$1"

  # Get current Git repository root
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Not inside a Git repository"
    return 1
  }

  # Parse GitHub remote URL to get owner and repo name
  local remote_url
  remote_url=$(git config --get remote.origin.url)
  if [[ "$remote_url" =~ github.com[:/](.*)/(.*)(\.git)?$ ]]; then
    local owner="${match[1]}"
    local repo="${match[2]%.git}"
  else
    echo "Unsupported or missing remote URL: $remote_url"
    return 1
  fi

  # If no argument: go to main repository (even from a worktree)
  if [[ -z "$wt_name" ]]; then
    if [[ -f "$repo_root/.git" ]]; then
      local gitdir_line
      gitdir_line=$(<"$repo_root/.git")
      if [[ "$gitdir_line" =~ gitdir:\ (.*)/\.git/worktrees/.* ]]; then
        local main_repo_path="${match[1]}"
        echo "[gw] Moving to main repository: $main_repo_path"
        cd "$main_repo_path" || return 1
        return 0
      fi
    fi

    echo "[gw] Already in main repository: $repo_root"
    cd "$repo_root" || return 1
    return 0
  fi

  local base_dir="$WT_ROOT/$owner/$repo"
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
}

# ==========================
# gw completion (_gw)
# ==========================
function _gw() {
  local WT_ROOT="$HOME/worktrees"

  local remote_url=$(git config --get remote.origin.url 2>/dev/null)
  [[ "$remote_url" =~ github.com[:/](.*)/(.*)(\.git)?$ ]] || return
  local owner="${match[1]}"
  local repo="${match[2]%.git}"

  local base_dir="$WT_ROOT/$owner/$repo"
  [[ -d "$base_dir" ]] || return

  local -a worktrees
  worktrees=(${(f)"$(find "$base_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)"})

  compadd -Q -- "${worktrees[@]}"
}
compdef _gw gw
