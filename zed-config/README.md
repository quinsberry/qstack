# qstack: Zed config

Zed setup that mirrors my VS Code: VSCode keymap, jdinhlife Gruvbox Dark Hard colors,
VSCode icons, VS Code default fonts (Menlo 12 / SF Pro 14), Prettier options.

## Contents

- `settings.json`: Zed settings (copy of `~/.config/zed/settings.json`)
- `themes/gruvbox-dark-hard-vscode.json`: Gruvbox Dark Hard ported from the VS Code theme

## Install on a new machine

```bash
git clone <this-repo> ~/qstack
~/qstack/zed-config/install.sh
```

The script symlinks `settings.json` and `themes/` into `~/.config/zed`, so edits made
in Zed land in this repo. Existing files are kept as `*.bak`.

Extensions listed in `auto_install_extensions` install on the first Zed start.
AI keys and the GitHub login live in the macOS Keychain, so sign in again.

## Optional: project manager

Replacement for the VS Code Project Manager extension: `cmd-alt-p` to pick a saved
project, `cmd-alt-shift-p` to save the current one. Not installed by `install.sh`.
See [extensions/project-manager/README.md](extensions/project-manager/README.md).
