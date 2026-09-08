import type { Plugin } from "@opencode-ai/plugin"

const hookPath = (name: string) =>
  `${process.env.HOME}/.claude/hooks/${name}`

export const AgentNotifications: Plugin = async ({ client, directory }) => {
  const pane = process.env.TMUX_PANE
  if (!pane) return {}

  const notified = new Set<string>()

  const isRootSession = async (sessionID: string) => {
    try {
      const result = await client.session.get({
        path: { id: sessionID },
        query: { directory },
      })
      return !result.data?.parentID
    } catch {
      // A notification is better than silently losing one if session lookup
      // briefly races session creation.
      return true
    }
  }

  const runHook = async (
    name: "notify-engaged.sh" | "notify-complete.sh",
    title?: string,
  ) => {
    const child = Bun.spawn([hookPath(name)], {
      cwd: directory,
      env: {
        ...process.env,
        TMUX_PANE: pane,
        AGENT_NOTIFICATION_AGENT: "OpenCode",
        ...(title ? { AGENT_NOTIFICATION_TITLE: title } : {}),
      },
      stdout: "ignore",
      stderr: "ignore",
    })
    await child.exited
  }

  const notify = async (sessionID: string) => {
    if (notified.has(sessionID) || !(await isRootSession(sessionID))) return
    notified.add(sessionID)
    await runHook("notify-complete.sh", "OpenCode")
  }

  return {
    event: async ({ event }) => {
      const properties = event.properties as {
        sessionID?: string
        status?: { type?: string }
      }
      const sessionID = properties?.sessionID
      if (!sessionID) return

      if (
        event.type === "session.status" &&
        properties.status?.type === "busy" &&
        (await isRootSession(sessionID))
      ) {
        notified.delete(sessionID)
        await runHook("notify-engaged.sh")
        return
      }

      if (event.type === "session.idle") {
        await notify(sessionID)
        return
      }

      // These events mean OpenCode needs input before the turn can continue.
      // Older releases call this permission.updated; newer releases use
      // permission.asked and question.asked.
      if (
        event.type === "permission.updated" ||
        (event.type as string) === "permission.asked" ||
        (event.type as string) === "question.asked"
      ) {
        await notify(sessionID)
      }
    },
  }
}
