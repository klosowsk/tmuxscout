/**
 * tmuxscout — pi integration.
 *
 * Flags this pi pane in tmuxscout when the agent finishes a turn
 * (`agent_end` -> "done"/✅), so it surfaces in the tmux popup (prefix+a) and the
 * status-bar badge — just like the Claude Code hook.
 *
 * Install: symlinked into the user's pi package extensions dir (auto-discovered).
 * pi loads extensions at startup, so restart pi (or open a new session) to
 * activate; the currently running session is unaffected.
 *
 * The only coupling is one CLI call. The binary is resolved from
 * $TMUXSCOUT_BIN or "tmuxscout" on PATH (no hardcoded paths). This file has
 * no runtime deps: the type import is erased and child_process/path are built-ins.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { basename } from "node:path";

const RADAR = process.env.TMUXSCOUT_BIN || "tmuxscout";

function mark(status: "done" | "waiting", label: string, summary: string): void {
  if (!process.env.TMUX) return; // only meaningful inside tmux
  execFile(RADAR, ["mark", status, label, summary], () => {});
}

export default function (pi: ExtensionAPI) {
  // agent_end fires when pi finishes responding and is ready for your input.
  pi.on("agent_end", async (_event, ctx) => {
    const label = basename(process.cwd()) || "pi";

    // Best-effort one-line summary of the last assistant message. Wrapped in
    // try/catch so any API drift just yields an empty summary (never crashes pi).
    let summary = "";
    try {
      const sm: any = (ctx as any).sessionManager;
      const msgs: any[] = sm?.getMessages?.() ?? sm?.messages ?? [];
      for (let i = msgs.length - 1; i >= 0; i--) {
        const m = msgs[i];
        if (m?.role !== "assistant") continue;
        const c = m.content;
        const text = Array.isArray(c)
          ? c.filter((b: any) => b?.type === "text").map((b: any) => b.text).join(" ")
          : typeof c === "string"
            ? c
            : "";
        summary = String(text).replace(/\s+/g, " ").trim().slice(0, 180);
        if (summary) break;
      }
    } catch {
      /* summary is best-effort */
    }

    mark("done", label, summary);
  });
}
