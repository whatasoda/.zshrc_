# Deduplicate
function ded() {
  # macOS only: read clipboard content
  local clipboard_content
  clipboard_content=$(pbpaste)

  # Split by lines and deduplicate
  local unique
  unique=$(printf "%s\n" "$clipboard_content" | awk '!seen[$0]++')

  # Copy back to clipboard
  printf "%s\n" "$unique" | pbcopy

  echo "Deduplicated lines have been copied to the clipboard:"
  echo "$unique"
}
