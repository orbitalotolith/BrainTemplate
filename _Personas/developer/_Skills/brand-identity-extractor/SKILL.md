---
name: brand-identity-extractor
description: Use when a user needs to extract brand identity from a website URL, populate a _Brand.md file for a client, or generate a style guide from an existing site.
user-invocable: true
disable-model-invocation: false
allowed-tools: WebFetch, Glob, Read, Write, Edit, AskUserQuestion
---

# Brand Identity Extractor

Extract brand identity from a client website and generate a structured `_Brand.md` style guide. Reconciles website signals with any existing design system CSS in the client's projects.

## Overview

[TBD]

## Arguments

Parse args for `<ClientName>` and `<URL>`. If not provided, use AskUserQuestion to request them.

- **Client directory:** `~/Development/<ClientName>/`
- **Brand file:** `~/Development/<ClientName>/_Brand.md`

If the client directory does not exist, output the brand guide to terminal and suggest running `/create-project` first.

## Process

### 0. Read Gotchas
Read `gotchas.md` in this skill's directory (if it exists) before proceeding.
Known failure modes inform execution — avoid repeating past mistakes.

### Phase 1: Scan Existing Assets

Search the client directory for existing design system ground truth:

```
Glob: **/styles/index.css, **/styles/globals.css, **/theme.*, **/tailwind.config.*
```

Read any files found. Extract:
- CSS custom properties (`:root` variables)
- Color tokens, font stacks, spacing scales
- Theme mode (dark/light)

This is ground truth — the website may differ from the implemented design system.

### Phase 2: Fetch Website

Use WebFetch on the homepage URL with this prompt:

> Extract all brand identity signals: 1) Color palette — list every hex color (backgrounds, text, accents, buttons, borders). 2) Typography — font families, sizes, weights. 3) Visual style — dark/light theme, border radius, shadows, spacing. 4) Brand voice — tone of copy, vocabulary, positioning. 5) Logo description. 6) Any brand guidelines or style references. Be thorough with hex values.

Optionally fetch secondary pages for more signals:
- `/about`, `/about-us` — brand story, voice
- `/brand`, `/style-guide` — explicit guidelines

If the website is blocked, times out, or is an SPA with minimal HTML:
- Ask the user for a screenshot or style guide document
- Fall back to project CSS only

### Phase 3: Extract & Categorize

Organize all signals into four categories:

#### Color Palette
Group by role:
- **Primary/Accent** — brand color, CTA buttons
- **Surfaces** — backgrounds (page, panel, input)
- **Text** — primary, secondary, muted, on-light/on-dark
- **Borders** — dividers, input borders
- **Semantic** — success, error, warning

#### Typography
- **UI font** — family, stack, source (Google Fonts, system, self-hosted)
- **Mono font** — family, stack, source
- **Display/Heading font** — if different from UI
- **Scale** — heading sizes, body size, line-height

#### Visual Style
- Theme (light/dark/dual)
- Border radius range
- Shadow style
- Spacing philosophy (tight/airy)
- Animation style

#### Brand Voice
- Positioning statement
- Tone (formal/casual, luxe/accessible)
- Key vocabulary and phrases
- Target audience signals

### Phase 4: Reconcile

If both website and project CSS data exist, note discrepancies:
- Website may use marketing colors (e.g., bright blue) while the app uses tool-appropriate colors (e.g., warm amber)
- Flag which is the "canonical brand" vs "app adaptation"
- Present both as separate sections in the output

### Phase 5: Present & Confirm

Use AskUserQuestion to show the extracted brand guide to the user BEFORE writing. Format as a readable summary. Ask:

> Here's the extracted brand guide for [Client]. Review and let me know:
> 1. Any corrections to colors, fonts, or voice?
> 2. Should I merge website + app palettes or keep them separate?
> 3. Anything to add or remove?

Apply corrections before writing.

### Phase 6: Write `_Brand.md`

#### If `_Brand.md` exists with real content (beyond stub)
Show diff, ask: overwrite, merge (use Edit to update in place), or skip.

#### If `_Brand.md` is a stub or doesn't exist
Write using the template below. Preserve existing frontmatter `tags` and `## Projects` wiki-links.

#### Template

Read `brand-template.md` companion file for the complete template.

## Output

[TBD]

## Rules

### Edge Cases

| Scenario | Handling |
|----------|----------|
| Website blocked/timeout | Ask user for screenshot or style guide; fall back to project CSS only |
| Fonts loaded via JS | Note limitation, ask user to confirm font names |
| SPA with minimal HTML | Ask for server-rendered page URL or fall back to CSS |
| `_Brand.md` has real content | Show diff, ask: overwrite, merge, or skip |
| No client directory exists | Output guide to terminal, suggest `/create-project` first |
| No website provided | Extract from project CSS only, skip website phases |

- Always present results for user review before writing
- Preserve existing frontmatter tags and project wiki-links
- Note discrepancies between website and app design systems — don't silently pick one
- Use tables for colors and typography — they render well in Obsidian
- Include CSS variable names when available
- Keep the file under 150 lines when possible
