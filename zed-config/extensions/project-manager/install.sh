#!/usr/bin/env bash
# Opt-in: adds "Project: open" / "Project: save current" tasks and shortcuts to Zed.
# Your project list stays in ~/.config/zed/projects.json and is never part of this repo.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
ZED_DIR="$HOME/.config/zed"
PROJECTS="${ZP_PROJECTS:-$ZED_DIR/projects.json}"
VSCODE_PROJECTS="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"

mkdir -p "$ZED_DIR"
chmod +x "$DIR/zp" "$DIR/zp-save"

command -v jq  >/dev/null || { echo "jq is required: brew install jq"; exit 1; }
command -v fzf >/dev/null || echo "warning: fzf not found, the picker needs it: brew install fzf"

# 1. projects file
if [ ! -e "$PROJECTS" ]; then
  if [ -f "$VSCODE_PROJECTS" ]; then
    read -rp "Import projects from VS Code Project Manager? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      cp "$VSCODE_PROJECTS" "$PROJECTS"
      echo "imported $(jq length "$PROJECTS") projects into $PROJECTS"
    fi
  fi
  [ -e "$PROJECTS" ] || { echo '[]' > "$PROJECTS"; echo "created empty $PROJECTS"; }
fi

# 2. tasks and keybindings (absolute paths to this repo's scripts)
TASKS="$(jq -n --arg zp "$DIR/zp" --arg save "$DIR/zp-save" '[
  { label: "Project: open", command: $zp,
    reveal: "always", reveal_target: "center", hide: "on_success",
    use_new_terminal: true, allow_concurrent_runs: false,
    show_command: false, show_summary: false },
  { label: "Project: save current", command: $save, args: ["$ZED_WORKTREE_ROOT"],
    reveal: "always", hide: "on_success",
    use_new_terminal: true, allow_concurrent_runs: false,
    show_command: false, show_summary: false },
  { label: "Project: edit list", command: $zp, args: ["--edit"],
    reveal: "never", hide: "always",
    use_new_terminal: true, allow_concurrent_runs: false,
    show_command: false, show_summary: false }
]')"

# Shortcuts. Precedence: ZP_KEY_* env var > key already in keymap.json > default.
# Set a ZP_KEY_* to "none" to leave that task without a shortcut.
KEYMAP="$ZED_DIR/keymap.json"
existing_key() {
  [ -f "$KEYMAP" ] && jq -e . "$KEYMAP" >/dev/null 2>&1 || return 0
  jq -r --arg t "$1" '[ .[] | (.bindings // {}) | to_entries[]
    | select(.value == ["task::Spawn", {"task_name": $t}]) | .key ][0] // empty' "$KEYMAP"
}
pick_key() { # env_value task default
  if [ -n "$1" ]; then echo "$1"; else
    local k; k="$(existing_key "$2")"; echo "${k:-$3}"; fi
}
KEY_OPEN="$(pick_key "${ZP_KEY_OPEN:-}" "Project: open"         "cmd-alt-p")"
KEY_SAVE="$(pick_key "${ZP_KEY_SAVE:-}" "Project: save current" "cmd-alt-shift-p")"
KEY_EDIT="$(pick_key "${ZP_KEY_EDIT:-}" "Project: edit list"    "cmd-alt-shift-e")"

KEYS="$(jq -n --arg o "$KEY_OPEN" --arg s "$KEY_SAVE" --arg e "$KEY_EDIT" '
  [ [$o, "Project: open"], [$s, "Project: save current"], [$e, "Project: edit list"] ]
  | map(select(.[0] != "none" and .[0] != ""))
  | [{ context: "Workspace",
       bindings: (map({ key: .[0], value: ["task::Spawn", { task_name: .[1] }] }) | from_entries) }]')"

# Writes the file if missing, merges if it is plain JSON, otherwise prints the snippet.
merge() {
  local file="$1" new="$2" filter="$3"
  if [ ! -e "$file" ]; then
    printf '%s\n' "$new" | jq . > "$file"
    echo "created $file"
  elif jq -e . "$file" >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    jq --argjson new "$new" "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
    echo "updated $file"
  else
    echo "$file has comments or trailing commas, so it was not changed. Add this by hand:"
    printf '%s\n' "$new" | jq .
  fi
}

# replace our tasks by label, keep the rest
merge "$ZED_DIR/tasks.json" "$TASKS" \
  '($new | map(.label)) as $l | map(select(.label as $x | $l | index($x) | not)) + $new'

# remove our old "Project: *" bindings (drop blocks left empty), then append the new block
merge "$KEYMAP" "$KEYS" '
  map(if .bindings then .bindings |= with_entries(select(
        (.value | type == "array" and .[0] == "task::Spawn"
          and ((.[1].task_name // "") | startswith("Project: "))) | not))
      else . end)
  | map(select(.bindings == null or (.bindings | length > 0)))
  + $new'

echo "Done. Shortcuts:"
echo "  ${KEY_OPEN}  Project: open"
echo "  ${KEY_SAVE}  Project: save current"
echo "  ${KEY_EDIT}  Project: edit list"
echo "Change them in $KEYMAP, or rerun with ZP_KEY_OPEN / ZP_KEY_SAVE / ZP_KEY_EDIT."
