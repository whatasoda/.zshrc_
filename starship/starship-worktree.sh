#!/bin/bash
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 1
common_git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
worktree_name=$(basename "$root")

if [[ "$common_git_dir" != /* ]]; then
    prefix="$worktree_name"
else
    main_repo_name=$(basename "${common_git_dir%/.git}")
    prefix="$main_repo_name/$worktree_name"
fi

rel_path="${PWD#$root}"
rel_path="${rel_path#/}"

if [ -n "$rel_path" ]; then
    echo "${prefix}:${rel_path}"
else
    echo "${prefix}"
fi
