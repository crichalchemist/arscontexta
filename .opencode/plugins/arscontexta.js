/**
 * arscontexta plugin for OpenCode.ai
 *
 * Registers this plugin's skills/ directory with OpenCode so the
 * /arscontexta:* commands resolve. That is the whole job.
 *
 * Deliberately absent: bootstrap injection. obra/superpowers injects its
 * using-superpowers skill into every session because nothing may happen
 * before that skill is loaded. arscontexta has no such contract — every
 * command is invoked explicitly and no skill dispatches subagents — so
 * there is nothing to make resident ahead of the user.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ArsContextaPlugin = async ({ client, directory }) => {
  const skillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Push our skills path into the live config. OpenCode's Config.get()
    // returns a cached singleton, so a mutation here is visible when skills
    // are lazily discovered later — no symlinks, no user config edits.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
