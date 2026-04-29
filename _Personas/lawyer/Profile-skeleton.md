---
title: User Profile
type: profile
created: {{CREATED}}
---

# Profile

**Name:** {{USER_NAME}}
**Role:** Lawyer / legal practitioner
**Practice area:** {{PRACTICE_AREA}}
**Typical matter types:** {{MATTER_TYPES}}

## Working style

(Populate as you discover preferences — what kinds of analysis do you want, what level of detail, what citation style.)

## Anti-hallucination policy

This vault enforces source-citation for all factual claims. AI output that asserts a fact about a document must cite the document and page/section. Out-of-corpus answers are flagged explicitly. See `CLAUDE.md` for the full policy.

## Tools

- Brain (this vault) — local persistent memory + matter context for AI work
- Claude Code — terminal-based AI assistant; primary interface for this vault
- Claude.ai chat — web-based; useful for ad-hoc questions, not the persistent context
- (Optional) Westlaw / LexisNexis — paid legal databases; integration deferred to Plan 2

## See also

- `_Profile/identity.md`, `_Profile/preferences.md` — populate over time
- `CLAUDE.md` — Brain operating rules and anti-hallucination policy
- `_HowThisWorks.md` — vault architecture
