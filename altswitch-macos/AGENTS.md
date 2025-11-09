<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Claude Agents

This document enumerates the Claude Code agents that are tailored for the AltSwitch repository. Each agent loads the shared engineering context from `CLAUDE.md`, so skim that file before delegating any task to be sure the assistant understands the build, testing, and architecture expectations.

## Picking The Right Agent
- Identify the outcome you need (feature work, test design, code review) and match it to the agent whose `name` field appears in `.claude/agents/`.
- Provide the agent with the same CLI commands listed in `CLAUDE.md` so it can build, test, or lint exactly the way CI does.
- When a request spans multiple disciplines, start with the most specialized agent and escalate to others only if new expertise is required.

## Available Agents

| Agent name | Purpose | Ask it for | Definition |
| --- | --- | --- | --- |
| `swift-test-engineer` | Builds and maintains high-signal Swift/SwiftUI macOS test suites. | Designing new Swift Testing suites, deflaking UI automation, assessing coverage gaps, or wiring test tooling into CI. | `.claude/agents/swift-macos-engineer.md` |
| `swift-code-reviewer` | Performs pragmatic, high-signal reviews of Swift/SwiftUI/macOS changes with an eye toward correctness, maintainability, and alignment with AltSwitch guidelines. | Structured review feedback, risk triage on pull requests, identifying missing tests, or recommending follow-up actions. | `.claude/agents/swift-code-reviewer.md` *(added in this update)* |

Add future agents by dropping a new Markdown file into `.claude/agents/` using the same front-matter schema (`name`, `description`, `model`, `color`, `examples`), then record it in the table above with a concise description of when to use it.

# Source Control
This project uses Jujutsu (`jj`) for source control. Use this instead of git!
