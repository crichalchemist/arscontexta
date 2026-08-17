import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Type-only import above: erased at compile time, so this file has no runtime
// dependency and this repo needs no package.json.

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");

/**
 * Registers this plugin's skills/ directory with Pi so the plugin's skills
 * become available. The exact invocation syntax Pi uses to run one is
 * host-specific and unverified.
 *
 * Deliberately absent: the session_start / session_compact / agent_end flag
 * dance, the bootstrap cache, and the compactionSummary insert-index walk that
 * obra/superpowers needs to force-load one skill ahead of the agent. Every
 * arscontexta command is invoked explicitly, so nothing must be resident first.
 */
export default function arscontextaPiExtension(pi: ExtensionAPI) {
  pi.on("resources_discover", async () => ({
    skillPaths: [skillsDir],
  }));
}
