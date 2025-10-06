# Chatbot Project Context (for maintainers and future automation)

This file is intended for internal use by maintainers and automation tools (such as AI assistants) to retain situational awareness and project context that is not suitable for end-user documentation. It should not be included in the PowerShell Gallery package or referenced in user-facing docs.

## Project Summary
- **Name:** GitIdentities
- **Type:** PowerShell module for managing multiple Git/SSH identities with per-folder configuration
- **Audience:** Developers with multiple Git profiles (work, personal, clients)
- **Key Features:**
  - Idempotent provisioning of Git/SSH identities
  - Platform detection (GitHub, GitLab, Azure DevOps, Bitbucket)
  - SSH key management, credential helper integration
  - Per-folder `includeIf` config, cross-user support
  - Logging, dry-run, advanced troubleshooting
- **Supported OS:** Windows (PowerShell 5.1+)
- **Distribution:** PowerShell Gallery, GitHub

## Documentation Policy
- The root `README.md` is for GitHub visitors and contributors: project overview, install, test, and contribution info.
- The module `GitIdentities/README.md` is for PowerShell Gallery and module users: detailed usage, parameters, advanced scenarios, troubleshooting.
- This file (`chatbot.md`) is for automation and maintainers: context, design decisions, and future AI/automation notes.

## Automation/AI Notes
- If you need to remove or refactor content from the main READMEs for clarity or audience targeting, preserve any context useful for future automation here.
- Summarize any major design or documentation changes here for future maintainers.
- Use this file to track project-specific conventions, naming, or non-obvious decisions.

## Recent Changes (2025-10-06)
- README split: root for GitHub, module for PowerShell Gallery.
- Added beginner test instructions to root README.
- Ensured all module usage, parameters, and troubleshooting are in module README.

---
This file is not intended for end users. Do not include in published module packages.