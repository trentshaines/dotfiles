# tmux assistant restore

Continuum saves every five minutes and restores when the tmux server starts.
`assistant-state.sh` supplies a stable PATH before shell/mise initialization.
The local hooks must stay after TPM in `.tmux.conf`.

Window names entered with prefix + `,` are explicitly pinned in the window
option `@manual-window-name` (its value is the intended name). Prefix + `Alt+,`
unpins the window. `window-names.conf` is loaded by interactive fish startup and
the name restore helper. A rename guard also protects pins from older assistant
hooks that do not know about the option. Branch naming helpers respect it.
The snapshot's names sidecar saves this option and restores it before assistant
launches and again afterward, including when one of the resumes fails.
To intentionally rename a pinned window from a CLI, set `@manual-window-name`
to the new name before running `rename-window`, or unset it to unlock the name.
Run `python3 ~/.config/tmux/test-window-names.py` to test an isolated restart.

Codex identity comes from its process's open thread-writer lock or rollout file.
It is never inferred from the most recent conversation in a working directory.
Resume commands contain one explicit session UUID and no replayed prompt.
Automatic resumes suppress the Codex update prompt for that invocation.
Other assistants use the existing tmux-assistant-resurrect adapter.

Recent Codex versions default to a shared daemon, whose thread locks cannot be
assigned to individual panes. The fish `codex` function (also used by `cod`)
and the restore hook both call `codex-launch.sh`. Inside tmux, this launcher
adds `--no-daemon` when the selected Codex binary supports it. This keeps thread
ownership local to each pane. The capability check accommodates different mise
versions per project; older Codex versions and launches outside tmux are unchanged.
Use these launch paths inside tmux: `command codex` bypasses the fish function.

Before tmux-resurrect publishes its latest layout, the post-save-layout hook
embeds exact Codex resume IDs directly into that layout. Even if the later
sidecar save fails, fresh conversations still have a recoverable identity.
Raw Codex commands without verified pane ownership are removed: resurrect's
default `ps` strategy can match a different process with the same PID prefix.
Each resurrect layout also has `.assistants.json` and `.names.json` sidecars.
`assistant-history/` retains immutable metadata saves for recovery. Runtime
conversations and mappings remain local, outside the dotfiles repository.
A failed restore leaves `assistant-restore-pending.json` for diagnosis and retry.
It does not block saves of other live sessions. Pending IDs are retained only
for the same server and pane, and only if Codex actually persisted the thread.
Unresolved processes are logged individually; other panes still get saved.
Empty TUIs with no persisted conversation are not resumable and are excluded.

Claude session IDs come from Claude Code's own registry,
`~/.claude/sessions/<pid>.json`. The plugin's hook files live in `$TMPDIR`,
which macOS purges, and its fallback can capture `--resume --flag` as an ID.
A pane with no transcript, such as an open resume picker, is skipped.
Restore ignores non-UUID Claude IDs found in older snapshots. The plugin's
per-pane restore log is appended to `assistant-restore.log`.

Continuum autosaves call `resurrect-save-guard.sh`. On a new server, the guard
blocks autosaves until the assistant restore sets `@assistant-restore-done`,
or for 30 minutes if no restore runs. In one case an autosave nine seconds into
a restore replaced `last` with 16 of 79 panes and no assistants. The restore
hook then read that partial snapshot. Manual saves (prefix + Ctrl-s) bypass the
guard. `.tmux.conf` sources `window-names.conf`, so reloading the
configuration no longer replaces the pin-aware branch hooks.

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
