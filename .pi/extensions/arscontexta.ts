import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Type-only import above: erased at compile time, so this file has no runtime
// dependency and this repo needs no package.json.

const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "../..");
const skillsDir = resolve(packageRoot, "skills");

// That resolution is relative to THIS FILE, so the extension works only while it
// sits inside a checkout. Copying it into ~/.pi/agent/extensions/ makes packageRoot
// ~/.pi and registers a skillsDir that does not exist — silently: the handler returns,
// no skills appear, nothing is reported. Register the path in settings.json instead;
// see .pi/INSTALL.md.

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
