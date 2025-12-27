#!/bin/bash

# git 管理下かどうかを確認
if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
    # git 管理外: full pwd を表示（~ 形式）
    pwd | sed "s|^$HOME|~|"
    exit 0
fi

# git 管理下の場合
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
