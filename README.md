# qstack

The agent skills and editor config I use. The skills work in Claude Code and Codex.

## Skills

| Skill | What it does |
|---|---|
| [`address-pr-comments`](skills/address-pr-comments/SKILL.md) | Work through a PR's review comments one at a time, locally, and post replies only after approval |
| [`generate-staged-commit`](skills/generate-staged-commit/SKILL.md) | Write a Conventional Commits message for the staged changes, without committing |
| [`review-candidate`](skills/review-candidate/SKILL.md) | Turn a technical interview transcript (`.docx` or `.md`) into a hire/no-hire recommendation |
| [`review-pr`](skills/review-pr/SKILL.md) | Review a GitHub PR, draft terse inline comments, and post them only after approval. Manual only in Claude Code (`/review-pr`) |
| [`work-history`](skills/work-history/SKILL.md) | Export and sanitize your work history into an inventory and a seniority analysis |

The PR skills need the [`gh`](https://cli.github.com/) CLI, signed in.

### Install

The recommended way is the [`skills`](https://github.com/vercel-labs/skills) CLI. It asks which agents to install for:

```bash
# All skills
npx skills@latest add quinsberry/qstack

# Or only the ones you want
npx skills@latest add quinsberry/qstack --skill review-pr --skill address-pr-comments
```

This copies the skills, so run it again to get updates.

To stay in sync with the repo instead, symlink the skills into your agent's skills folder and update with `git pull`:

```bash
git clone <this-repo> ~/qstack

# Claude Code
mkdir -p ~/.claude/skills
ln -s ~/qstack/skills/* ~/.claude/skills/

# Codex
mkdir -p ~/.codex/skills
ln -s ~/qstack/skills/* ~/.codex/skills/
```

## Zed config

[`zed-config/`](zed-config/README.md) holds a Zed setup that mirrors VS Code (keymap, Gruvbox Dark Hard theme, fonts) and an optional [project manager](zed-config/extensions/project-manager/README.md) built on shell scripts and `fzf`. Run `zed-config/install.sh` to link it into `~/.config/zed`.

## License

[MIT](LICENSE)
