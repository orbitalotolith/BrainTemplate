---
tags: [reference, nodejs, npm]
---
# Node.js and npm

## Gotchas

- **npm bin links can silently become 0-byte files** (as of npm 9/10, observed 2026-03; verify current npm version — last reviewed 2026-04-04): Instead of a symlink (e.g. `node_modules/.bin/concurrently -> ../concurrently/dist/bin/concurrently.js`), the file becomes a 0-byte regular file. Cause unknown — possibly interrupted `npm install` or filesystem issue. Symptom: the CLI tool exits immediately with no output, no error. Diagnostic: `ls -la node_modules/.bin/<tool>` — should be a symlink, not a regular file. Fix: `rm node_modules/.bin/<tool> && npm install`.
