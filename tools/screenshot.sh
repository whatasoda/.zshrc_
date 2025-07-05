function ss() {
  # スクリーンショットの保存先（必要に応じて変更）
  DIR="$HOME/screenshots"

  # PNG ファイルを新しい順に並べて取得
  files=("${(f)$(ls -t "$DIR"/*.png 2>/dev/null)}")

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No PNG files found in $DIR"
    exit 1
  fi

  # fzf で選択（QuickLook を使ってプレビュー）
  selected=$(printf '%s\n' "${files[@]}" | fzf \
    --prompt="" \
    --bind "ctrl-s:execute-silent(qlmanage -p {} >& /dev/null)")

  if [[ -z "$selected" ]]; then
    echo "No file selected."
    exit 1
  fi

  # 選んだファイルをクリップボードにコピー（PNG）
  osascript <<EOF
set the clipboard to (read (POSIX file "$selected") as «class PNGf»)
EOF
}
