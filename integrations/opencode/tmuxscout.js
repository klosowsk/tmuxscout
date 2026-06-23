/**
 * tmuxscout — OpenCode integration (plugin).
 *
 * Flags the pane in tmuxscout on OpenCode lifecycle events:
 *   session.idle       -> "done"    (agent finished responding)
 *   permission.updated -> "waiting" (agent needs your approval/input)
 *
 * Install: symlinked into the OpenCode plugins dir (auto-loaded at startup):
 *   ~/.config/opencode/plugins/tmuxscout.js   (global)
 *   <project>/.opencode/plugins/tmuxscout.js  (project)
 * Restart running OpenCode sessions to pick it up.
 *
 * The binary is resolved from $TMUXSCOUT_BIN or "tmuxscout" on PATH.
 * `$` is OpenCode's injected Bun shell; .quiet().nothrow() keeps plugin failures
 * from ever disrupting the session.
 *
 * @import { Plugin } from "@opencode-ai/plugin"
 */

const RADAR = process.env.TMUXSCOUT_BIN || "tmuxscout";

/** @type {Plugin} */
export const AgentRadar = async ({ client, directory, $ }) => {
  const label = (directory || process.cwd()).split("/").filter(Boolean).pop() || "opencode";

  return {
    event: async ({ event }) => {
      if (!process.env.TMUX) return; // only meaningful inside tmux

      if (event.type === "session.idle") {
        const summary = await lastAssistantText(client, event.properties.sessionID);
        await $`${RADAR} mark done ${label} ${summary}`.quiet().nothrow();
      }

      if (event.type === "permission.updated") {
        const p = event.properties || {};
        const summary = p.title || `needs permission: ${p.type || "?"}`;
        await $`${RADAR} mark waiting ${label} ${summary}`.quiet().nothrow();
      }
    },
  };
};

/** Best-effort: last assistant message text for the summary. */
async function lastAssistantText(client, sessionID) {
  try {
    const res = await client.session.messages({ path: { id: sessionID } });
    const msgs = res?.data ?? res ?? [];
    for (let i = msgs.length - 1; i >= 0; i--) {
      const { info, parts } = msgs[i];
      if (info?.role !== "assistant") continue;
      const text = (parts || [])
        .filter((p) => p?.type === "text" && !p.synthetic && !p.ignored)
        .map((p) => p.text)
        .join(" ")
        .replace(/\s+/g, " ")
        .trim();
      if (text) return text.slice(0, 180);
    }
  } catch {
    /* summary is best-effort */
  }
  return "session idle";
}
