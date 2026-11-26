# Project manager (optional)

A small replacement for the VS Code
[Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)
extension. Zed extensions cannot add pickers or open folders, so this uses two shell scripts,
Zed tasks, and `fzf`.

| Default shortcut | Task | What it does |
|---|---|---|
| `cmd-alt-p` | Project: open | Fuzzy-search saved projects by name or tag, open the pick in a new Zed window |
| `cmd-alt-shift-p` | Project: save current | Save the open project, asks for a name and a tag |
| `cmd-alt-shift-e` | Project: edit list | Open `projects.json` in the current Zed window |

Every task is also in the command palette: `task: spawn`, then type `Project`.

## Install

```bash
brew install fzf jq   # jq ships with macOS 15+, fzf does not
./extensions/project-manager/install.sh
```

The installer:

1. Creates `~/.config/zed/projects.json`. If VS Code Project Manager is installed, it offers
   to import that list.
2. Adds the three tasks to `~/.config/zed/tasks.json` and the shortcuts to
   `~/.config/zed/keymap.json`. Your other tasks and bindings are kept. If one of those
   files has comments, it prints the snippet for you to paste instead of editing it.

Tasks point at the scripts by absolute path. Rerun the installer if you move this repo.

## Change the shortcuts

Either way works, and rerunning the installer keeps what you chose:

- **Edit `~/.config/zed/keymap.json`** (`zed: open keymap file`). Change the key in front of
  the `Project: ...` task:

  ```json
  "ctrl-p": ["task::Spawn", { "task_name": "Project: open" }]
  ```

- **Set them at install time.** Use `none` to leave a task without a shortcut:

  ```bash
  ZP_KEY_OPEN=ctrl-p ZP_KEY_SAVE=cmd-shift-s ZP_KEY_EDIT=none ./extensions/project-manager/install.sh
  ```

Key priority: `ZP_KEY_*` variable, then the key already in `keymap.json`, then the default.
If a shortcut does nothing, another binding may own it. Check with `dev: open key context view`.

## Your project list

- Lives in `~/.config/zed/projects.json`, **not in this repo**. It is personal and is
  ignored by `.gitignore`.
- Same format as VS Code Project Manager (`name`, `rootPath`, `tags`). Open it with
  `cmd-alt-shift-e` (Project: edit list) to rename or remove projects.
- To share one list with VS Code, point the scripts at the VS Code file. Add to `~/.zshrc`:

  ```bash
  export ZP_PROJECTS="$HOME/Library/Application Support/Code/User/globalStorage/alefragnani.project-manager/projects.json"
  ```

  Then restart Zed so tasks pick up the variable.

## Command line

The scripts also work from any terminal:

```bash
extensions/project-manager/zp           # pick and open
extensions/project-manager/zp-save .    # save the current folder
extensions/project-manager/zp --edit    # open projects.json in Zed
```
