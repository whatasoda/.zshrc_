#!/bin/bash

# Simple status line for Claude Code

input=$(cat)

if ! command -v jq &> /dev/null; then
    echo "Claude Code"
    exit 0
fi

# Extract info
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "."')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

# Worktree name and relative path
get_worktree_path() {
    cd "$1" 2>/dev/null || return
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$root" ]; then
        local common_git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
        local main_repo_path
        local main_repo_name
        local worktree_name=$(basename "$root")

        # Handle relative .git path (main repo) vs absolute path (worktree)
        if [[ "$common_git_dir" != /* ]]; then
            # Main repo: common_git_dir is relative (e.g., .git or ../.git)
            main_repo_path="$root"
            main_repo_name="$worktree_name"
        else
            # Worktree: common_git_dir is absolute, remove /.git suffix
            main_repo_path="${common_git_dir%/.git}"
            main_repo_name=$(basename "$main_repo_path")
        fi

        local rel_path="${1#$root}"
        rel_path="${rel_path#/}"  # Remove leading slash

        # Check if this is a worktree (not main repo)
        local prefix="$main_repo_name"
        if [ "$root" != "$main_repo_path" ]; then
            # It's a worktree: show repo/worktree
            prefix="${main_repo_name}/${worktree_name}"
        fi

        if [ -n "$rel_path" ]; then
            echo "${prefix}:${rel_path}"
        else
            echo "${prefix}"
        fi
    else
        # Fallback: show last 2 components
        local dir="${1/#$HOME/~}"
        echo "$dir" | awk -F'/' '{print $(NF-1)"/"$NF}'
    fi
}

# Git branch with dirty indicator
get_git_info() {
    cd "$1" 2>/dev/null || return
    if git rev-parse --git-dir &>/dev/null; then
        local branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
        local dirty=""
        git diff-index --quiet HEAD -- 2>/dev/null || dirty="*"
        printf " on \033[35m%s%s\033[0m" "$branch" "$dirty"
    fi
}

# Context usage
get_context_usage() {
    if [ "$context_size" -gt 0 ] && [ "$input_tokens" != "null" ]; then
        local total=$((input_tokens + cache_creation + cache_read))
        local percent=$((total * 100 / context_size))
        # Color based on usage: green < 50%, yellow 50-80%, red > 80%
        local color=32  # green
        if [ $percent -ge 80 ]; then
            color=31  # red
        elif [ $percent -ge 50 ]; then
            color=33  # yellow
        fi
        printf " | \033[${color}m%d%%\033[0m" "$percent"
    fi
}

path_display=$(get_worktree_path "$current_dir")

# Output: worktree:path [git info] | context%
printf "\033[36m%s\033[0m" "$path_display"
get_git_info "$current_dir"
get_context_usage
