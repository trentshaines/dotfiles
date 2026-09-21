# tmux assistant restore

Continuum saves every five minutes and restores when the tmux server starts.
`assistant-state.sh` supplies a stable PATH before shell/mise initialization.
The local hooks must stay after TPM in `.tmux.conf`.

Codex identity comes from its process's open thread-writer lock or rollout file.
It is never inferred from the most recent conversation in a working directory.
Resume commands contain one explicit session UUID and no replayed prompt.
Automatic resumes suppress the Codex update prompt for that invocation.
Other assistants use the existing tmux-assistant-resurrect adapter.

Each resurrect layout has `.assistants.json` and `.names.json` sidecars.
`assistant-history/` retains immutable metadata saves for recovery. Runtime
conversations and mappings remain local, outside the dotfiles repository.
A failed restore leaves `assistant-restore-pending.json` and blocks metadata
replacement until the restore succeeds. Inspect the affected panes and retry.
Never delete the pending file just to silence a failed restore.

Inspect live, exact Codex assignments:

```sh
bash ~/.config/tmux/assistant-state.sh inspect
```

Save layout, sessions and names together:

```sh
bash ~/.tmux/plugins/tmux-resurrect/scripts/save.sh quiet
```

Preview or retry assistant restoration without rebuilding the layout:

```sh
bash ~/.config/tmux/assistant-state.sh restore --dry-run
bash ~/.config/tmux/assistant-state.sh restore
```

Restore refuses to type into an occupied pane. Check `assistant-state.log`
inside the resurrect data directory for verified session IDs and failures.
Run the regression suite with `python3 ~/.config/tmux/test-assistant-state.py`.

Chezmoi's `sourceDir` setting belongs at the top level of `chezmoi.toml`,
not inside a `[chezmoi]` table. Confirm the checkout using `chezmoi source-path`.
Ansible installs TPM and the configured restore plugins for a fresh machine.
